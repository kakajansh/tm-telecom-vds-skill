#!/usr/bin/env bash
set -u

TIMEOUT="${TIMEOUT:-8}"
MIN_RAM_MB="${MIN_RAM_MB:-4096}"
MIN_DISK_GB="${MIN_DISK_GB:-30}"
PULL_IMAGES="${PULL_IMAGES:-0}"
IMAGE_LIST="${IMAGE_LIST:-nginx:latest node:22-alpine python:3.12-slim}"
APP_HEALTH_URL="${APP_HEALTH_URL:-}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
ENV_FILE="${ENV_FILE:-.env.production}"

pass=0; fail=0; warn=0

hr() { printf '\n==== %s ====\n' "$1"; }

row() {
  local name="$1" status="$2" detail="$3"
  case "$status" in
    OK) pass=$((pass+1)) ;;
    WARN) warn=$((warn+1)) ;;
    *) fail=$((fail+1)) ;;
  esac
  printf '  %-44s %-6s %s\n' "$name" "$status" "$detail"
}

have() { command -v "$1" >/dev/null 2>&1; }

probe_https() {
  local host="$1" expect="${2:-^(200|301|302|400|401|403|404)$}"
  local code
  code=$(curl -sS -o /dev/null -m "$TIMEOUT" -w '%{http_code}' "https://${host}/" 2>/dev/null || true)
  code="${code:-ERR}"
  echo "$code" | grep -qE "$expect" && row "$host" OK "HTTP $code" || row "$host" FAIL "HTTP $code"
}

probe_tcp() {
  local host="$1" port="$2"
  if have nc; then
    nc -z -w "$TIMEOUT" "$host" "$port" >/dev/null 2>&1 \
      && row "tcp ${host}:${port}" OK "reachable" \
      || row "tcp ${host}:${port}" FAIL "blocked or timed out"
  else
    row "tcp ${host}:${port}" WARN "nc not installed"
  fi
}

hr "System"
echo "  date UTC:      $(date -u +%FT%TZ)"
echo "  kernel:        $(uname -srm)"
if [ -r /etc/os-release ]; then . /etc/os-release; echo "  distro:        ${PRETTY_NAME:-unknown}"; fi
echo "  public IPv4:   $(curl -4 -sS -m "$TIMEOUT" https://ifconfig.co 2>/dev/null || echo unknown)"

arch="$(uname -m)"
case "$arch" in
  x86_64|aarch64|arm64) row "CPU architecture" OK "$arch" ;;
  *) row "CPU architecture" WARN "$arch; Docker images may not support it" ;;
esac

cpu_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 0)"
[ "$cpu_count" -ge 2 ] 2>/dev/null && row "CPU cores" OK "$cpu_count" || row "CPU cores" WARN "$cpu_count; 2+ recommended"

ram_mb="$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)"
[ "$ram_mb" -ge "$MIN_RAM_MB" ] 2>/dev/null && row "RAM" OK "${ram_mb}MB" || row "RAM" FAIL "${ram_mb}MB; need >=${MIN_RAM_MB}MB"

swap_mb="$(awk '/SwapTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)"
[ "$swap_mb" -gt 0 ] 2>/dev/null && row "Swap" OK "${swap_mb}MB" || row "Swap" WARN "no swap; builds may fail on small VDS"

disk_gb="$(df -BG / 2>/dev/null | awk 'NR==2 {gsub("G","",$4); print $4}')"
[ "${disk_gb:-0}" -ge "$MIN_DISK_GB" ] 2>/dev/null && row "Free disk /" OK "${disk_gb}GB" || row "Free disk /" FAIL "${disk_gb:-0}GB; need >=${MIN_DISK_GB}GB"

hr "Required commands"
for cmd in bash curl awk sed grep openssl git make; do
  have "$cmd" && row "$cmd" OK "$($cmd --version 2>/dev/null | head -1)" || row "$cmd" FAIL "missing"
done

hr "Docker"
if have docker; then
  row "docker client" OK "$(docker --version 2>/dev/null)"
  docker info >/dev/null 2>&1 && row "docker daemon" OK "running and accessible" || row "docker daemon" FAIL "not running or current user lacks permission"
  docker compose version >/dev/null 2>&1 && row "docker compose plugin" OK "$(docker compose version 2>/dev/null)" || row "docker compose plugin" FAIL "missing"
else
  row "docker" FAIL "missing"
fi

hr "Firewall / ports"
if have ss; then
  listeners="$(ss -tln 2>/dev/null | awk 'NR>1 && ($4 ~ /:80$/ || $4 ~ /:443$/) {print $4}' | paste -sd ',' -)"
  [ -n "$listeners" ] && row "local listeners 80/443" WARN "$listeners already in use" || row "local listeners 80/443" OK "free"
else
  row "ss" WARN "missing; cannot inspect listeners"
fi
have ufw && { ufw status 2>/dev/null | sed 's/^/  ufw: /' | head -20; } || true
have firewall-cmd && { firewall-cmd --state 2>/dev/null | sed 's/^/  firewalld: /'; } || true
echo "  note: inbound 80/443 must also be allowed in Turkmen Telecom/provider firewall."

hr "DNS + HTTPS reachability"
probe_https github.com '^(200|301|302)$'
probe_https api.github.com '^(200|301|302)$'
probe_https codeload.github.com
probe_https registry-1.docker.io '^(200|401|404)$'
probe_https auth.docker.io '^(200|401|404)$'
probe_https production.cloudflare.docker.com
probe_https registry.npmjs.org '^(200|301|302)$'
probe_https pypi.org '^(200|301|302)$'
probe_https files.pythonhosted.org
probe_https huggingface.co '^(200|301|302|401|403|404)$'
probe_https cdn-lfs.huggingface.co '^(200|301|302|401|403|404)$'
probe_https generativelanguage.googleapis.com
probe_https oauth2.googleapis.com
probe_https acme-v02.api.letsencrypt.org

if [ -n "$APP_HEALTH_URL" ]; then
  code=$(curl -sS -o /dev/null -m "$TIMEOUT" -w '%{http_code}' "$APP_HEALTH_URL" 2>/dev/null || true)
  echo "$code" | grep -qE '^(200|301|302|400|401|403|404)$' && row "APP_HEALTH_URL" OK "HTTP $code" || row "APP_HEALTH_URL" FAIL "HTTP ${code:-ERR}"
else
  row "APP_HEALTH_URL" WARN "not set; skip application health endpoint reachability"
fi

hr "TCP 443 probes"
probe_tcp github.com 443
probe_tcp registry-1.docker.io 443
probe_tcp registry.npmjs.org 443
probe_tcp pypi.org 443
probe_tcp huggingface.co 443
probe_tcp generativelanguage.googleapis.com 443

hr "Optional Docker image pulls"
if [ "$PULL_IMAGES" = "1" ] && have docker && docker info >/dev/null 2>&1; then
  for img in $IMAGE_LIST; do
    docker pull "$img" >/tmp/tm-preflight-pull.log 2>&1 \
      && row "docker pull $img" OK "pulled" \
      || row "docker pull $img" FAIL "$(tail -1 /tmp/tm-preflight-pull.log)"
  done
else
  row "docker image pulls" WARN "skipped; rerun with PULL_IMAGES=1 for definitive Docker Hub test"
fi

hr "Repo compose check"
if [ -f "$COMPOSE_FILE" ]; then
  if [ -f "$ENV_FILE" ]; then
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config >/dev/null 2>&1 \
      && row "production compose config" OK "renders" \
      || row "production compose config" FAIL "invalid; run docker compose config for details"
  else
    row "$ENV_FILE" WARN "missing; compose render skipped"
  fi
else
  row "$COMPOSE_FILE" WARN "not in current directory; repo not checked out here"
fi

hr "Summary"
echo "  passed:  $pass"
echo "  warned:  $warn"
echo "  failed:  $fail"

if [ "$fail" -eq 0 ]; then
  echo "  verdict: server looks deployable for a Docker Compose web app; warnings may still need cleanup."
  exit 0
else
  echo "  verdict: fix failed checks before deployment."
  exit 1
fi
