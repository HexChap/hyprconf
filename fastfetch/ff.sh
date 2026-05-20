#!/usr/bin/env bash

set -euo pipefail

# === Settings ===
BASE_CONFIG="$HOME/.config/fastfetch/config-nerv.jsonc"
TEMP_CONFIG="/tmp/fastfetch_config.json"
CLEAN_CONFIG="/tmp/clean_config.json"
smallLogo="$HOME/.config/fastfetch/nerv-ascii-sm.txt"
largeLogo="$HOME/.config/fastfetch/nerv-ascii-l.txt"
gap=0  # Desired gap between logo and modules

# === Defaults for toggles (can be overridden by CLI flags or env vars) ===
center_x=${FF_CENTER_X:-0}                           # env var fallback (default: disabled)
modules_padding_top=${FF_MODULES_PADDING_TOP:-0}     # env var fallback (default: 0)
logo_right=${FF_LOGO_RIGHT:-0}                       # env var fallback (default: left)

# === CLI arg parsing ===
show_help() {
    cat <<'EOF'
Usage: ff.sh [OPTIONS] -- [fastfetch args]

Options:
  --center-x, -X               Enable horizontal centering (default: disabled)
  --modules-padding-top N, -T N Set number of break modules for top padding (default: 0)
                               Can specify different values for small/large: --modules-padding-top 3:10
                               (3 for small terminal, 10 for large terminal)
  --logo-right, -R             Position logo on the right side (default: left)
  -h, --help                   Show this help

Any remaining args after options will be passed to fastfetch.
You can also set env vars FF_CENTER_X=1, FF_MODULES_PADDING_TOP=N or FF_MODULES_PADDING_TOP=N:M, and/or FF_LOGO_RIGHT=1
EOF
}

# === Parse arguments ===
parse_args() {
    local args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --center-x|-X)
                center_x=1
                shift
                ;;
            --modules-padding-top|-T)
                if [[ -n "${2:-}" ]]; then
                    if [[ "$2" =~ ^[0-9]+:[0-9]+$ ]]; then
                        # Format: small:large
                        modules_padding_top="$2"
                    elif [[ "$2" =~ ^[0-9]+$ ]]; then
                        # Single number, use for both
                        modules_padding_top="$2"
                    else
                        echo "Error: --modules-padding-top requires a numeric argument or small:large format (e.g., 3:10)" >&2
                        exit 1
                    fi
                    shift 2
                else
                    echo "Error: --modules-padding-top requires a numeric argument" >&2
                    exit 1
                fi
                ;;
            --logo-right|-R)
                logo_right=1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --) # end of flags; remaining args are for fastfetch
                shift
                args+=("$@")
                break
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    FASTFETCH_ARGS=("${args[@]}")
}

# === Utility functions ===
cleanup() {
    rm -f "$TEMP_CONFIG" "$CLEAN_CONFIG" 2>/dev/null || true
}

strip_config_comments() {
    perl -0777 -pe '
      # remove lines that are only // comments
      s/^[ \t]*\/\/.*\n//mg;
      # remove commas that are directly followed only by whitespace and then ] or }
      s/,(?=\s*[\]\}])//g;
    ' "$BASE_CONFIG" > "$CLEAN_CONFIG"
}

get_logo_config() {
    local cols="$1"

    if (( cols >= 119 )); then
        echo "$largeLogo" 4
    else
        echo "$smallLogo" 0
    fi
}

get_modules_padding_top() {
    local cols="$1" padding_spec="$2"

    if [[ "$padding_spec" == *:* ]]; then
        # Format: small:large - split on colon
        local small_padding="${padding_spec%:*}"
        local large_padding="${padding_spec#*:}"

        if (( cols >= 119 )); then
            echo "$large_padding"
        else
            echo "$small_padding"
        fi
    else
        # Single value or default
        echo "$padding_spec"
    fi
}

apply_modules_padding_top() {
    local padding_count="$1"

    if (( padding_count > 0 )); then
        jq --arg count "$padding_count" '
          .modules = (
            [ range( ($count | try tonumber catch 0) ) | "break" ]
            + (.modules | map(select(type == "object")))
          )
        ' "$CLEAN_CONFIG" > "$TEMP_CONFIG"
    else
        cp "$CLEAN_CONFIG" "$TEMP_CONFIG"
    fi
}

measure_fastfetch_width() {
    fastfetch -c "$TEMP_CONFIG" --logo "$1" --pipe \
        | cat -t \
        | awk '/^\^/ {print}' \
        | sed -E 's/\^\[\[([[:digit:]]+)C/\1 /g' \
        | awk '{print $1 + length - length($1)}' \
        | sort -n -r \
        | head -n 1
}

is_enabled() {
    local value="$1"
    [[ "$value" == "1" || "$value" == "true" ]]
}

calculate_padding() {
    local cols="$1" max_width="$2" key_padding_left="$3"
    local total_width left_padding key_padding

    # If centering is disabled, skip width calculations entirely
    if ! is_enabled "$center_x"; then
        left_padding=0
        key_padding=$key_padding_left
    else
        total_width=$((max_width + gap))
        left_padding=$(( (cols - total_width) / 2 ))
        [[ $left_padding -lt 0 ]] && left_padding=0
        key_padding=$left_padding
    fi

    if is_enabled "$logo_right"; then
        echo "$left_padding" "$key_padding" "right" "--logo-padding-right"
    else
        echo "$left_padding" "$key_padding" "left" "--logo-padding-left"
    fi
}

# === Main execution ===
main() {
    parse_args "$@"
    trap cleanup EXIT

    # Get terminal width
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)

    # Strip comments from config
    strip_config_comments

    # Get logo configuration
    read -r logo key_padding_left < <(get_logo_config "$cols")

    # Get modules padding top based on terminal size
    local actual_modules_padding_top
    actual_modules_padding_top=$(get_modules_padding_top "$cols" "$modules_padding_top")

    # Apply modules padding top
    apply_modules_padding_top "$actual_modules_padding_top"

    # Only measure output width if centering is enabled
    local max_width=0
    if is_enabled "$center_x"; then
        max_width=$(measure_fastfetch_width "$logo" || echo 0)
    fi

    read -r left_padding key_padding logo_pos logo_pad_opt < <(calculate_padding "$cols" "$max_width" "$key_padding_left")

    # Run Fastfetch with calculated padding
    fastfetch -c "$TEMP_CONFIG" \
        --logo "$logo" \
        --key-padding-left "$key_padding" \
        "$logo_pad_opt" "$left_padding" \
        --logo-position "$logo_pos" \
        "${FASTFETCH_ARGS[@]}"
}

main "$@"
