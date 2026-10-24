# Claude Sandbox

Run Claude Code in a Podman or Docker container with Node.js, Go, Rust and common CLI tools. Only the current project directory and a dedicated sandbox home directory are visible inside the container.

## Quick start

Requires Podman (recommended) or Docker, plus `make`.

Build the image:

```sh
make build
```

Copy your host Claude Code setup into the sandbox config (settings, skills, plugins, `.claude.json`, git identity):

```sh
make setup
```

Run Claude Code from any project directory:

```sh
/path/to/claude-sandbox/scripts/claude-box
```

Or add an alias:

```sh
alias claude-box='/path/to/claude-sandbox/scripts/claude-box'
```

`make run` runs the same script from the current directory.

On rootless Podman the script adds `--userns=keep-id:uid=1000,gid=1000`, so files created in the project stay owned by your host user.

## What is mounted

| Host | Container |
| --- | --- |
| current directory | `/workspace/<project-name>` |
| `~/.claude-sandbox` | `/home/node` |

The sandbox home contains `.claude`, `.claude.json`, `.gitconfig` and `.config/gh`. Everything else on the host is outside the container. The container runs as the non-root `node` user with `--cap-drop=ALL` and `--security-opt=no-new-privileges`.

Networking defaults to host networking (`--network=host`) so local services and local API proxies are reachable. Set `SANDBOX_NETWORK=bridge` when you do not need them.

## Configuration

`make setup` copies the following from the host:

- `~/.claude/settings.json` — including the `env` block, so a third-party Anthropic-compatible endpoint and token keep working;
- `~/.claude/skills` and `~/.claude/plugins` — including enabled plugins;
- `~/.claude.json` — user-level MCP servers and Claude state (kept if already present);
- `~/.gitconfig` — git identity.

Re-run `make setup` after changing the host config. Skills and plugins are replaced; `.claude.json` is left alone once it exists. MCP servers added inside the container (`claude mcp add -s user`) persist in the mounted `.claude.json`.

Other environment variables: `IMAGE` (default `claude-sandbox`), `CONTAINER_RUNTIME` (default `podman`, then `docker`), `CLAUDE_SANDBOX_CONFIG` (default `~/.claude-sandbox`).

### GitHub and Codeberg

The image includes `gh`, and the launcher reuses the host login: if `GH_TOKEN` is unset, it runs `gh auth token` on the host and forwards the result to the container as `GH_TOKEN`. The token goes through the environment, not the `podman run` command line. A host already logged in with `gh auth login` therefore needs no extra step.

```sh
claude-box --shell
gh auth status
```

If the host has no `gh` login, authenticate once inside the sandbox. The token is then stored in `~/.claude-sandbox/.config/gh` and survives container restarts.

```sh
claude-box --shell
gh auth login
```

Git is preconfigured through `/etc/gitconfig` to use `gh` as its HTTPS credential helper, so `git push` works without running `gh auth setup-git`. Set `GH_TOKEN` yourself to override the automatic lookup.

Codeberg uses a personal access token. Generate one with `repository: Read and Write` and `Specific repositories` for the target repo, then store it in the sandbox home:

```sh
read -rsp 'Codeberg token: ' CB_TOKEN; echo
printf 'https://YOUR_USERNAME:%s@codeberg.org\n' "$CB_TOKEN" > ~/.claude-sandbox/.git-credentials
unset CB_TOKEN
chmod 600 ~/.claude-sandbox/.git-credentials
make setup
```

`make setup` registers git's built-in `store` helper for `https://codeberg.org`; the credentials file is mode 600 and only visible inside the sandbox. Re-run `make setup` after rotating the token, and never put the token in the remote URL.

## Security boundary

This is container isolation, not a virtual machine: containers share the host kernel. The mounted project and config directories are writable from inside. Host networking also exposes services listening on localhost. The config directory holds the Claude token and a Codeberg personal access token in `.git-credentials` (mode 600); a `gh` login created inside the sandbox also stores a plaintext GitHub token in `.config/gh/hosts.yml`. When reusing the host GitHub login, the token is passed to the container as an environment variable instead. Use a VM if you need a stronger boundary against deliberately malicious code.

## Development

Install pre-commit for local lint and pre-commit checks.

```bash
pip install pre-commit
```

Install the git hook scripts:

```bash
pre-commit install
```

Run against all files if you need to do a full check:

```bash
pre-commit run --all-files
```

## Clean up

Remove the image:

```sh
make clean
```

Remove the image and all sandbox config (session context and memory included):

```sh
make clean-all
```
