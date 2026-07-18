# Project conventions

When adding or modifying a skill in this repo:

- Run `scripts/validate_skills.py` before declaring the work done — same script CI runs.
- Update the skill index in `README.md` (alphabetical, under `## Skills`).

When editing either `settings.json` or `settings-with-statusline.json`:

- Apply the change to both. They must carry identical configuration, differing only by the statusLine block the second file adds.
- Run `scripts/validate_settings.sh` before declaring the work done — same script CI runs.
