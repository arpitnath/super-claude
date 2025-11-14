#!/usr/bin/env bash
# Sandbox validator - validates tool permissions before execution
# Checks read/write/network permissions against blacklist and whitelist patterns

set -euo pipefail

validate_permissions() {
    local tool_name="$1"
    local tool_metadata="$2"
    local operation="${3:-}"
    local target_path="${4:-}"

    local read_paths=$(echo "$tool_metadata" | jq -r '.permissions.read // [] | .[]' 2>/dev/null || echo "")
    local write_paths=$(echo "$tool_metadata" | jq -r '.permissions.write // [] | .[]' 2>/dev/null || echo "")
    local network_allowed=$(echo "$tool_metadata" | jq -r '.permissions.network // false' 2>/dev/null || echo "false")

    case "$operation" in
        read)
            validate_read_permission "$tool_name" "$read_paths" "$target_path"
            ;;
        write)
            validate_write_permission "$tool_name" "$write_paths" "$target_path"
            ;;
        network)
            validate_network_permission "$tool_name" "$network_allowed"
            ;;
        *)
            return 0
            ;;
    esac
}

validate_read_permission() {
    local tool_name="$1"
    local allowed_paths="$2"
    local target_path="$3"

    if [ -z "$target_path" ]; then
        return 0
    fi

    if [ -e "$target_path" ]; then
        target_path=$(cd "$(dirname "$target_path")" && pwd)/$(basename "$target_path")
    else
        target_path="$(pwd)/$target_path"
    fi

    if is_blacklisted_path "$target_path"; then
        echo "PERMISSION DENIED: $tool_name cannot read sensitive path: $target_path" >&2
        return 1
    fi

    if [ -z "$allowed_paths" ]; then
        if is_within_project "$target_path"; then
            return 0
        else
            echo "PERMISSION DENIED: $tool_name can only read project files by default" >&2
            return 1
        fi
    fi

    while IFS= read -r allowed_pattern; do
        if path_matches_pattern "$target_path" "$allowed_pattern"; then
            return 0
        fi
    done <<< "$allowed_paths"

    echo "PERMISSION DENIED: $tool_name not allowed to read: $target_path" >&2
    return 1
}

validate_write_permission() {
    local tool_name="$1"
    local allowed_paths="$2"
    local target_path="$3"

    if [ -z "$target_path" ]; then
        return 0
    fi

    if [ -e "$target_path" ]; then
        target_path=$(cd "$(dirname "$target_path")" && pwd)/$(basename "$target_path")
    else
        target_path="$(pwd)/$target_path"
    fi

    if is_blacklisted_path "$target_path"; then
        echo "PERMISSION DENIED: $tool_name cannot write to sensitive path: $target_path" >&2
        return 1
    fi

    if [ -z "$allowed_paths" ]; then
        echo "PERMISSION DENIED: $tool_name has no write permissions" >&2
        return 1
    fi

    while IFS= read -r allowed_pattern; do
        if path_matches_pattern "$target_path" "$allowed_pattern"; then
            return 0
        fi
    done <<< "$allowed_paths"

    echo "PERMISSION DENIED: $tool_name not allowed to write: $target_path" >&2
    return 1
}

validate_network_permission() {
    local tool_name="$1"
    local network_allowed="$2"

    if [ "$network_allowed" = "true" ]; then
        return 0
    else
        echo "PERMISSION DENIED: $tool_name not allowed network access" >&2
        return 1
    fi
}

is_blacklisted_path() {
    local path="$1"

    local blacklist=(
        "$HOME/.ssh"
        "$HOME/.aws"
        "$HOME/.config/gcloud"
        "$HOME/.kube"
        "/etc/passwd"
        "/etc/shadow"
        "/etc/hosts"
    )

    local sensitive_patterns=(
        ".env"
        ".env.local"
        ".env.production"
        "credentials.json"
        "serviceAccount.json"
        "id_rsa"
        "id_ed25519"
        ".pem"
        ".key"
    )

    for blacklisted in "${blacklist[@]}"; do
        if [[ "$path" == "$blacklisted"* ]]; then
            return 0
        fi
    done

    for pattern in "${sensitive_patterns[@]}"; do
        if [[ "$path" == *"$pattern"* ]]; then
            return 0
        fi
    done

    return 1
}

is_within_project() {
    local path="$1"
    local project_root="$(pwd)"

    if [[ "$path" == "$project_root"* ]]; then
        return 0
    else
        return 1
    fi
}

path_matches_pattern() {
    local path="$1"
    local pattern="$2"

    pattern="${pattern/#\~/$HOME}"
    pattern="${pattern//\*\*/__DOUBLESTAR__}"
    pattern="${pattern//\*/[^/]*}"
    pattern="${pattern//__DOUBLESTAR__/.*}"

    if [[ "$path" =~ ^${pattern}$ ]]; then
        return 0
    else
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f validate_permissions
    export -f validate_read_permission
    export -f validate_write_permission
    export -f validate_network_permission
    export -f is_blacklisted_path
    export -f is_within_project
    export -f path_matches_pattern
fi
