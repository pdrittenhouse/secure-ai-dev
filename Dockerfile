FROM mcr.microsoft.com/devcontainers/base:bookworm

ENV NODE_VERSION=20 PHP_VERSION=8.2

# Base tooling (iptables for firewall; dnsutils for getent; sudo for entrypoint)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git jq dnsutils iptables iproute2 iputils-ping sudo \
    php${PHP_VERSION} php${PHP_VERSION}-cli php${PHP_VERSION}-curl php${PHP_VERSION}-xml php${PHP_VERSION}-mbstring php${PHP_VERSION}-zip \
    unzip less vim net-tools \
 && rm -rf /var/lib/apt/lists/*

# Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
 && apt-get update && apt-get install -y nodejs \
 && rm -rf /var/lib/apt/lists/*

# WP-CLI (OK to keep for WP workflows)
RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp \
 && chmod +x /usr/local/bin/wp

# Security payload
COPY security /opt/security
RUN chmod -R 755 /opt/security

# Use the pre-existing vscode user from the devcontainers base image
USER vscode
WORKDIR /workspaces/app

# On start: apply firewall, then keep container alive
ENTRYPOINT ["bash","-lc","sudo /opt/security/setup-firewall.sh && exec sleep infinity"]
