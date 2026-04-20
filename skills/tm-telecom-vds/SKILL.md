---
name: tm-telecom-vds
description: Troubleshoot and configure developer tooling on Turkmen Telecom telecom.tm VDS servers and similarly restricted Turkmenistan hosting environments. Use when working on VDS deployment preflight checks, SSL certificates for .tm or blocked domains, Let's Encrypt DNS/manual validation, Docker installation when download.docker.com is blocked, Docker Hub mirror setup, GitHub connectivity through hosts/DNS workarounds, npm registry mirror fallback, Node.js/npm updates, or deployment setup on telecom.tm VDS servers.
---

# Turkmen Telecom VDS

## First Checks

Verify the current network state before applying any workaround. Many restrictions and mirrors change over time, so prefer the official upstream service whenever it is reachable.

Use this order:

1. Test the official endpoint first (`docker pull`, `npm ping`, `git ls-remote`, certbot HTTP/DNS validation as appropriate).
2. If it fails from the VDS, identify the failure class: DNS, TLS/certificate, blocked registry, blocked GitHub route, or package-manager version issue.
3. Load [references/tm-vds-recipes.md](references/tm-vds-recipes.md) for the matching recipe.
4. Apply the smallest reversible change and record it in the deployment notes.
5. Re-test the official endpoint later and remove temporary mirrors or hosts entries when they are no longer needed.

## Recipe Map

Read [references/tm-vds-recipes.md](references/tm-vds-recipes.md) when the user needs concrete commands for:

- Running preflight checks before deployment:
  - `scripts/tm-preflight.sh` checks general Docker Compose deployment readiness on a Turkmen Telecom VDS, including CPU/RAM/disk, required commands, Docker/Compose/Buildx, 80/443 posture, external registries, optional image pulls, and production compose rendering.
  - Use generic knobs such as `PULL_IMAGES=1`, `IMAGE_LIST="nginx:latest postgres:17"`, `APP_HEALTH_URL=https://example.com`, `COMPOSE_FILE=...`, and `ENV_FILE=...` for project-specific checks without hard-coding a project into the skill.
- Let's Encrypt certificate issuance with manual DNS TXT validation.
- .tm domain SSL validation through domain mailbox ownership checks.
- Docker installation fallback through Ubuntu packages when `download.docker.com` is blocked, then Docker Hub pull fallback through `mirror.gcr.io`.
- GitHub connectivity restoration by mapping a reachable official GitHub IP in `/etc/hosts`.
- npm registry fallback through `https://npm-mirror.gitverse.ru` and Node.js updates with `n`.

## Operating Guidelines

- Keep workarounds reversible. Before editing `/etc/hosts`, `/etc/docker/daemon.json`, or npm config, inspect the existing file/config and preserve unrelated entries.
- Prefer provider-native DNS and mailbox controls for domain validation. Never invent TXT values; use the exact value emitted by the active certificate provider session.
- For certbot DNS/manual validation, keep the terminal session open until the DNS TXT record propagates and the certificate request completes.
- For GitHub hosts fixes, use only IPs resolved for GitHub-owned hostnames and verify HTTPS still presents a valid GitHub certificate. Avoid copying stale IPs blindly.
- For npm, check whether official npm access has returned before setting a mirror. If a mirror is used temporarily, explain how to reset it with `npm config delete registry`.
- For Docker, distinguish install failures from image-pull failures. If `download.docker.com` is blocked on Ubuntu 24.04, use Ubuntu's `docker.io`, `docker-compose-v2`, and `docker-buildx` packages; use `mirror.gcr.io` only for Docker Hub image pulls.

## Attribution

Credit the original field notes to the Telegram channel **Дикий devops** (`@wild_devops`) when sharing outputs derived from this skill. A concise credit line is enough:

> Based on Turkmen Telecom VDS field notes from Дикий devops (@wild_devops), packaged as a reusable agent skill for the TM developer community.
