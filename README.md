⚠️ This is experimental and doesn't work for now. I cannot get my plugins installed inside the devcontainer because of an issue with the ssh agent

# AI Sandboxo

Reusable devcontainer for running Claude Code with full permissions in a sandboxed environment. Drop it into any TS/React/Next project.

## Quick Start

### One-time global setup

```bash
# Add .devcontainer/ and sandbox to your global gitignore
echo -e ".devcontainer/\nsandbox" >> ~/.config/git/ignore
```

### Per-project setup

```bash
# Copy into your project
npx degit selrahcd/ai-sandbox/.devcontainer .devcontainer
npx degit selrahcd/ai-sandbox/sandbox sandbox
chmod +x sandbox

# Start, login, install plugins
./sandbox up
./sandbox login
./sandbox setup

# Go
./sandbox claude
```

## Commands

| Command | Description |
|---|---|
| `./sandbox up` | Start the container |
| `./sandbox down` | Stop the container |
| `./sandbox rebuild` | Rebuild from scratch |
| `./sandbox login` | Run `claude login` in the container |
| `./sandbox setup` | Install marketplaces + plugins |
| `./sandbox claude` | Launch Claude Code (full permissions) |
| `./sandbox shell` | Open a bash shell |

## What's Inside

- Node 22 LTS
- npm, pnpm, yarn
- Claude Code CLI

## How It Works

The container mounts your project directory and runs Claude Code with `--dangerously-skip-permissions`. Your host filesystem outside the project is not accessible. Claude authenticates via `claude login` inside the container (isolated from your host `~/.claude`).

Plugins are installed per-container via the setup script. Since the project workspace is mounted from your host, project-level Claude config (`.claude/`) persists across container rebuilds.

## Future Improvements

- [ ] **Network restrictions**: Squid proxy with domain allowlist + SNI-based HTTPS filtering
- [ ] **`./sandbox allow <domain>`**: Hot-add domains to the allowlist without rebuild
- [ ] **Per-project domain allowlist**: `.devcontainer/allowed-domains.txt` merged with defaults
- [ ] **OpenCode support**: Add OpenCode CLI to the container
- [ ] **TDD workflow system**: Inject autonomous agent team workflows (inspired by NTCoding/autonomous-claude-agent-team)
- [ ] **Baked Claude settings**: Ship a default `settings.json` for consistent config
- [ ] **Network monitoring**: Log blocked domains to help discover what needs allowing
- [ ] **Protected paths**: Mount empty files over sensitive host paths (SSH keys, cloud credentials)
