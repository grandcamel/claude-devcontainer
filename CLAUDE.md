# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a batteries-included developer container optimized for Claude Code. It provides Docker images with pre-installed toolchains (Python, Node.js, Go, Rust), modern CLI tools, and flexible authentication modes (OAuth from macOS Keychain or API key).

## Key Commands

### Running the Container

```bash
# Basic usage (current directory mounted, OAuth auth)
./scripts/run.sh

# Mount specific project
./scripts/run.sh --project ~/myproject

# Use pre-built enhanced image (instant startup with modern CLI tools)
./scripts/run.sh --use-enhanced

# Install additional packages at runtime
./scripts/run.sh --pip flask,sqlalchemy --npm lodash --apt graphviz

# API key authentication
./scripts/run.sh --api-key              # uses ANTHROPIC_API_KEY env var
./scripts/run.sh --api-key-from-config  # reads from ~/.claude.json
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

1. **OAuth (default on macOS)**: Reads credentials from macOS Keychain via `security find-generic-password`, creates temp directory with `.credentials.json`, mounts to container
2. **API Key**: Either from `ANTHROPIC_API_KEY` env var or `primaryApiKey` from `~/.claude.json`

The `validate_auth()` function in `lib/container.sh` handles all authentication modes.

## Team Image Customization

Create a YAML config file (see `examples/team-config.yaml`) specifying:
- Base image and output image name/tag
- Corporate CA certificate
- pip, npm, apt packages to pre-install
- Environment variables and labels

The `build-team-image.sh` script parses YAML using embedded Python and generates a Dockerfile.team that can be version-controlled.

## CI/CD

GitHub Actions workflow (`.github/workflows/docker-build.yml`) builds both base and enhanced images on push to main, uses Docker layer caching, and runs basic validation tests on PRs.
