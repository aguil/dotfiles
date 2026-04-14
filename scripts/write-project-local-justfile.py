#!/usr/bin/env python3
"""Expand project_local_justfile.stub into a per-project Justfile."""
import json
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 5:
        print(
            "usage: write-project-local-justfile.py STUB OUT MODULE_PATH PROJECT_NAME",
            file=sys.stderr,
        )
        sys.exit(2)
    stub, out, mod_path, project = sys.argv[1:5]
    text = Path(stub).read_text()
    text = text.replace("___MODULE___", json.dumps(mod_path))
    text = text.replace("___PROJECT___", json.dumps(project))
    Path(out).write_text(text)


if __name__ == "__main__":
    main()
