#!/usr/bin/env python3
"""Expand project_agents.md.stub into a per-project AGENTS.md."""
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 4:
        print(
            "usage: write-project-agents-md.py STUB OUT PROJECT_NAME",
            file=sys.stderr,
        )
        sys.exit(2)
    stub, out, project = sys.argv[1:4]
    text = Path(stub).read_text()
    text = text.replace("___PROJECT___", project)
    Path(out).write_text(text)


if __name__ == "__main__":
    main()
