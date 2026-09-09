#!/usr/bin/env python3
"""Extract the minimal build/ + prebuilts/ project paths for `m nothing`.

The LineageOS 19.1 manifest lists many prebuilts (ndk, sdk, rust, maven_repo,
module_sdk, ...) that `m nothing` never touches. Pulling them all would turn a
5-minute sync into a multi-GB one, so only the prebuilts on the allowlist are
kept. Excludes projects tagged "notdefault" or "darwin" (not needed on Linux).
Prints one path per line.
"""

import re
import sys

# Curated prebuilts needed for soong/kati to boot and `m nothing` to go green.
# (clang and the legacy host gcc are NOT needed: nothing builds cc modules.)
PREBUILT_ALLOW = {
    "prebuilts/build-tools",  # ckati, ninja, make, flex, bison, go
    "prebuilts/clang/host/linux-x86",  # host clang for building ckati from source
    "prebuilts/go/linux-x86",  # go toolchain soong_ui bootstraps with
    "prebuilts/jdk/jdk11",  # Java 11 required by Android 12
}


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} /path/to/aosp/tree", file=sys.stderr)
        return 2

    manifest = f"{sys.argv[1]}/.repo/manifests/default.xml"
    try:
        content = open(manifest, encoding="utf-8").read()
    except OSError as e:
        print(f"error: cannot read {manifest}: {e}", file=sys.stderr)
        return 1

    projects = []
    for m in re.finditer(r'<project[^>]*path="([^"]+)"[^>]*>', content):
        path, tag = m.group(1), m.group(0)
        groups = re.search(r'groups="([^"]+)"', tag)
        group_str = groups.group(1) if groups else ""
        if "notdefault" in group_str or "darwin" in group_str:
            continue
        if path.startswith("build/"):
            projects.append(path)
        elif path in PREBUILT_ALLOW:
            projects.append(path)

    print("\n".join(projects))
    return 0


if __name__ == "__main__":
    sys.exit(main())
