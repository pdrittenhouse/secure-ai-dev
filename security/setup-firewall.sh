#!/usr/bin/env bash
set -euo pipefail
echo "[security] default-deny egress"

# IPv4/IPv6 default deny
sudo iptables -F OUTPUT || true
sudo iptables -P OUTPUT DROP
sudo ip6tables -F OUTPUT || true
sudo ip6tables -P OUTPUT DROP

# Loopback + established/related
sudo iptables  -A OUTPUT -o lo -j ACCEPT
sudo ip6tables -A OUTPUT -o lo -j ACCEPT
sudo iptables  -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo ip6tables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# DNS (tcp/udp 53)
sudo iptables  -A OUTPUT -p udp --dport 53 -j ACCEPT
sudo iptables  -A OUTPUT -p tcp --dport 53 -j ACCEPT
sudo ip6tables -A OUTPUT -p udp --dport 53 -j ACCEPT
sudo ip6tables -A OUTPUT -p tcp --dport 53 -j ACCEPT

allow_domain() {
  local d="$1"
  # resolve both v4/v6; tolerate failures
  for ip in $(getent ahosts "$d" | awk '{print $1}' | sort -u); do
    if [[ "$ip" =~ : ]]; then
      sudo ip6tables -A OUTPUT -d "$ip" -j ACCEPT || true
    else
      sudo iptables  -A OUTPUT -d "$ip" -j ACCEPT || true
    fi
  done
}

# Global allowlist
ALLOW="${ALLOWLIST_GLOBAL:-/opt/security/allowlist/global-allowed.txt}"
if [[ -f "$ALLOW" ]]; then
  while read -r d; do
    [[ -z "$d" || "$d" =~ ^# ]] && continue
    allow_domain "$d"
  done < "$ALLOW"
fi

# Per-project extra domains
PROJECT_ALLOW="/workspaces/app/.allowed-domains.txt"
if [[ -f "$PROJECT_ALLOW" ]]; then
  while read -r d; do
    [[ -z "$d" || "$d" =~ ^# ]] && continue
    allow_domain "$d"
  done < "$PROJECT_ALLOW"
fi

echo "[security] egress rules applied."
