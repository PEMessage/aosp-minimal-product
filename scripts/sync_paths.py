#!/usr/bin/env python3
"""Extract build/ and prebuilts/ project paths from an AOSP manifest.

Excludes projects tagged groups containing "notdefault" or "darwin"
(not needed for Linux builds). Prints one path per line.
"""

import re
import sys


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
        if path.startswith(("build/", "prebuilts/")):
            projects.append(path)

    print("\n".join(projects))
    return 0


if __name__ == "__main__":
    sys.exit(main())
