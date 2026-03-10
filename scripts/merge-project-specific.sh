#!/bin/bash
# merge-project-specific.sh
# Merge source file into target while preserving target's PROJECT-SPECIFIC block.
#
# Usage: ./scripts/merge-project-specific.sh SOURCE TARGET
#   or:  merge_project_specific SOURCE TARGET  (when sourced)
#
# Algorithm:
#   1. Read source file
#   2. Read target file (if exists)
#   3. Extract target content between PROJECT-SPECIFIC markers
#   4. Replace block between same markers in source with extracted block
#   5. Write result to target path
#
# Edge cases:
#   - Target missing → copy source as-is
#   - Markers missing in target → use source's block
#
# Markers: <!-- PROJECT-SPECIFIC - AUTO-UPDATED - START --> ... <!-- PROJECT-SPECIFIC - AUTO-UPDATED - END -->

set -euo pipefail

START_MARKER='<!-- PROJECT-SPECIFIC - AUTO-UPDATED - START -->'
END_MARKER='<!-- PROJECT-SPECIFIC - AUTO-UPDATED - END -->'

merge_project_specific() {
    local src="$1"
    local dst="$2"

    if [[ ! -f "$src" ]]; then
        echo "Error: source file does not exist: ${src}" >&2
        return 1
    fi

    # Target missing → copy source as-is
    if [[ ! -f "$dst" ]]; then
        cp "$src" "$dst"
        return 0
    fi

    # Extract block from target (between markers, inclusive)
    local block_file
    block_file=$(mktemp)
    trap 'rm -f "$block_file"' RETURN

    awk -v start="$START_MARKER" -v end="$END_MARKER" '
        $0 ~ start { flag = 1 }
        flag { print; if ($0 ~ end) flag = 0 }
    ' "$dst" > "$block_file"

    # Markers missing in target → use source's block (copy source as-is)
    if [[ ! -s "$block_file" ]]; then
        cp "$src" "$dst"
        return 0
    fi

    # Replace block in source with target's block; write to temp then mv (handles src==dst)
    local out_file
    out_file=$(mktemp)
    trap 'rm -f "$block_file" "$out_file"' RETURN

    awk -v blockfile="$block_file" -v start="$START_MARKER" -v end="$END_MARKER" '
        BEGIN {
            while ((getline line < blockfile) > 0)
                block = block line "\n"
        }
        $0 ~ start {
            printf "%s", block
            skip = 1
            next
        }
        skip && $0 ~ end {
            skip = 0
            next
        }
        skip { next }
        { print }
    ' "$src" > "$out_file"

    mv "$out_file" "$dst"
}

# Main: when run as script, parse args and invoke
if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]]; then
    if [[ $# -ne 2 ]]; then
        echo "Usage: $(basename "$0") SOURCE TARGET" >&2
        echo "" >&2
        echo "Merge source into target, preserving target's PROJECT-SPECIFIC block" >&2
        echo "between <!-- PROJECT-SPECIFIC - AUTO-UPDATED - START/END --> markers." >&2
        exit 1
    fi
    merge_project_specific "$1" "$2"
fi
