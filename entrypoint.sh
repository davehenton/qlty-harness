#!/usr/bin/env bash
#
# Qlty coverage Harness plugin entrypoint.
#
# Harness Plugin-step `settings:` arrive as PLUGIN_<UPPERCASE_KEY> environment
# variables. This script maps them to `qlty coverage publish` flags, mirroring
# the qlty CircleCI orb's publish command.
set -eu

QLTY_BIN="$HOME/.qlty/bin/qlty"

# --- Install the qlty CLI (runtime install; pinnable via `qlty_version`) ------
if [ -n "${PLUGIN_QLTY_VERSION:-}" ]; then
    export QLTY_VERSION="${PLUGIN_QLTY_VERSION}"
fi

if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://qlty.sh/install.sh | sh
elif command -v wget >/dev/null 2>&1; then
    wget -qO- https://qlty.sh/install.sh | sh
else
    echo "curl or wget is required to install qlty" >&2
    exit 1
fi

export PATH="$HOME/.qlty/bin:$PATH"
"$QLTY_BIN" --version

# --- Build the publish command from plugin settings ---------------------------
params=()

add_param() {
    local flag=$1
    local value=$2
    if [ -n "$value" ]; then
        params+=("$flag" "$value")
    fi
}

add_param "--tag" "${PLUGIN_TAG:-}"
add_param "--format" "${PLUGIN_FORMAT:-}"
add_param "--add-prefix" "${PLUGIN_ADD_PREFIX:-}"
add_param "--strip-prefix" "${PLUGIN_STRIP_PREFIX:-}"
add_param "--name" "${PLUGIN_NAME:-}"

# Required for workspace-scoped tokens (prefix `qltcw_`); harmless otherwise.
add_param "--project" "${PLUGIN_PROJECT:-}"

# --total-parts-count 1 conflicts with --incomplete, so only pass it when > 1.
if [ -n "${PLUGIN_TOTAL_PARTS_COUNT:-}" ] && [ "${PLUGIN_TOTAL_PARTS_COUNT}" != "1" ]; then
    add_param "--total-parts-count" "${PLUGIN_TOTAL_PARTS_COUNT}"
fi

if [ "${PLUGIN_INCOMPLETE:-false}" = "true" ]; then
    params+=("--incomplete")
fi

if [ "${PLUGIN_SKIP_MISSING_FILES:-false}" = "true" ]; then
    params+=("--skip-missing-files")
fi

if [ "${PLUGIN_VERBOSE:-false}" = "true" ]; then
    params+=("--verbose")
fi

if [ "${PLUGIN_DRY_RUN:-false}" = "true" ]; then
    params+=("--dry-run")
fi

# Validation is enabled by default in the CLI, so only act when disabling or
# when a custom threshold is set.
if [ "${PLUGIN_VALIDATE:-true}" = "true" ]; then
    add_param "--validate-file-threshold" "${PLUGIN_VALIDATE_FILE_THRESHOLD:-}"
else
    params+=("--no-validate")
fi

# Token: prefer the explicit setting, else fall back to QLTY_COVERAGE_TOKEN,
# which the CLI reads from the environment on its own.
if [ -n "${PLUGIN_TOKEN:-}" ]; then
    params+=("--token" "${PLUGIN_TOKEN}")
fi

# Working directory (defaults to the Harness workspace root).
cd "${PLUGIN_WORKING_DIRECTORY:-.}" || exit 1

# Coverage files: comma- or whitespace-separated, trimmed of blanks.
files=()
if [ -n "${PLUGIN_FILES:-}" ]; then
    IFS=', ' read -r -a raw_files <<< "${PLUGIN_FILES}"
    for f in "${raw_files[@]}"; do
        [ -n "$f" ] && files+=("$f")
    done
fi

# --- Run, redacting the token in the echoed command ---------------------------
print_redacted() {
    local out=() skip=0
    for arg in "$@"; do
        if [ "$skip" = "1" ]; then
            out+=("***")
            skip=0
        elif [ "$arg" = "--token" ]; then
            out+=("$arg")
            skip=1
        else
            out+=("$arg")
        fi
    done
    echo "Running: ${out[*]}"
}

print_redacted "$QLTY_BIN" coverage publish "${files[@]}" "${params[@]}"

set +e
"$QLTY_BIN" coverage publish "${files[@]}" "${params[@]}"
status=$?
set -e

# skip_errors (default true): a coverage upload failure should not fail the build.
if [ "${PLUGIN_SKIP_ERRORS:-true}" = "true" ]; then
    exit 0
fi
exit "$status"
