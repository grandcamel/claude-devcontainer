# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a batteries-included developer container optimized for Claude Code. It provides Docker images with pre-installed toolchains (Python, Node.js, Go, Rust), modern CLI tools, and two authentication modes (OAuth Token or API Key).

## Key Commands

### Running the Container

```bash
# Mount specific project with OAuth token auth
./scripts/run.sh --oauth-token --project ~/myproject

# Use pre-built enhanced image (instant startup with modern CLI tools)
./scripts/run.sh --oauth-token --use-enhanced

# Install additional packages at runtime
./scripts/run.sh --oauth-token --pip flask,sqlalchemy --npm lodash --apt graphviz

# Authentication options (one required)
./scripts/run.sh --oauth-token  # uses CLAUDE_CODE_OAUTH_TOKEN (Pro/Max, generate with 'claude setup-token')
./scripts/run.sh --api-key      # uses ANTHROPIC_API_KEY env var
```

### Building Images

```bash
# Build enhanced image with pre-installed tools
./scripts/build-enhanced.sh

# Build with corporate CA certificate
./scripts/build-enhanced.sh --ca-cert zscaler.crt

# Build team-customized image from config
./scripts/build-team-image.sh --config team-config.yaml --build

# Publish to private registry
./scripts/publish-to-registry.sh --config team-config.yaml --registry harbor.company.com
```

### Testing

```bash
# Build and test base image
docker build -t test-base -f Dockerfile .
docker run --rm test-base python3 --version

# Build and test enhanced image
docker build -t test-enhanced -f Dockerfile.enhanced .
docker run --rm test-enhanced which starship
```

## Architecture

- **Dockerfile**: Base image with Python, Node.js, Go, Rust, AWS CLI, database clients
- **Dockerfile.enhanced**: Extended image with modern CLI tools (starship, eza, bat, delta, zoxide, btop, lazygit, tmux, neovim)
- **lib/container.sh**: Shared shell functions for authentication and Docker run helpers
- **scripts/run.sh**: Main entry point that handles argument parsing, authentication validation, and container execution
- **scripts/build-team-image.sh**: Generates customized Dockerfiles from YAML configs (parses YAML with embedded Python)
- **config/**: Configuration files copied into enhanced images (starship.toml, tmux.conf)

## Code Conventions

### Dockerfile Patterns

- **Dockerfile.enhanced inherits from base**: Uses `FROM grandcamel/claude-devcontainer:latest` to avoid duplicating base setup
- **Config files over echo chains**: Multi-line configurations go in `config/` directory and are COPYed in, not built with echo commands

### Shell Script Patterns

- **Source shared library**: All scripts in `scripts/` should `source "$SCRIPT_DIR/../lib/container.sh"` for colors and common functions
- **Constants in lib/container.sh**: DEFAULT_IMAGE_NAME, DEFAULT_IMAGE_TAG, and other shared constants defined once
- **No dead code**: Remove flags, variables, and code paths that aren't fully implemented

### Common Mistakes to Avoid

- Don't duplicate base Dockerfile content in extended images
- Don't hardcode the same value (like image names) in multiple files
- Don't add argument parsing for features that aren't implemented
- Don't reference environment variables that don't exist

## Authentication Flow

One of the following authentication methods is required:

1. **OAuth Token** (`--oauth-token`): Uses `CLAUDE_CODE_OAUTH_TOKEN` env var. For Pro/Max users, generate with `claude setup-token`. The script automatically creates a temp `.claude.json` with `hasCompletedOnboarding: true` (required for OAuth token to work in containers).
2. **API Key** (`--api-key`): Uses `ANTHROPIC_API_KEY` env var.

The `validate_auth()` function in `lib/container.sh` handles authentication validation and config setup.

## Team Image Customization

Create a YAML config file (see `examples/team-config.yaml`) specifying:

- Base image and output image name/tag
- Corporate CA certificate
- pip, npm, apt packages to pre-install
- Environment variables and labels

The `build-team-image.sh` script parses YAML using embedded Python and generates a Dockerfile.team that can be version-controlled.

## Git Workflow

- **Never push directly to `main`** — Always create a PR branch
- **Rebase merge only** — Maintain linear history
- **Delete branches after merge**

```bash
git checkout -b feature/my-change
git push -u origin feature/my-change
gh pr create
gh pr merge --rebase --delete-branch
```

## CI/CD

GitHub Actions workflow (`.github/workflows/docker-build.yml`) builds both base and enhanced images on push to main, uses Docker layer caching, and runs basic validation tests on PRs.

## Pre-commit Hooks

Pre-commit hooks are configured in `.pre-commit-config.yaml`:

```bash
# Install hooks (one-time setup)
pre-commit install

# Run on all files
pre-commit run --all-files

# Bypass hooks for direct commits to main (use sparingly)
git commit --no-verify -m "message"
```

### Configured Hooks

| Hook                | Purpose                       |
| ------------------- | ----------------------------- |
| trailing-whitespace | Remove trailing whitespace    |
| end-of-file-fixer   | Ensure files end with newline |
| check-yaml/json     | Validate syntax               |
| no-commit-to-branch | Block direct commits to main  |
| prettier            | Format JS/JSON/YAML/Markdown  |
| gitleaks            | Detect hardcoded secrets      |
| shellcheck          | Lint shell scripts            |
| hadolint            | Lint Dockerfiles              |

### Hadolint Ignored Rules

| Rule   | Reason                                                    |
| ------ | --------------------------------------------------------- |
| DL3007 | Using `:latest` tag intentional for enhanced image        |
| DL3008 | Pin apt versions impractical for dev containers           |
| DL3013 | Pin pip versions handled by explicit upgrades             |
| DL3016 | Pin npm versions - use latest intentionally               |
| DL3059 | Multiple consecutive RUN improves readability             |
| DL3062 | Pin go install versions - use @latest for security        |
| DL4006 | pipefail not critical for dev containers                  |
| SC2016 | Single quotes intentional (prevent expansion in .profile) |
| SC2028 | echo escape sequences intentional (PS1 prompt colors)     |
| SC2086 | ARG variables safe unquoted in Dockerfile context         |

## Lessons Learned & Security

### Go Dependency Vulnerabilities

**Problem**: Go tools (gopls, dlv, golangci-lint) compile in vulnerable versions of `golang.org/x/crypto` and `golang.org/x/net` at build time.

**Solution**: Rebuild tools after Go upgrade to pull patched dependencies:

```dockerfile
ARG GO_VERSION=1.25.6
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" | tar -C /usr/local -xzf -

# Rebuild tools with patched dependencies
RUN go install golang.org/x/tools/gopls@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest \
    && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```

**Key insight**: Simply upgrading Go isn't enough—pre-compiled tools retain old dependencies until rebuilt.

### Python Package CVEs

**Problem**: System Python packages (setuptools, wheel) may have CVEs even after `apt-get upgrade`.

**Solution**: Explicitly upgrade known-vulnerable packages with minimum versions:

```dockerfile
RUN pip3 install --break-system-packages --upgrade \
    "setuptools>=78.1.1" \
    "wheel>=0.46.2" \
    "jaraco.context>=6.1.0"
```

### Pre-commit no-commit-to-branch

**Behavior**: The `no-commit-to-branch` hook blocks commits directly to main. This is intentional to enforce PR workflow.

**Workaround**: For legitimate direct commits (releases, CI fixes), use `--no-verify`:

```bash
git commit --no-verify -m "fix: emergency hotfix"
```

### Hadolint Local vs CI

**Issue**: Hadolint may not be installed locally but runs in CI via `hadolint-action`.

**Solution**: Pre-commit config includes hadolint, but failures are expected locally if not installed. CI is the source of truth for Dockerfile linting.

### Security Scanning in CI

The `security-scan` job runs after lint and includes:

- `npm audit --audit-level=high` - Node.js dependency vulnerabilities
- `pip-audit` - Python dependency vulnerabilities
- `bandit` - Python static security analysis

These use `|| true` to report without blocking, as some findings may be false positives or upstream issues.
