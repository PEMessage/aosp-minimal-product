#!/usr/bin/env bash
# Print the minimal build/ + curated prebuilts/ project paths for `m nothing`.
#
# The LineageOS 19.1 manifest lists many prebuilts (ndk, sdk, rust,
# maven_repo, module_sdk, ...) that `m nothing` never touches; syncing them all
# would turn a 5-minute sync into a multi-GB one.  So take every build/*
# project the manifest carries and only the prebuilts on the allowlist below.
# Works before anything is checked out (see scripts/repo-list.sh).  Prints one
# path per line.
#
# Usage: scripts/sync_paths.sh [/path/to/aosp/tree]     # defaults to $PWD
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TREE="${1:-$PWD}"

# Curated prebuilts needed for soong/kati to boot and `m nothing` to go green.
# (clang and the legacy host gcc are NOT needed: nothing builds cc modules.)
PREBUILT_ALLOW=(
    prebuilts/build-tools           # ckati, ninja, make, flex, bison, go
    prebuilts/clang/host/linux-x86  # host clang for building ckati from source
    prebuilts/go/linux-x86          # go toolchain soong_ui bootstraps with
    prebuilts/jdk/jdk11             # Java 11 required by Android 12
)

# repo-list.sh prints name:path, so $2 is the path; select build/*, then append
# the curated prebuilts.
{
    "$HERE/repo-list.sh" "$TREE" | awk -F: '$2 ~ /^build\// { print $2 }'
    printf '%s\n' "${PREBUILT_ALLOW[@]}"
} | sort -u
