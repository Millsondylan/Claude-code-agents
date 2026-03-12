#!/bin/bash
# generate-agents.sh
# DEPRECATED: This repo uses OpenCode (.opencode/agents/) as the source of truth.
# Edit agents directly in .opencode/agents/ — do NOT use .claude/agents/.
#
# Legacy: This script converted .claude/agents/ -> .opencode/agents/.
# It is kept for reference only. Running it would overwrite .opencode/agents/
# with stale .claude/ content. Do not run.
echo "DEPRECATED: This repo uses .opencode/agents/ as source of truth. Do not run generate-agents.sh." >&2
exit 1

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve paths relative to the repo root (the directory containing this
# script's parent directory, i.e. two levels up from .opencode/).
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${REPO_ROOT}/.claude/agents"
TARGET_DIR="${REPO_ROOT}/.opencode/agents"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Model provider constants.
# ---------------------------------------------------------------------------
PROVIDER_PRIMARY="alibaba-coding-plan/kimi-k2.5"
PROVIDER_KIMI="kimi-for-coding/k2p5"
PROVIDER_GLM="zai-coding-plan/glm-5"

# ---------------------------------------------------------------------------
# Agents that always use the primary model (Kimi K2.5) regardless of their model alias.
# ---------------------------------------------------------------------------
is_primary_agent() {
    local basename="$1"
    case "${basename}" in
        prompt-optimizer.md | code-discovery.md | plan-agent.md | test-writer.md | \
        debugger.md | debugger-2.md | debugger-3.md | debugger-4.md | debugger-5.md | \
        debugger-6.md | debugger-7.md | debugger-8.md | debugger-9.md | debugger-10.md | \
        debugger-11.md | logical-agent.md | review-agent.md | decide-agent.md | \
        pipeline-scaler.md | pre-flight-checker.md | integration-agent.md | \
        project-customizer.md | web-syntax-researcher.md | claude-in-chrome.md)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# Determine model for a numbered build agent based on rotation pattern.
# Agents where (N-1)%5 < 3  → Kimi K2.5  (positions 1,2,3 of every group of 5)
# Agents where (N-1)%5 >= 3 → GLM-5      (positions 4,5 of every group of 5)
# The deprecated build-agent.md (no number) → Kimi
# ---------------------------------------------------------------------------
build_agent_model() {
    local basename="$1"
    # Match build-agent-N.md (numbered) or build-agent.md (deprecated base).
    if [[ "${basename}" =~ ^build-agent-([0-9]+)\.md$ ]]; then
        local n="${BASH_REMATCH[1]}"
        local remainder=$(( (n - 1) % 5 ))
        if (( remainder < 3 )); then
            echo "${PROVIDER_KIMI}"
        else
            echo "${PROVIDER_GLM}"
        fi
    else
        # build-agent.md (deprecated) → Kimi
        echo "${PROVIDER_KIMI}"
    fi
}

# ---------------------------------------------------------------------------
# Map a Claude Code model alias to the OpenCode provider/model-id string.
# $1 = model alias from frontmatter (opus, sonnet, haiku, inherit, or full ID)
# $2 = agent basename (e.g. build-agent-1.md) — used for provider routing
# Returns empty string for "inherit" (field should be omitted).
# ---------------------------------------------------------------------------
map_model() {
    local model="$1"
    local basename="${2:-}"

    # Agents explicitly assigned to the primary model always get it, even if their
    # source frontmatter says "inherit".
    if is_primary_agent "${basename}"; then
        echo "${PROVIDER_PRIMARY}"
        return
    fi

    # "inherit" means no model field in output (for non-primary agents).
    if [[ "${model}" == "inherit" ]]; then
        echo ""
        return
    fi

    # Build agents: route by rotation pattern.
    if [[ "${basename}" =~ ^build-agent ]]; then
        build_agent_model "${basename}"
        return
    fi

    # task-breakdown and docs-researcher → Kimi K2.5
    if [[ "${basename}" == "task-breakdown.md" || "${basename}" == "docs-researcher.md" ]]; then
        echo "${PROVIDER_KIMI}"
        return
    fi

    # test-agent → GLM-5
    if [[ "${basename}" == "test-agent.md" ]]; then
        echo "${PROVIDER_GLM}"
        return
    fi

    # All remaining aliases: map by the alias value.
    case "${model}" in
        opus)    echo "${PROVIDER_PRIMARY}" ;;
        sonnet)  echo "${PROVIDER_KIMI}" ;;
        haiku)   echo "${PROVIDER_GLM}" ;;
        # Pass through any already-qualified model IDs unchanged.
        *)       echo "${model}" ;;
    esac
}

# Map a color word to its hex equivalent.
map_color() {
    local color="$1"
    case "${color}" in
        purple)  echo "#800080" ;;
        blue)    echo "#0000FF" ;;
        yellow)  echo "#FFD700" ;;
        cyan)    echo "#00FFFF" ;;
        red)     echo "#FF0000" ;;
        orange)  echo "#FFA500" ;;
        green)   echo "#008000" ;;
        pink)    echo "#FFC0CB" ;;
        # If value already looks like a hex code, pass through.
        \#*)     echo "${color}" ;;
        # Unknown color names: pass through verbatim.
        *)       echo "${color}" ;;
    esac
}

# Convert a comma-separated tools string into an indented YAML boolean map.
# Input:  "Write, Read, Edit, Grep, Glob, Bash, TodoWrite"
# Output:
#   write: true
#   read: true
#   ...
# MCP tool names (mcp__*) are kept verbatim in lower-case.
build_tools_yaml() {
    local raw_tools="$1"
    local output=""

    # Split on commas; strip surrounding whitespace from each token.
    IFS=',' read -ra tool_list <<< "${raw_tools}"
    for tool in "${tool_list[@]}"; do
        # Trim leading/trailing whitespace.
        tool="${tool#"${tool%%[![:space:]]*}"}"
        tool="${tool%"${tool##*[![:space:]]}"}"

        if [[ -z "${tool}" ]]; then
            continue
        fi

        # Map Claude Code tool names to OpenCode tool keys (lower-case).
        local key
        case "${tool}" in
            Write)      key="write" ;;
            Read)       key="read" ;;
            Edit)       key="edit" ;;
            Bash)       key="bash" ;;
            Grep)       key="grep" ;;
            Glob)       key="glob" ;;
            TodoWrite)  key="todowrite" ;;
            WebSearch)  key="websearch" ;;
            WebFetch)   key="webfetch" ;;
            Task)       key="task" ;;
            # MCP tools keep their name, just lower-cased.
            mcp__*)     key="$(printf '%s' "${tool}" | tr '[:upper:]' '[:lower:]')" ;;
            # Unknown: lower-case verbatim.
            *)          key="$(printf '%s' "${tool}" | tr '[:upper:]' '[:lower:]')" ;;
        esac

        output+="  ${key}: true"$'\n'
    done

    # Strip trailing newline.
    printf '%s' "${output%$'\n'}"
}

# Determine whether a filename should be marked hidden: true in OpenCode.
# Hidden = internal pipeline agents not shown in @ autocomplete.
# Visible (hidden: false) = user-facing entry-point agents.
is_hidden() {
    local filename="$1"  # basename without path
    case "${filename}" in
        # These two are the user-facing entry points.
        pipeline-scaler.md | task-breakdown.md)
            echo "false" ;;
        *)
            echo "true" ;;
    esac
}

# ---------------------------------------------------------------------------
# Process one agent file.
# Arguments: $1 = full path to source .md file
# ---------------------------------------------------------------------------
process_file() {
    local src_file="$1"
    local basename
    basename="$(basename "${src_file}")"
    local dest_file="${TARGET_DIR}/${basename}"

    # Read the entire source file.
    local content
    content="$(cat "${src_file}")"

    # Check if the file begins with a YAML frontmatter block (---).
    if ! printf '%s\n' "${content}" | head -1 | grep -q '^---'; then
        echo "  SKIP (no frontmatter): ${basename}"
        return
    fi

    # ---------------------------------------------------------------------------
    # Parse YAML frontmatter.
    # The frontmatter is between the first and second "---" lines.
    # We extract field values using awk for reliability with multi-line content.
    # ---------------------------------------------------------------------------

    # Extract raw frontmatter block (lines between first and second ---).
    local frontmatter
    frontmatter="$(awk '
        /^---/ { count++; if (count == 1) next; if (count == 2) exit }
        count == 1 { print }
    ' "${src_file}")"

    # Extract simple single-line fields.
    local fm_description fm_tools fm_model fm_color
    fm_description="$(printf '%s\n' "${frontmatter}" | awk -F': ' '/^description:/ { sub(/^description: */, ""); print; exit }')"
    fm_tools="$(printf '%s\n' "${frontmatter}" | awk -F': ' '/^tools:/ { sub(/^tools: */, ""); print; exit }')"
    fm_model="$(printf '%s\n' "${frontmatter}" | awk '/^model:/ { sub(/^model: */, ""); print; exit }')"
    fm_color="$(printf '%s\n' "${frontmatter}" | awk '/^color:/ { sub(/^color: */, ""); print; exit }')"

    # ---------------------------------------------------------------------------
    # Extract markdown body (everything after the closing --- of frontmatter).
    # ---------------------------------------------------------------------------
    local body
    body="$(awk '
        /^---/ { count++; if (count == 2) { found=1; next } }
        found { print }
    ' "${src_file}")"

    # ---------------------------------------------------------------------------
    # Build transformed values.
    # ---------------------------------------------------------------------------
    local oc_model
    oc_model="$(map_model "${fm_model}" "${basename}")"

    local oc_hidden
    oc_hidden="$(is_hidden "${basename}")"

    local oc_color
    if [[ -n "${fm_color}" ]]; then
        oc_color="$(map_color "${fm_color}")"
    else
        oc_color=""
    fi

    local oc_tools_yaml
    oc_tools_yaml="$(build_tools_yaml "${fm_tools}")"

    # ---------------------------------------------------------------------------
    # Write output file.
    # ---------------------------------------------------------------------------
    {
        printf '%s\n' "---"

        # description
        printf 'description: "%s"\n' "${fm_description}"

        # mode: all user-facing agents get "primary", others get "subagent"
        if [[ "${oc_hidden}" == "false" ]]; then
            printf 'mode: primary\n'
        else
            printf 'mode: subagent\n'
        fi

        # model (omit for "inherit")
        if [[ -n "${oc_model}" ]]; then
            printf 'model: %s\n' "${oc_model}"
        fi

        # hidden
        printf 'hidden: %s\n' "${oc_hidden}"

        # color (optional)
        if [[ -n "${oc_color}" ]]; then
            printf 'color: "%s"\n' "${oc_color}"
        fi

        # tools
        if [[ -n "${oc_tools_yaml}" ]]; then
            printf 'tools:\n'
            printf '%s\n' "${oc_tools_yaml}"
        fi

        printf '%s\n' "---"

        # Preserve the markdown body exactly as-is.
        printf '%s\n' "${body}"

    } > "${dest_file}"

    echo "  OK: ${basename} -> ${dest_file}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo "=== OpenCode Agent Generator ==="
    echo "Source : ${SOURCE_DIR}"
    echo "Target : ${TARGET_DIR}"
    echo ""

    # Ensure target directory exists.
    mkdir -p "${TARGET_DIR}"

    local processed=0
    local skipped=0

    # Iterate over all .md files in the source directory; skip README.md.
    for src_file in "${SOURCE_DIR}"/*.md; do
        local basename
        basename="$(basename "${src_file}")"

        if [[ "${basename}" == "README.md" ]]; then
            echo "  SKIP (README): ${basename}"
            (( skipped++ )) || true
            continue
        fi

        process_file "${src_file}"
        (( processed++ )) || true
    done

    echo ""
    echo "Done. Processed: ${processed} files, Skipped: ${skipped} files."
}

main "$@"
