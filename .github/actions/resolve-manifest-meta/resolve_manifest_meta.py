#!/usr/bin/env python3
"""Extract commit/image/ssh_mode values from a manifest JSON file.

Prints values as 3 newline-delimited fields in this order:
1) commit
2) image
3) ssh_mode
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    manifest_path = Path(sys.argv[1])
    commit = ""
    image = ""
    ssh_mode = "public-hardened"

    try:
        with manifest_path.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
        commit = data.get("commit") or data.get("build_commit") or ""
        image = data.get("image") or ""
        ssh_mode = data.get("ssh_mode") or "public-hardened"
    except Exception:
        # Keep defaults/fallbacks when the manifest is missing or malformed.
        pass

    print(commit)
    print(image)
    print(ssh_mode)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
