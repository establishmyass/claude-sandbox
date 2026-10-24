# Dev sandbox for Claude Code: Node.js, Go, Rust and common CLI tools.
# Toolchains track the upstream major tags; rebuild to update them.

FROM golang:1-bookworm AS go
FROM rust:1-slim-bookworm AS rust

FROM node:24-bookworm-slim

ARG CLAUDE_CODE_VERSION=latest

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
      build-essential \
      ca-certificates \
      curl \
      git \
      jq \
      less \
      libssl-dev \
      openssh-client \
      pkg-config \
      procps \
      ripgrep \
      unzip \
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

RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} && \
    chown -R node:node /usr/local/cargo /usr/local/rustup

COPY .zshrc /home/node/.zshrc
RUN mkdir -p /workspace && chown -R node:node /home/node /workspace

USER node
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/claude"]
