# Secure AI Dev Toolbox

A reusable, network-restricted Docker environment plus a tiny launcher (`aidev`) that gives you **default‑deny egress** for AI development. Your code stays on the **host**; the container mounts your project at `/workspaces/app` and only reaches **allow‑listed** domains (npm, GitHub, LLM APIs, etc).

**Published image:** `docker.io/pdrittenhouse/secure-ai-dev:1`

This repo also contains the **source** (Dockerfile + `security/`) so you can build or customize the image yourself.

---

## TL;DR — Use the published image

```bash
# 0) Set the image once for aidev (recommended)
mkdir -p "$HOME/.secure-ai-dev"
echo 'SECURE_AI_IMAGE="docker.io/pdrittenhouse/secure-ai-dev:1"' >> "$HOME/.secure-ai-dev/config"

# 1) Install the launcher (host-side)
mkdir -p "$HOME/.secure-ai-dev/bin"
curl -fsSL https://raw.githubusercontent.com/<org>/<repo>/main/bin/aidev -o "$HOME/.secure-ai-dev/bin/aidev"
chmod +x "$HOME/.secure-ai-dev/bin/aidev"
echo 'export PATH="$HOME/.secure-ai-dev/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc

# 2) Ensure a global allowlist exists (edit as needed)
mkdir -p "$HOME/.secure-ai-dev/security/allowlist"
touch "$HOME/.secure-ai-dev/security/allowlist/global-allowed.txt"

# 3) Start in your project
cd /path/to/project
aidev
aidev doctor --verbose
```

> Prefer VS Code devcontainers? See the example below that points directly at `docker.io/pdrittenhouse/secure-ai-dev:1`.

---

## Build from source (this repo)

### A) Local single‑arch build (creates a local image)
From the **repo root** (where the Dockerfile lives):
```bash
docker build -t pdrittenhouse/secure-ai-dev:dev .
# use it with aidev
echo 'SECURE_AI_IMAGE="pdrittenhouse/secure-ai-dev:dev"' >> "$HOME/.secure-ai-dev/config"
aidev rm 2>/dev/null || true
aidev && aidev doctor
```

### B) Multi‑arch build & push to Docker Hub
Use this when you want both Apple Silicon (arm64) and x86 (amd64) in one tag:
```bash
docker buildx create --use 2>/dev/null || true
docker login

docker buildx build   --platform linux/amd64,linux/arm64   -t docker.io/pdrittenhouse/secure-ai-dev:1   -t docker.io/pdrittenhouse/secure-ai-dev:latest   --push   .
```

Verify:
```bash
docker buildx imagetools inspect docker.io/pdrittenhouse/secure-ai-dev:1
```

> When you publish a new version, bump the tag (e.g., `:2`) and tell users to update their `SECURE_AI_IMAGE` or `devcontainer.json` accordingly.

### C) Load a specific arch locally (no push)
```bash
# Apple Silicon
docker buildx build --platform linux/arm64 -t pdrittenhouse/secure-ai-dev:dev --load .
# x86_64
docker buildx build --platform linux/amd64 -t pdrittenhouse/secure-ai-dev:dev --load .
```

---

## Example: `.devcontainer/devcontainer.json`

Use the **published** image:
```json
{
  "name": "Secure AI Dev (published image)",
  "image": "docker.io/pdrittenhouse/secure-ai-dev:1",
  "workspaceFolder": "/workspaces/app",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspaces/app,type=bind",
  "runArgs": [
    "--cap-add=NET_ADMIN",
    "--cap-add=NET_RAW",
    "--add-host=host.docker.internal:host-gateway"
  ],
  "mounts": [
    "source=${env:HOME}/.secure-ai-dev/security/allowlist,target=/opt/security/allowlist,type=bind,readonly"
  ],
  "remoteUser": "vscode",
  "postStartCommand": "sudo /opt/security/setup-firewall.sh",
  "shutdownAction": "stopContainer"
}
```

Or reference your **locally built** tag (for development):
```json
{
  "image": "pdrittenhouse/secure-ai-dev:dev",
  "workspaceFolder": "/workspaces/app",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspaces/app,type=bind",
  "runArgs": ["--cap-add=NET_ADMIN","--cap-add=NET_RAW","--add-host=host.docker.internal:host-gateway"],
  "mounts": ["source=${env:HOME}/.secure-ai-dev/security/allowlist,target=/opt/security/allowlist,type=bind,readonly"],
  "remoteUser": "vscode",
  "postStartCommand": "sudo /opt/security/setup-firewall.sh"
}
```

---

## `aidev` quick reference

| Command | What it does |
|---|---|
| `aidev` / `aidev start` | Start or reattach a secure container for the current folder. |
| `aidev sh` | Open a bash shell inside the container. |
| `aidev stop` | Stop the container for this folder. |
| `aidev rm` | Remove (force) the container for this folder (safe for code). |
| `aidev ls` | List all `aidev-*` containers. |
| `aidev reload` | Re-run the firewall script (re-reads allow‑lists, refreshes IP rules). |
| `aidev doctor [--verbose]` | Diagnostics + per‑domain IP rule checks. |
| `aidev domains add <host> [host…]` | Add domain(s) to `./.allowed-domains.txt` + reload. |
| `aidev domains remove <host> [host…]` | Remove domain(s) from the project allow‑list + reload. |
| `aidev domains list` | Show both global and project allow‑lists. |
| `aidev domains test <host> [host…]` | Resolve & check ACCEPT rules now (no file edits). |

### Environment variables (optional)
```bash
export SECURE_AI_IMAGE="docker.io/pdrittenhouse/secure-ai-dev:1"  # force the published image
export SECURE_AI_HOME="$HOME/.secure-ai-dev"
export AIDEV_PREFIX="aidev"
export ALLOWLIST_DIR="$HOME/.secure-ai-dev/security/allowlist"
export AIDEV_DOCTOR_DOMAINS="api.github.com api.openai.com"
```

---

## Using VS Code — Attach to the running container (F1)

If you started the container with `aidev`, you can attach without a devcontainer.json.

1. On the host:
   ```bash
   cd /path/to/project
   aidev
   ```
2. In VS Code, **press F1** (or **Shift+Cmd+P / Ctrl+Shift+P**) → **Dev Containers: Attach to Running Container…** → select your `aidev-<folder>-<hash>`.
3. In the attached window: **File → Open Folder… → `/workspaces/app`** (this is your project mount).
4. Verify networking: open a terminal and run `aidev doctor --verbose` or `sudo /opt/security/setup-firewall.sh`.

> If you see only dotfiles like `.bashrc`, you opened the container home. Use **File → Open Folder… → `/workspaces/app`**.

### Alternative: devcontainer.json (optional)
```json
{
  "name": "Secure AI Dev",
  "image": "docker.io/pdrittenhouse/secure-ai-dev:1",
  "workspaceFolder": "/workspaces/app",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspaces/app,type=bind",
  "runArgs": ["--cap-add=NET_ADMIN","--cap-add=NET_RAW","--add-host=host.docker.internal:host-gateway"],
  "mounts": [
    "source=${env:HOME}/.secure-ai-dev/security/allowlist,target=/opt/security/allowlist,type=bind,readonly"
  ],
  "remoteUser": "vscode",
  "postStartCommand": "sudo /opt/security/setup-firewall.sh",
  "shutdownAction": "stopContainer"
}
```

---

## Install & Use **Claude Code** inside the container (zsh & bash)

> The VS Code extension is just the UI. Install the **Claude Code CLI/runtime** where VS Code is running — in the **Dev Container** — so all traffic stays behind the firewall.

### 1) Install the extension in the Dev Container
Extensions → search **Claude Code** → ▼ menu → **Install in Dev Container** (not Local).

### 2) Install the CLI via npm (no sudo; use a per‑user prefix)

**Zsh**
```zsh
npm config set prefix ~/.local
mkdir -p ~/.local/bin
grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.zshrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
npm install -g @anthropic-ai/claude-code
which claude || which claude-code
claude --version 2>/dev/null || claude-code --version 2>/dev/null
```

**Bash**
```bash
npm config set prefix ~/.local
mkdir -p ~/.local/bin
grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.profile || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
source ~/.bashrc
hash -r
npm install -g @anthropic-ai/claude-code
which claude || which claude-code
claude --version 2>/dev/null || claude-code --version 2>/dev/null
```

**Troubleshooting**
- `EACCES: permission denied`: you tried to write to `/usr/lib/node_modules`. Run `npm config set prefix ~/.local` first (no sudo).
- “Oh My Zsh can’t be loaded from: bash”: don’t `source ~/.zshrc` while in bash. Either switch to `zsh` or update `~/.bashrc` as above.
- Still stuck? Fix ownership and retry:
  ```bash
  sudo chown -R "$(id -u)":"$(id -g)" ~/.npm ~/.config || true
  npm install -g @anthropic-ai/claude-code
  ```

### 3) API key (container)
```bash
export ANTHROPIC_API_KEY=sk-ant-…
# Persist for zsh:
grep -q ANTHROPIC_API_KEY ~/.zshrc || echo 'export ANTHROPIC_API_KEY=sk-ant-…' >> ~/.zshrc
# Persist for bash:
grep -q ANTHROPIC_API_KEY ~/.bashrc || echo 'export ANTHROPIC_API_KEY=sk-ant-…' >> ~/.bashrc
```

### 4) Allowlist on the host
```bash
aidev domains add api.anthropic.com
aidev reload
aidev doctor --verbose
```

---

## Git hygiene notes

- ✅ **Commit**: `Dockerfile`, `security/` (scripts, rules), `bin/aidev`, docs.
- 🚫 **Do not commit**: `/.allowed-domains.txt` (per‑project), personal `~/.secure-ai-dev/security/allowlist/global-allowed.txt`.
- Suggested `.gitignore`:
  ```gitignore
  /.allowed-domains.txt
  .DS_Store
  ```

---

## Release checklist

1. Update `security/` or `Dockerfile` as needed.
2. Build & push a new tag (e.g., `:2`).
3. Update README examples to the new tag.
4. Users: `aidev rm && aidev` or Dev Containers → Rebuild Container.

Happy (and safe) shipping! 🚀

