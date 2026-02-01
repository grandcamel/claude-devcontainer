#!/usr/bin/env bash
#
# Shared library for claude-devcontainer scripts
#
# Usage: source this file at the top of each script
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/container.sh"
#

# =============================================================================
# Common Configuration
# =============================================================================

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$LIB_DIR/.." && pwd)"
export PROJECT_ROOT  # Used by sourcing scripts

# Default image name (can be overridden via env vars)
DEFAULT_IMAGE_NAME="grandcamel/claude-devcontainer"
DEFAULT_IMAGE_TAG="latest"
IMAGE_NAME="${CLAUDE_DEVCONTAINER_IMAGE:-$DEFAULT_IMAGE_NAME}"
IMAGE_TAG="${CLAUDE_DEVCONTAINER_TAG:-$DEFAULT_IMAGE_TAG}"
export IMAGE_NAME IMAGE_TAG  # Used by sourcing scripts
CLAUDE_CONFIG_TMP_DIR=""

# Plugin/workspace directory (can be overridden by scripts)
PLUGIN_DIR="${CLAUDE_PLUGIN_DIR:-}"
export PLUGIN_DIR  # Used by sourcing scripts

# =============================================================================
# Color Output
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }
echo_status() { echo -e "${CYAN}[$1]${NC} $2"; }
echo_step() { echo -e "${BLUE}==>${NC} ${CYAN}$1${NC}"; }

# =============================================================================
# Cleanup
# =============================================================================

lib_cleanup() {
    local exit_code=$?
    if [[ -n "$CLAUDE_CONFIG_TMP_DIR" && -d "$CLAUDE_CONFIG_TMP_DIR" ]]; then
        rm -rf "$CLAUDE_CONFIG_TMP_DIR"
    fi
    exit $exit_code
}

# Set up cleanup trap (call this in your script's init)
setup_cleanup_trap() {
    trap lib_cleanup EXIT INT TERM
}

# =============================================================================
# OAuth Token Config Setup
# =============================================================================

# Create a temporary .claude directory with config for OAuth token mode
# This ensures hasCompletedOnboarding is set so Claude Code works properly
create_oauth_token_config() {
    CLAUDE_CONFIG_TMP_DIR=$(mktemp -d)
    cat > "$CLAUDE_CONFIG_TMP_DIR/.claude.json" <<'EOF'
{
  "hasCompletedOnboarding": true
}
EOF
    chmod 600 "$CLAUDE_CONFIG_TMP_DIR/.claude.json"
    echo_info "Created OAuth token config (hasCompletedOnboarding: true)"
}

# =============================================================================
# Authentication Validation
# =============================================================================

# Arguments:
#   $1 - USE_API_KEY (true/false)
#   $2 - USE_OAUTH_TOKEN (true/false)
validate_auth() {
    local use_api_key="${1:-false}"
    local use_oauth_token="${2:-false}"

    if [[ "$use_oauth_token" == "true" ]]; then
        # OAuth token mode (Pro/Max subscription, long-lived token)
        if [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
            echo_error "CLAUDE_CODE_OAUTH_TOKEN is not set"
            echo ""
            echo "Generate a token with:"
            echo "  claude setup-token"
            echo ""
            echo "Then export it:"
            echo "  export CLAUDE_CODE_OAUTH_TOKEN='c_oauth_token_...'"
            exit 1
        fi
        # Create config directory with hasCompletedOnboarding flag
        create_oauth_token_config
        echo_info "Using OAuth token (Pro/Max subscription)"
    elif [[ "$use_api_key" == "true" ]]; then
        if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
            echo_error "ANTHROPIC_API_KEY is not set"
            echo ""
            echo "Export your API key:"
            echo "  export ANTHROPIC_API_KEY='sk-ant-api03-...'"
            echo ""
            echo "Or use --oauth-token with CLAUDE_CODE_OAUTH_TOKEN"
            exit 1
        fi
        echo_info "Using API key from environment"
    else
        echo_error "No authentication method specified"
        echo ""
        echo "Use one of:"
        echo "  --oauth-token  Use CLAUDE_CODE_OAUTH_TOKEN (Pro/Max, run 'claude setup-token')"
        echo "  --api-key      Use ANTHROPIC_API_KEY environment variable"
        exit 1
    fi
}

# =============================================================================
# Docker Helpers
# =============================================================================

# Add model environment variable
# Arguments:
#   $1 - model name (haiku, sonnet, opus, or full model ID)
get_model_env() {
    local model="$1"
    case "$model" in
        haiku)
            echo "ANTHROPIC_MODEL=claude-haiku-3-5-20241022"
            ;;
        sonnet)
            echo "ANTHROPIC_MODEL=claude-sonnet-4-20250514"
            ;;
        opus)
            echo "ANTHROPIC_MODEL=claude-opus-4-20250514"
            ;;
        *)
            echo "ANTHROPIC_MODEL=$model"
            ;;
    esac
}
