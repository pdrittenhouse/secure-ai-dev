#!/usr/bin/env bash
set -euo pipefail
FILE="/opt/security/permissions/claude-code.json"
if jq empty "$FILE" >/dev/null 2>&1; then
  echo "[security] Permissions policy OK"
else
  echo "[security] Permissions policy INVALID JSON" >&2
  exit 1
fi
