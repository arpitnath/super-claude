#!/bin/bash
# Tool runner - universal tool execution framework with sandboxing
# Supports bash, python, node, go, and binary tools with permission validation and audit logging

TOOL_RUNNER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCK_ROOT="$(cd "$TOOL_RUNNER_DIR/../.." && pwd)"
CLAUDE_TOOLS_DIR="$SCK_ROOT/.claude/tools"
TOOLS_CACHE="$HOME/.claude/.tools_cache.json"

SANDBOX_VALIDATOR="$TOOL_RUNNER_DIR/sandbox-validator.sh"
AUDIT_LOGGER="$TOOL_RUNNER_DIR/audit-logger.sh"

if [[ -f "$SANDBOX_VALIDATOR" ]]; then
    source "$SANDBOX_VALIDATOR"
fi

if [[ -f "$AUDIT_LOGGER" ]]; then
    source "$AUDIT_LOGGER"
fi

log_tool() {
    echo "[tool-runner] $*" >&2
}

error_tool() {
    echo "[tool-runner ERROR] $*" >&2
}

discover_tools() {
    local tools_json="[]"

    if [[ -d "$CLAUDE_TOOLS_DIR" ]]; then
        for tool_manifest in "$CLAUDE_TOOLS_DIR"/*/tool.json; do
            if [[ -f "$tool_manifest" ]]; then
                local tool_dir="$(dirname "$tool_manifest")"
                local tool_name="$(basename "$tool_dir")"

                if command -v jq >/dev/null 2>&1; then
                    local tool_meta=$(cat "$tool_manifest")
                    tool_meta=$(echo "$tool_meta" | jq --arg dir "$tool_dir" '. + {tool_dir: $dir}')
                    tools_json=$(echo "$tools_json" | jq --argjson tool "$tool_meta" '. += [$tool]')
                fi
            fi
        done
    fi

    echo "$tools_json" > "$TOOLS_CACHE"
    echo "$tools_json"
}

get_tool_metadata() {
    local tool_name="$1"

    if [[ ! -f "$TOOLS_CACHE" ]] || [[ $(find "$TOOLS_CACHE" -mmin +60 2>/dev/null) ]]; then
        discover_tools >/dev/null
    fi

    if command -v jq >/dev/null 2>&1; then
        cat "$TOOLS_CACHE" | jq -r ".[] | select(.name == \"$tool_name\")"
    else
        error_tool "jq is required for tool metadata parsing"
        return 1
    fi
}

run_tool() {
    local tool_name="$1"
    shift
    local tool_params=("$@")

    if [[ -z "$tool_name" ]]; then
        error_tool "Tool name is required"
        return 1
    fi

    if command -v log_tool_execution >/dev/null 2>&1; then
        log_tool_execution "$tool_name" "execute" "started" "${tool_params[*]}"
    fi

    local start_time=$(date +%s%3N)

    local metadata=$(get_tool_metadata "$tool_name")
    if [[ -z "$metadata" ]]; then
        error_tool "Tool not found: $tool_name"
        error_tool "Available tools: $(list_tools)"
        if command -v log_tool_execution >/dev/null 2>&1; then
            log_tool_execution "$tool_name" "execute" "failed" "tool_not_found"
        fi
        return 1
    fi

    local tool_type=$(echo "$metadata" | jq -r '.type // "bash"')
    local tool_entry=$(echo "$metadata" | jq -r '.entry')
    local tool_dir=$(echo "$metadata" | jq -r '.tool_dir')
    local timeout=$(echo "$metadata" | jq -r '.timeout // 300')

    if [[ -z "$tool_entry" ]] || [[ "$tool_entry" == "null" ]]; then
        error_tool "Tool '$tool_name' has no entry point defined"
        if command -v log_tool_execution >/dev/null 2>&1; then
            log_tool_execution "$tool_name" "execute" "failed" "no_entry_point"
        fi
        return 1
    fi

    if [[ -z "$tool_dir" ]] || [[ "$tool_dir" == "null" ]]; then
        error_tool "Tool '$tool_name' has no directory defined"
        if command -v log_tool_execution >/dev/null 2>&1; then
            log_tool_execution "$tool_name" "execute" "failed" "no_directory"
        fi
        return 1
    fi

    local exit_code=0
    case "$tool_type" in
        bash)
            timeout "${timeout}s" bash -c "$(declare -f run_bash_tool); run_bash_tool '$tool_dir' '$tool_entry' ${tool_params[*]@Q}" || exit_code=$?
            ;;
        python)
            timeout "${timeout}s" bash -c "$(declare -f run_python_tool); run_python_tool '$tool_dir' '$tool_entry' ${tool_params[*]@Q}" || exit_code=$?
            ;;
        node|javascript)
            timeout "${timeout}s" bash -c "$(declare -f run_node_tool); run_node_tool '$tool_dir' '$tool_entry' ${tool_params[*]@Q}" || exit_code=$?
            ;;
        go)
            timeout "${timeout}s" bash -c "$(declare -f run_go_tool); run_go_tool '$tool_dir' '$tool_entry' ${tool_params[*]@Q}" || exit_code=$?
            ;;
        binary)
            timeout "${timeout}s" bash -c "$(declare -f run_binary_tool); run_binary_tool '$tool_dir' '$tool_entry' ${tool_params[*]@Q}" || exit_code=$?
            ;;
        *)
            error_tool "Unsupported tool type: $tool_type"
            if command -v log_tool_execution >/dev/null 2>&1; then
                log_tool_execution "$tool_name" "execute" "failed" "unsupported_type:$tool_type"
            fi
            return 1
            ;;
    esac

    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    if command -v log_tool_execution >/dev/null 2>&1; then
        if [ $exit_code -eq 0 ]; then
            log_tool_execution "$tool_name" "execute" "success" "duration:${duration}ms"
        elif [ $exit_code -eq 124 ]; then
            log_tool_execution "$tool_name" "execute" "failed" "timeout:${timeout}s"
        else
            log_tool_execution "$tool_name" "execute" "failed" "exit_code:$exit_code"
        fi
    fi

    return $exit_code
}

run_bash_tool() {
    local tool_dir="$1"
    local entry="$2"
    shift 2

    local script_path="$tool_dir/$entry"
    if [[ ! -f "$script_path" ]]; then
        error_tool "Script not found: $script_path"
        return 1
    fi

    bash "$script_path" "$@"
}

run_python_tool() {
    local tool_dir="$1"
    local entry="$2"
    shift 2

    local script_path="$tool_dir/$entry"
    if [[ ! -f "$script_path" ]]; then
        error_tool "Script not found: $script_path"
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        error_tool "python3 is required for this tool"
        return 1
    fi

    python3 "$script_path" "$@"
}

run_node_tool() {
    local tool_dir="$1"
    local entry="$2"
    shift 2

    local script_path="$tool_dir/$entry"
    if [[ ! -f "$script_path" ]]; then
        error_tool "Script not found: $script_path"
        return 1
    fi

    if ! command -v node >/dev/null 2>&1; then
        error_tool "node is required for this tool"
        return 1
    fi

    node "$script_path" "$@"
}

run_go_tool() {
    local tool_dir="$1"
    local entry="$2"
    shift 2

    local go_path="$tool_dir/$entry"

    if ! command -v go >/dev/null 2>&1; then
        error_tool "go is required for this tool"
        return 1
    fi

    (cd "$tool_dir" && go run "$entry" "$@")
}

run_binary_tool() {
    local tool_dir="$1"
    local entry="$2"
    shift 2

    local bin_path="$tool_dir/$entry"
    if [[ ! -f "$bin_path" ]]; then
        error_tool "Binary not found: $bin_path"
        return 1
    fi

    if [[ ! -x "$bin_path" ]]; then
        error_tool "Binary is not executable: $bin_path"
        return 1
    fi

    "$bin_path" "$@"
}

list_tools() {
    if [[ ! -f "$TOOLS_CACHE" ]] || [[ $(find "$TOOLS_CACHE" -mmin +60 2>/dev/null) ]]; then
        discover_tools >/dev/null
    fi

    if command -v jq >/dev/null 2>&1; then
        cat "$TOOLS_CACHE" | jq -r '.[].name' | tr '\n' ', ' | sed 's/,$//'
    else
        echo "jq required"
    fi
}

tool_info() {
    local tool_name="$1"

    if [[ -z "$tool_name" ]]; then
        error_tool "Tool name is required"
        return 1
    fi

    local metadata=$(get_tool_metadata "$tool_name")
    if [[ -z "$metadata" ]]; then
        error_tool "Tool not found: $tool_name"
        return 1
    fi

    echo "$metadata" | jq .
}

export -f run_tool
export -f list_tools
export -f tool_info
export -f discover_tools
export -f get_tool_metadata
