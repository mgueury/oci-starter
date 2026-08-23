#!/usr/bin/env bash
#
# Serialize OCI Starter commands that change infrastructure or deployments.
# This uses mkdir instead of flock so it works on the macOS build hosts used by
# OCI Starter and leaves useful diagnostic metadata for a waiting operator.

BUILD_LOCK_DIR=""
BUILD_LOCK_OWNER=""

build_lock_acquire() {
    local command_name="$1"
    local lock_pid stale_dir

    if [ -z "${TARGET_DIR:-}" ]; then
        echo "ERROR: TARGET_DIR must be set before acquiring the build lock" >&2
        return 1
    fi

    BUILD_LOCK_DIR="$TARGET_DIR/build.lock"
    BUILD_LOCK_OWNER="$$-$(date '+%s')"
    while ! (umask 077; mkdir "$BUILD_LOCK_DIR") 2>/dev/null; do
        lock_pid="$(cat "$BUILD_LOCK_DIR/pid" 2>/dev/null || true)"

        if [ -z "$lock_pid" ]; then
            echo "ERROR: OCI Starter build lock exists but its metadata is incomplete: $BUILD_LOCK_DIR" >&2
            echo "Remove it manually after confirming no build command is running." >&2
            return 1
        fi

        if kill -0 "$lock_pid" 2>/dev/null; then
            echo "ERROR: OCI Starter build command is already running (PID $lock_pid): $BUILD_LOCK_DIR" >&2
            echo "Wait for it to finish before starting another build command." >&2
            return 1
        fi

        stale_dir="$BUILD_LOCK_DIR.stale.$$"
        if mv "$BUILD_LOCK_DIR" "$stale_dir" 2>/dev/null; then
            echo "Recovering stale OCI Starter build lock from dead PID $lock_pid." >&2
            rm -rf "$stale_dir"
        fi
    done

    if ! (
        umask 077
        printf '%s\n' "$$" > "$BUILD_LOCK_DIR/pid"
        printf '%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$BUILD_LOCK_DIR/started_at"
        printf '%s\n' "$command_name" > "$BUILD_LOCK_DIR/command"
        printf '%s\n' "$BUILD_LOCK_OWNER" > "$BUILD_LOCK_DIR/owner"
    ); then
        echo "ERROR: could not write OCI Starter build lock metadata" >&2
        rm -rf "$BUILD_LOCK_DIR"
        return 1
    fi
}

build_lock_release() {
    local lock_owner

    [ -n "$BUILD_LOCK_DIR" ] || return 0
    [ -d "$BUILD_LOCK_DIR" ] || return 0

    lock_owner="$(cat "$BUILD_LOCK_DIR/owner" 2>/dev/null || true)"
    if [ "$lock_owner" = "$BUILD_LOCK_OWNER" ]; then
        rm -rf "$BUILD_LOCK_DIR"
    fi
}

build_lock_register_cleanup() {
    trap 'build_lock_release' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP
}

build_lock_unlock_stale() {
    local lock_pid

    if [ -z "${TARGET_DIR:-}" ]; then
        echo "ERROR: TARGET_DIR must be set before unlocking the build lock" >&2
        return 1
    fi

    BUILD_LOCK_DIR="$TARGET_DIR/build.lock"
    if [ ! -e "$BUILD_LOCK_DIR" ]; then
        echo "No OCI Starter build lock exists."
        return 0
    fi

    if [ ! -d "$BUILD_LOCK_DIR" ]; then
        echo "ERROR: OCI Starter build lock is not a directory: $BUILD_LOCK_DIR" >&2
        return 1
    fi

    lock_pid="$(cat "$BUILD_LOCK_DIR/pid" 2>/dev/null || true)"
    if ! [[ "$lock_pid" =~ ^[1-9][0-9]*$ ]]; then
        echo "ERROR: OCI Starter build lock has no valid PID: $BUILD_LOCK_DIR" >&2
        return 1
    fi

    if kill -0 "$lock_pid" 2>/dev/null; then
        echo "ERROR: OCI Starter build command is still running (PID $lock_pid): $BUILD_LOCK_DIR" >&2
        return 1
    fi

    rm -rf "$BUILD_LOCK_DIR"
    echo "Removed stale OCI Starter build lock from dead PID $lock_pid."
}
