# Turkmen Telecom VDS Recipes

Use these recipes for telecom.tm VDS servers and similar restricted Turkmenistan hosting environments. Test official services first because availability changes.

Source credit: these recipes are adapted from Telegram channel **Дикий devops** (`@wild_devops`). Preserve attribution when sharing the skill or outputs derived from it.

## Preflight Script

Run the bundled preflight before proposing a deployment or workaround. It is read-only and safe to rerun.

Use `scripts/tm-preflight.sh` when evaluating whether a Turkmen Telecom VDS can deploy a Docker Compose web application. It checks:

- CPU architecture, CPU count, RAM, swap, free disk, distro, kernel, and public IPv4
- required commands such as `curl`, `git`, `make`, and `openssl`
- Docker client, daemon, Compose plugin, and Buildx
- local listeners on ports 80/443 and firewall hints
- outbound HTTPS/TCP reachability for GitHub, Docker Hub, npm, PyPI, Hugging Face, Gemini, OAuth, and Let's Encrypt
- optional Docker pulls for application images
- production Docker Compose config rendering when the compose file and env file are present

Useful environment variables:

```bash
TIMEOUT=12 bash scripts/tm-preflight.sh
MIN_RAM_MB=4096 MIN_DISK_GB=30 bash scripts/tm-preflight.sh
PULL_IMAGES=1 bash scripts/tm-preflight.sh
PULL_IMAGES=1 IMAGE_LIST="nginx:latest node:22-alpine postgres:17" bash scripts/tm-preflight.sh
APP_HEALTH_URL=https://example.com bash scripts/tm-preflight.sh
COMPOSE_FILE=compose.production.yml ENV_FILE=.env bash scripts/tm-preflight.sh
```

## Let's Encrypt With DNS TXT Validation

Use when HTTP validation fails or the domain cannot be verified through the normal web challenge.

Run certbot in manual DNS mode:

```bash
sudo certbot certonly --manual --preferred-challenges dns -d example.com
```

Certbot prints a TXT record name similar to:

```text
_acme-challenge.example.com.
```

and a unique TXT value for the active session.

Add that exact TXT record in the domain DNS panel. Do not close the terminal or restart certbot while waiting, because the TXT value is unique per session.

Check propagation with one of:

```bash
dig TXT _acme-challenge.example.com
```

or an external DNS checker such as Google Admin Toolbox or DNSChecker. After the expected TXT value appears globally, return to the certbot terminal and press Enter.

## SSL For .tm Domains

Use when ordinary Let's Encrypt validation is unreliable for Turkmen `.tm` domains.

Practical fallback:

1. Create a corporate/domain mailbox for the target domain, for example through Sanly TM or another local provider that can host mail for the domain.
2. Buy or request a certificate from a provider that supports email/domain mailbox validation, such as SSLs, ZeroSSL, or another CA.
3. Choose email validation and receive the verification email at a domain-owned mailbox.
4. Complete the certificate provider's verification flow and install the issued certificate on the VDS.

Keep the mailbox active until the certificate is issued and note the renewal path, because renewal may require another mailbox verification.

## Docker Installation And Docker Hub Mirror

First distinguish Docker installation failures from image-pull failures.

If `download.docker.com:443` is reachable, install Docker from the official Docker apt repository on Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
docker version
```

If `download.docker.com:443` is blocked, the official Docker CE repo cannot be used. On Ubuntu 24.04, remove the broken Docker CE source and install Ubuntu's own Docker packages instead:

```bash
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo apt update

sudo apt install -y software-properties-common
sudo add-apt-repository -y universe
sudo apt update

sudo apt install -y docker.io docker-compose-v2 docker-buildx make netcat-openbsd

sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
```

Verify:

```bash
docker --version
docker compose version
docker buildx version
docker info
```

In a Turkmen Telecom Ubuntu 24.04 field test, this Ubuntu-package path produced a healthy Docker install with Docker `29.1.3`, Compose `2.40.3`, Buildx `0.30.1`, `overlayfs`, the `systemd` cgroup driver, and successful application image pulls.

Only after Docker itself works, configure Docker to use Google Container Registry's Docker Hub mirror when Docker Hub pulls are slow or blocked:

```bash
sudo mkdir -p /etc/docker
sudo nano /etc/docker/daemon.json
```

Use this JSON, merging with existing daemon settings if the file already exists:

```json
{
  "registry-mirrors": ["https://mirror.gcr.io"]
}
```

Restart and verify:

```bash
sudo systemctl restart docker
docker system info | grep "Registry Mirrors" -A 1
docker pull nginx:latest
```

For an application deployment, test the images that the compose stack actually uses. For example:

```bash
docker pull nginx:latest
docker pull node:22-alpine
docker pull postgres:17
```

## GitHub Access Through `/etc/hosts`

Use only when GitHub DNS or routing fails from the VDS and the user needs a temporary workaround.

Find currently resolved GitHub IPs through a DNS checker or resolver, then test candidates from the server:

```bash
ping <candidate-github-ip>
```

If an official GitHub IP responds, add a temporary hosts entry:

```bash
sudo nano /etc/hosts
```

Example shape:

```text
20.207.73.82 github.com
```

Flush DNS cache if available:

```bash
sudo systemd-resolve --flush-caches
```

Verify with:

```bash
git ls-remote https://github.com/octocat/Hello-World.git
```

Remove or update the hosts entry when it stops working or when normal access returns. Do not map GitHub to random third-party IPs.

## npm Registry Mirror And Node.js Update

Use only if official npm registry access fails. The original notes later observed that official npm access reopened, so check first:

```bash
npm ping
npm config get registry
```

If npm registry access is blocked, set a temporary mirror:

```bash
npm config set registry https://npm-mirror.gitverse.ru
npm config get registry
```

Install Node.js/npm from apt if needed:

```bash
sudo apt update
sudo apt install -y nodejs npm
node -v
npm -v
```

Install the `n` version manager through the mirror and update Node:

```bash
sudo npm install -g n --registry=https://npm-mirror.gitverse.ru
sudo n stable
hash -r
node -v
npm -v
```

When official npm works again, reset the mirror:

```bash
npm config delete registry
npm config get registry
```
