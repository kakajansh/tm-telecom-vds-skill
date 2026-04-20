# TM Telecom VDS Skill

Reusable agent skill for troubleshooting Turkmen Telecom / `telecom.tm` VDS deployments and similarly restricted Turkmenistan hosting environments.

It helps AI coding agents with:

- Docker Compose deployment preflight checks
- Docker installation fallback when `download.docker.com` is blocked
- Docker Hub pull fallback through `mirror.gcr.io`
- GitHub connectivity checks and reversible `/etc/hosts` workaround
- npm registry mirror fallback
- Let's Encrypt DNS/manual validation
- `.tm` SSL certificate fallback guidance

## Install

Install globally for Codex:

```bash
npx skills add kakajansh/tm-telecom-vds-skill --skill tm-telecom-vds -a codex -g
```

Install globally for several popular agents:

```bash
npx skills add kakajansh/tm-telecom-vds-skill --skill tm-telecom-vds -a claude-code -a antigravity -a codex -a cursor -a windsurf -a gemini-cli -g
```

Install interactively and choose your agent:

```bash
npx skills add kakajansh/tm-telecom-vds-skill --skill tm-telecom-vds -g
```

List the skill from the repo before installing:

```bash
npx skills add kakajansh/tm-telecom-vds-skill --list
```

## Usage

Ask your agent:

```text
Use $tm-telecom-vds to preflight my telecom.tm VDS before deployment.
```

Or:

```text
Use $tm-telecom-vds to fix Docker and npm access on a Turkmen Telecom VDS.
```

## Skill Contents

```text
skills/tm-telecom-vds/
├── SKILL.md
├── agents/
│   └── openai.yaml
├── references/
│   └── tm-vds-recipes.md
└── scripts/
    └── tm-preflight.sh
```

## Attribution

Based on Turkmen Telecom VDS field notes from Дикий devops (`@wild_devops`), packaged as a reusable agent skill for the TM developer community.

## License

MIT
