# Dev sandbox for Claude Code: Node.js, Go, Rust and common CLI tools.
# Toolchains track the upstream major tags; rebuild to update them.

FROM golang:1-bookworm AS go
FROM rust:1-slim-bookworm AS rust

FROM node:24-trixie-slim

ARG CLAUDE_CODE_VERSION=latest
ARG XRAY_VERSION=""
ARG XRAY_SHA256=""
ARG CADDY_VERSION=2.11.7
ARG CADDY_SHA256=727b91701a392de6ebc5027509f548bf39979e5216340d0faed8fa5e69c84f8b

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
      build-essential \
      ca-certificates \
      chromium \
      curl \
      dbus \
      dbus-x11 \
      fonts-dejavu-core \
      git \
      jq \
      less \
      libcairo2-dev \
      libgdk-pixbuf-2.0-dev \
      libglib2.0-dev \
      libgtk-4-dev \
      libpango1.0-dev \
      libssl-dev \
      openssh-client \
      pkg-config \
      procps \
      python3 \
      python3-pip \
      python3-venv \
      ripgrep \
      unzip \
      x11-utils \
      xauth \
      xvfb \
      zsh \
    && mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install --no-install-recommends -y gh \
    && git config --system credential.https://github.com.helper '!/usr/bin/gh auth git-credential' \
    && rm -rf /var/lib/apt/lists/*

COPY --from=go /usr/local/go /usr/local/go
COPY --from=rust /usr/local/rustup /usr/local/rustup
COPY --from=rust /usr/local/cargo /usr/local/cargo

ENV PATH=/usr/local/go/bin:/usr/local/cargo/bin:$PATH \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    DISABLE_AUTOUPDATER=1

RUN rustup component add rustfmt clippy && \
    npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} && \
    chown -R node:node /usr/local/cargo /usr/local/rustup

RUN if [ -n "${XRAY_VERSION}" ]; then \
      set -eux; \
      case "$(dpkg --print-architecture)" in \
        amd64) asset="Xray-linux-64.zip" ;; \
        arm64) asset="Xray-linux-arm64-v8a.zip" ;; \
        *) echo "unsupported architecture"; exit 1 ;; \
      esac; \
      curl -fsSL -o /tmp/xray.zip \
        "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/${asset}"; \
      echo "${XRAY_SHA256}  /tmp/xray.zip" | sha256sum -c -; \
      unzip -j /tmp/xray.zip xray -d /usr/local/bin; \
      chmod +x /usr/local/bin/xray; \
      rm -f /tmp/xray.zip; \
    fi

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
      adwaita-icon-theme \
      gdb \
      hicolor-icon-theme \
      librsvg2-common \
      librsvg2-dev \
      linux-perf \
      shellcheck \
      sqlite3 \
      strace \
      valgrind \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/caddy.tar.gz \
      "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_$(dpkg --print-architecture).tar.gz" \
    && echo "${CADDY_SHA256}  /tmp/caddy.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/caddy.tar.gz -C /usr/local/bin caddy \
    && chmod +x /usr/local/bin/caddy \
    && rm -f /tmp/caddy.tar.gz

# Chromium's own sandbox cannot start under this container's cap-drop=ALL;
# the container is the sandbox boundary, so disable Chromium's inner sandbox.
RUN printf '#!/bin/sh\nexec /usr/bin/chromium --no-sandbox "$@"\n' \
      > /usr/local/bin/chromium-no-sandbox \
    && chmod +x /usr/local/bin/chromium-no-sandbox

COPY .zshrc /home/node/.zshrc
RUN mkdir -p /workspace && chown -R node:node /home/node /workspace

USER node
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/claude"]
