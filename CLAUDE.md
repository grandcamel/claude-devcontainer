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
- **lib/container.sh**: Shared shell functions for authentication, image management, and Docker run helpers
- **scripts/run.sh**: Main entry point that handles argument parsing, authentication validation, and container execution
- **scripts/build-team-image.sh**: Generates customized Dockerfiles from YAML configs (parses YAML with embedded Python)
- **config/**: Configuration files copied into enhanced images (starship.toml, tmux.conf, setup-enhanced.sh)

## Authentication Flow

One of the following authentication methods is required:

1. **OAuth Token** (`--oauth-token`): Uses `CLAUDE_CODE_OAUTH_TOKEN` env var. For Pro/Max users, generate with `claude setup-token`.
2. **API Key** (`--api-key`): Uses `ANTHROPIC_API_KEY` env var.

The `validate_auth()` function in `lib/container.sh` handles authentication validation.

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
