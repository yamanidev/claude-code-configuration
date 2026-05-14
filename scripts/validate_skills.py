#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["strictyaml>=1.7.3"]
# ///

"""
Validates every skills/<name>/SKILL.md against the Agent Skills spec.

Mirrors the validation rules and the YAML library used by the official
`skills-ref` reference library (https://github.com/agentskills/agentskills)
without taking on skills-ref as a dependency.

- skills-ref is marked "demonstration purposes only" by its maintainers
and is pre-release (no PyPI publish, no version tags, install from Git).
- skills-ref's ALLOWED_FIELDS rejects any frontmatter key outside the
six spec-defined ones, including Claude Code extension fields such as
`disable-model-invocation`, which this repo plans to adopt.

TODO: migrate to `skills-ref validate` once it ships a stable, tagged
release and either expands its allow-list to include client extension
fields or exposes an `--allow-unknown-fields` flag. Track:
https://github.com/agentskills/agentskills/releases
"""

import re
import sys
import unicodedata
from pathlib import Path

import strictyaml

SKILLS_DIR = Path("skills")
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
NAME_MAX = 64
DESC_MAX = 1024
FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---", re.S)

problems: list[str] = []


def flag(file: Path, msg: str) -> None:
    problems.append(f"{file}: {msg}")


dirs = sorted(p for p in SKILLS_DIR.iterdir() if p.is_dir())

for skill_dir in dirs:
    file = skill_dir / "SKILL.md"

    if not file.is_file():
        flag(file, "missing SKILL.md")
        continue

    text = file.read_text(encoding="utf-8")
    match = FRONTMATTER_RE.match(text)
    if not match:
        flag(
            file,
            "no YAML frontmatter (expected file to start with "
            "---<newline>...<newline>---)",
        )
        continue

    try:
        fm = strictyaml.load(match.group(1)).data
    except strictyaml.YAMLError as e:
        flag(file, f"YAML parse error: {str(e).splitlines()[0]}")
        continue

    if not isinstance(fm, dict):
        flag(file, "frontmatter must be a mapping")
        continue

    name = fm.get("name")
    description = fm.get("description")

    if not isinstance(name, str) or not name.strip():
        flag(file, "name is missing or not a non-empty string")
    else:
        name_n = unicodedata.normalize("NFKC", name.strip())
        if len(name_n) > NAME_MAX:
            flag(file, f"name is {len(name_n)} chars; max is {NAME_MAX}")
        if not NAME_RE.match(name_n):
            flag(
                file,
                f'name "{name_n}" does not match '
                "^[a-z0-9]+(-[a-z0-9]+)*$ "
                "(lowercase a-z, 0-9, hyphens; "
                "no leading/trailing/consecutive hyphens)",
            )
        dir_n = unicodedata.normalize("NFKC", skill_dir.name)
        if dir_n != name_n:
            flag(
                file,
                f'name "{name_n}" does not match '
                f'parent directory "{skill_dir.name}"',
            )

    if not isinstance(description, str) or not description.strip():
        flag(file, "description is missing or not a non-empty string")
    elif len(description) > DESC_MAX:
        flag(
            file,
            f"description is {len(description)} chars; max is {DESC_MAX}",
        )

if problems:
    for p in problems:
        print(f"❌ {p}", file=sys.stderr)

    print(
        f"\n🛑 {len(problems)} problem(s) across {len(dirs)} skill(s).",
        file=sys.stderr,
    )

    sys.exit(1)

print(f"✅ {len(dirs)} skill(s) validated.")
