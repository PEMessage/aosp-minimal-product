#!/usr/bin/env bash
# List every project the manifest knows about as name:path, without syncing.
#
# `repo list` only reports projects that are already checked out, so it is
# useless for deciding what to sync on a fresh tree.  `repo manifest` reads the
# manifest itself (including code/.repo/local_manifests/) and works before any
# project exists.  xmlstarlet renders each <project> and awk fills in the
# default path: the manifest may omit path=, in which case it equals name.
# The output is plain text, so callers compose it with grep/awk:
#
#   scripts/repo-list.sh | grep build/
#
# Usage:
#   scripts/repo-list.sh [tree]     # tree defaults to $PWD
set -euo pipefail

TREE="${1:-$PWD}"

need() { command -v "$1" >/dev/null || { echo "error: missing: $1" >&2; exit 1; }; }
need repo
need xmlstarlet

( cd "$TREE" && repo manifest ) \
    | xmlstarlet sel -t -m '//project' -v '@name' -o ':' -v '@path' -n \
    | awk -F: '{ print $1 ":" ($2 ? $2 : $1) }'
