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

## Using with VS Code Dev Containers

You can work two ways. **Pick one per project** (don’t mix them at the same time).

### Option A — Attach to a running `aidev` container (no repo config)
1. In your project on the host:
   ```bash
   aidev
   ```
2. VS Code → Command Palette (Press F1 / Shift+Cmd+P / Ctrl+Shift+P) → **Dev Containers: Attach to Running Container…**  
   Choose the container named `aidev-<folder>-<hash>`.
3. In the container, your project is at **/workspaces/app**. Open a terminal (it should say `vscode@<container>`).

**To refresh to a new image:** on the host run `aidev rm && aidev`, then re-attach.

### Option B — Use `.devcontainer/devcontainer.json` (VS Code creates the container)
Create `.devcontainer/devcontainer.json` in your repo:

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
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-azuretools.vscode-docker",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "EditorConfig.EditorConfig"
      ]
    }
  },
  "shutdownAction": "stopContainer"
}
```

Open your folder in VS Code, then: **Dev Containers → Reopen in Container**.

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

---

### Tips & Troubleshooting
- **Firewall didn’t load?** Check the `postStartCommand` logs (Terminal → Output → Dev Containers) or run `aidev doctor --verbose` inside the container.
- **Host services (LocalWP) from Linux?** We add `--add-host=host.docker.internal:host-gateway`. Use `host.docker.internal` from inside the container.
- **Updating the image:** change the `image` tag in `devcontainer.json` and run **Rebuild Container**.
- **Per‑project allowlist:** use `aidev domains add api.openai.com` on the host to create/update `./.allowed-domains.txt`.
- **Attaching the wrong folder:** In the VS Code container window press F1 → File: Open Folder…, type /workspaces/app → OK. You should now see your project files. Then type File: Open Folder… → /workspaces/app (VS Code can remember this per container window).