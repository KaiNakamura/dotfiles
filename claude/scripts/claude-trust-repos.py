#!/usr/bin/env python3
"""Mark git repos/worktrees as trusted for Claude Code (headless `claude -p`).

Sets projects[<abs path>].hasTrustDialogAccepted = true in ~/.claude.json for
every git repo or worktree directly under ~/repos, plus any paths given as args.
Idempotent; backs up ~/.claude.json (timestamped) before writing a change.
"""
import json, os, shutil, sys, tempfile, time
from pathlib import Path

CONFIG = Path.home() / ".claude.json"
REPOS = Path.home() / "repos"


def targets(extra):
    paths = []
    if REPOS.is_dir():
        paths += [p for p in sorted(REPOS.iterdir()) if p.is_dir() and (p / ".git").exists()]
    for a in extra:
        p = Path(a).expanduser()
        if not p.is_dir():
            print(f"skip (not a dir): {a}", file=sys.stderr)
            continue
        paths.append(p)
    return list(dict.fromkeys(str(p.resolve()) for p in paths))


def main():
    data = json.loads(CONFIG.read_text()) if CONFIG.exists() else {}
    projects = data.setdefault("projects", {})
    changed = []
    for path in targets(sys.argv[1:]):
        entry = projects.setdefault(path, {})
        if entry.get("hasTrustDialogAccepted") is not True:
            entry["hasTrustDialogAccepted"] = True
            changed.append(path)
    if not changed:
        print("all trusted, no change")
        return
    if CONFIG.exists():
        backup = CONFIG.with_name(f".claude.json.bak-{time.strftime('%Y%m%d-%H%M%S')}")
        shutil.copy2(CONFIG, backup)
        print(f"backup: {backup}")
    fd, tmp = tempfile.mkstemp(dir=CONFIG.parent, prefix=".claude.json.")
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, CONFIG)
    for p in changed:
        print(f"trusted: {p}")


if __name__ == "__main__":
    main()
