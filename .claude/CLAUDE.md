# Project conventions

When adding or modifying a skill in this repo:

- Run `scripts/validate_skills.py` before declaring the work done — same script CI runs.
- Update the skill index in `README.md` (alphabetical, under `## Skills`).

When editing `settings.json` or `statusline.json`:

- `settings.json` holds everything shared by both install variants. `statusline.json` holds the statusLine block and nothing else.
- `settings-with-statusline.json` is generated from those two by `scripts/build_settings.sh` and is git-ignored. Never edit it by hand.
- Run `scripts/build_settings.sh` after any change so the live symlinks pick it up, then `scripts/validate_settings.sh` before declaring the work done — same script CI runs.
- Claude Code writes `/model` and `/config` choices through the symlink into the generated file, where git cannot see them. The build script prints what a rebuild would drop. Move any of it worth keeping into `settings.json`, then rebuild.
