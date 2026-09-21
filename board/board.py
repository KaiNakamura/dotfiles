#!/usr/bin/env python3
"""A kanban board over a thoughts vault.

The vault already tracks every piece of work and what state it is in. This
renders that as a board and lets a column change write back, so there is one
copy of the truth and nothing to keep in sync.

Nodes and running agents both come from `th`, which already knows how to find
them. Nothing here parses the vault itself except the one line it writes.

No dependencies. Python 3.8+.
"""

import argparse
import concurrent.futures
import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.parse
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# The vault's own vocabulary, in board order. A node carrying anything else
# still shows, in its own column, rather than being hidden or coerced.
# Board order, which is not the vocabulary's order: deferred sits to the left of
# todo because it is the pile you scan past, not a stage work passes through.
STATUSES = ("deferred", "todo", "in-progress", "in-review", "blocked", "done",
            "canceled")

# Off the board unless asked for. Resolved work and nodes that never declared a
# status are both noise on a board about what is in flight.
QUIET_STATUSES = ("done", "canceled")

# The one piece of state the board owns. Everything else it shows is the vault's,
# read through `th`; what is tracked is Kai's, and it is not a fact about the work.
#
# It lives outside the vault on purpose. `status:` says what state a piece of
# work is in and belongs in the shared record; "am I carrying this right now" is
# personal and changes several times a day, and putting it in frontmatter would
# mean a git diff on a node every time attention moves.
STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "board")
TRACK_FILE = os.path.join(STATE_DIR, "tracking.json")

# Priority describes something already tracked; it is never a way to track it.
# That keeps one control for "am I carrying this" and leaves no state where a
# node is ranked but not carried.
PRIORITIES = ("high", "medium", "low")

DEFAULT_PORT = 8788
STALE_SECONDS = 15 * 60   # an agent quiet longer than this stops pulsing
CACHE_SECONDS = 1.5       # how long a `th` read is reused across requests
DESKTOP_SECONDS = 20      # how long a desktop lookup is reused; see Desktops
DETAIL_LOG_LINES = 12     # how much of a node's trail the project page shows
DETAIL_BODY_CHARS = 2400  # a head can run to 20k; the page is a glance, not a read
LINK_SECONDS = 60         # how long a fetched link card is reused; see LinkCards
LINK_WORKERS = 6          # how many of one node's links are fetched at once


# --------------------------------------------------------------------------
# Reading the vault, entirely through th

def run(args, timeout=15):
    """Run a command and return stdout, or raise with stderr in the message."""
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except FileNotFoundError:
        raise RuntimeError("%s is not on PATH" % args[0])
    except subprocess.TimeoutExpired:
        raise RuntimeError("%s timed out" % " ".join(args))
    if p.returncode != 0:
        raise RuntimeError((p.stderr or p.stdout or "").strip()
                           or "%s exited %d" % (args[0], p.returncode))
    return p.stdout


def vault_root(override=None):
    """Where the vault is. Asks th last, since parsing its table is the most
    fragile of the three and the other two answer on this machine."""
    if override:
        return os.path.abspath(os.path.expanduser(override))
    env = os.environ.get("THOUGHTS_VAULT")
    if env:
        return os.path.abspath(os.path.expanduser(env))
    d = os.getcwd()
    while True:
        if os.path.exists(os.path.join(d, "thoughts.md")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            break
        d = parent
    for line in run(["th", "config", "show"]).splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0] == "vault":
            return os.path.abspath(os.path.expanduser(parts[1]))
    raise RuntimeError("no vault found: stand in one, set THOUGHTS_VAULT, "
                       "or pass --vault")


def read_nodes(vault):
    out = run(["th", "status", "--all", "--depth", "99", "--json",
               "--vault", vault])
    return json.loads(out)


def load_tracking(vault):
    """{node path: {since, priority}} for this vault.

    Keyed by vault so one file can serve several. `since` is stored because
    "picked this up on Tuesday and it is still here" is worth being able to ask.
    """
    try:
        with open(TRACK_FILE, encoding="utf-8") as fh:
            raw = json.load(fh).get(vault, {})
    except (OSError, ValueError):
        return {}
    out = {}
    for path, value in raw.items():
        # Tolerate the bare timestamp the first version of this file wrote.
        if isinstance(value, dict):
            out[path] = {"since": value.get("since"),
                         "priority": value.get("priority")}
        else:
            out[path] = {"since": value, "priority": None}
    return out


def save_tracking(vault, tracking):
    try:
        with open(TRACK_FILE, encoding="utf-8") as fh:
            everything = json.load(fh)
    except (OSError, ValueError):
        everything = {}
    everything[vault] = tracking
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = TRACK_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(everything, fh, indent=1, sort_keys=True)
    os.replace(tmp, TRACK_FILE)


def set_tracking(vault, node_path, on, priority="keep"):
    """Track or untrack a node, and optionally rank it.

    Untracking drops the priority with it, since a priority only ever describes
    something being carried.
    """
    tracking = load_tracking(vault)
    if not on:
        existed = tracking.pop(node_path, None) is not None
        save_tracking(vault, tracking)
        return existed
    entry = tracking.get(node_path) or {"since": time.time(), "priority": None}
    if priority != "keep":
        if priority is not None and priority not in PRIORITIES:
            raise ValueError("priority is one of %s" % ", ".join(PRIORITIES))
        entry["priority"] = priority
    tracking[node_path] = entry
    save_tracking(vault, tracking)
    return True


def read_windows(vault):
    """What is open, as ({pid: desktop}, {node path: desktop}).

    `thw` owns the KWin and /proc knowledge; this is a read, so it never moves
    anything. Absent on a non-KDE box or over ssh, which is exactly when the
    answer is "there are no desktops" rather than an error.

    One call answers both questions because both are joins onto the same walk,
    and the walk is the expensive part. The first map is every agent's desktop,
    for the jump button. The second is every node with a window on it, which is
    a wider set than the agents: a window sitting at a shell has no agent and is
    invisible to `thw desks`, while being just as open.
    """
    try:
        out = run(["thw", "windows"], timeout=20)
    except (RuntimeError, OSError):
        return {}, {}
    desks, open_dirs = {}, {}
    root = os.path.join(vault, "")
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) != 3 or parts[1] in ("-", ""):
            continue
        pid, desktop, cwd = parts
        desks[pid] = desktop
        # Trailing " (deleted)" is what /proc appends when the directory has
        # been removed underneath a process still sitting in it, and it is not
        # part of any path.
        cwd = cwd.removesuffix(" (deleted)")
        if cwd.startswith(root):
            open_dirs.setdefault(cwd[len(root):], desktop)
    return desks, open_dirs


class Desktops:
    """Which desktop each agent is on and what is open, kept off the hot path.

    Asking costs well over a second: `thw` has to inject a script into KWin and
    read the answer back out of the journal, because KWin has no cheap read API
    for a window's pid. Doing that inside a board rebuild made every poll and,
    worse, every click wait on it -- a card took seconds to respond, which reads
    as broken rather than slow.

    So it is answered from the last known value immediately, and refreshed in
    the background when that value gets old. A desktop assignment changes when a
    window is moved, which is rare next to a two-second poll, so a stale answer
    costs a wrong number for a few seconds and never costs a wrong action: the
    jump itself re-resolves the desktop at the moment it is asked for.
    """

    def __init__(self):
        self.lock = threading.Lock()
        self.value = ({}, {})  # (pid -> desktop, directory -> desktop)
        self.at = 0.0
        self.running = False
        self.vault = None

    def _refresh(self):
        value = read_windows(self.vault)
        with self.lock:
            self.value = value
            self.at = time.time()
            self.running = False

    def get(self, vault):
        with self.lock:
            self.vault = vault
            stale = time.time() - self.at > DESKTOP_SECONDS
            if stale and not self.running:
                self.running = True
                threading.Thread(target=self._refresh, daemon=True).start()
            return self.value


DESKTOPS = Desktops()


def read_agents(vault):
    """Agents are a decoration, so a failure here dims the board rather than
    breaking it -- th agents reads /proc and can legitimately come back empty."""
    try:
        return json.loads(run(["th", "agents", "--json", "--vault", vault]))
    except (RuntimeError, ValueError):
        return []


def rollup(nodes, path):
    """How this node's descendants are doing, as {status: count}."""
    counts = {}
    prefix = path + "/"
    for n in nodes:
        if n["path"].startswith(prefix):
            key = n.get("status") or ""
            counts[key] = counts.get(key, 0) + 1
    return counts


def build_board(vault):
    nodes = read_nodes(vault)
    agents = read_agents(vault)
    desks, open_dirs = DESKTOPS.get(vault)
    tracking = load_tracking(vault)

    by_path = {}
    for a in agents:
        path = a.get("path")
        if not path:
            continue
        prev = by_path.get(path)
        # Several agents can sit in one node. The one the card should report is
        # whichever wants something: a session waiting for a prompt outranks one
        # that is working, because the card is read to decide where to go next.
        # Within a group the freshest wins, as it did before.
        def rank(x):
            return (0 if x.get("state") == "idle" else 1,
                    x.get("state_seconds", x.get("idle_seconds") or 0) or 0)
        if prev is None or rank(a) < rank(prev):
            by_path[path] = a

    paths = {n["path"] for n in nodes}

    # A window sits in a node or somewhere under one, and what is open is the
    # nearest node at or above it -- never that node's parents. Walking all the
    # way up marked `cyvl` as open because something under it was, which is the
    # same complaint that `hide from the board` was added for.
    open_nodes = {}
    for rel, desktop in open_dirs.items():
        while rel:
            if rel in paths:
                open_nodes.setdefault(rel, desktop)
                break
            rel = os.path.dirname(rel)
    slugs = {}
    for n in nodes:
        slugs.setdefault(n["slug"], []).append(n["path"])

    cards = []
    for n in nodes:
        path = n["path"]
        agent = by_path.get(path)
        parents = path.split("/")[1:-1]     # drop the leading "projects"
        cards.append({
            "slug": n["slug"],
            "path": path,
            "status": n.get("status") or "",
            "description": n.get("description") or "",
            "trail": parents,
            "group": path.split("/")[1] if path.count("/") >= 1 else "",
            "links": n.get("links") or {},
            "repos": [r.get("repo") for r in (n.get("repos") or [])
                      if r.get("repo")],
            "branch": (n.get("repos") or [{}])[0].get("branch") or "",
            # A node with children is a grouping as much as a task, and saying
            # so lets the board de-emphasise it rather than hide it. The vault's
            # own docs say a rollup is derived by walking child statuses rather
            # than stored, so it is derived here.
            "children": sum(1 for p in paths if p.startswith(path + "/")),
            "rollup": rollup(nodes, path),
            "ambiguous": len(slugs.get(n["slug"], [])) > 1,
            "touched": touched_at(vault, path, n["slug"]),
            "tracked": (tracking.get(path) or {}).get("since"),
            "priority": (tracking.get(path) or {}).get("priority"),
            # A window open on a desktop, whether or not an agent is running in
            # it. Wider than `agent` on purpose: a shell left open in a node is
            # something Kai has open, and the board could not see it before.
            "open": open_nodes.get(path),
            "agent": None if not agent else {
                "pid": agent.get("pid"),
                "idle_seconds": agent.get("idle_seconds", 0),
                # What the session says about itself, which is the fact the
                # card is actually asking for. `idle_seconds` measures silence,
                # and a session that is thinking produces the same silence as
                # one that has finished; see the traps in this node's head.
                "state": agent.get("state"),
                "state_seconds": agent.get("state_seconds"),
                "name": agent.get("name"),
                # Only meaningful for a session that never reported a state.
                # Something waiting for a prompt is not stale however long it
                # has waited, and something working is not stale at all.
                "stale": (agent.get("state") is None
                          and agent.get("idle_seconds", 0) > STALE_SECONDS),
                "desktop": desks.get(str(agent.get("pid"))),
            },
        })

    # Tracked work sits at the top of its column, highest priority first: that
    # is the order the board is actually being asked for. Below that, a session
    # waiting for a prompt outranks one that is working, because the first is
    # something to do and the second is something to leave alone.
    rank = {"high": 0, "medium": 1, "low": 2, None: 3}
    live = {"idle": 0, "busy": 1}
    cards.sort(key=lambda c: (
        0 if c["tracked"] else 1,
        rank.get(c["priority"], 3),
        0 if c["agent"] else 1,
        live.get((c["agent"] or {}).get("state"), 2),
        (c["agent"] or {}).get("state_seconds")
        or (c["agent"] or {}).get("idle_seconds") or 0,
        -(c["touched"] or 0),
        c["path"],
    ))
    return {"cards": cards, "statuses": list(STATUSES),
            "quiet": list(QUIET_STATUSES), "vault": vault, "now": time.time()}


class Cache:
    """One board read shared across the browser's polling. Without it three
    tabs and a 2s poll turn into a `th` subprocess several times a second."""

    def __init__(self, vault):
        self.vault = vault
        self.lock = threading.Lock()
        self.at = 0.0
        self.value = None

    def get(self, fresh=False):
        with self.lock:
            if fresh or self.value is None or time.time() - self.at > CACHE_SECONDS:
                self.value = build_board(self.vault)
                self.at = time.time()
            return self.value

    def invalidate(self):
        with self.lock:
            self.at = 0.0

    def patch(self, node_path, fields):
        """Apply a write to the cached board and hand it straight back.

        A write used to force a full rebuild before it could answer, so clicking
        a card waited on `th` and on the desktop lookup behind it. The board
        already knows what the write did, so it says so immediately and lets the
        next poll pick up anything else that moved.
        """
        with self.lock:
            board = self.value
            if board is None:
                return None
            for card in board["cards"]:
                if card["path"] == node_path:
                    card.update(fields)
                    break
            board["now"] = time.time()
            # Not marked fresh: the next poll still does a real read, so nothing
            # a patch could not know about stays wrong for more than a tick.
            return board


# --------------------------------------------------------------------------
# Writing the one line this tool owns

FRONTMATTER_STATUS = re.compile(r"^status:\s*(.*)$")


def head_file(vault, node_path, slug):
    return os.path.join(vault, node_path, slug + ".md")


def touched_at(vault, node_path, slug):
    """When this node last moved, as an epoch time.

    The log is the vault's own chronological trail, so its mtime is the closest
    thing to a real "last worked on" without inventing a frontmatter field. The
    head is the fallback, since a node can be edited without a log entry, and
    the newer of the two is the honest answer.
    """
    newest = 0.0
    for name in ("log.md", slug + ".md"):
        try:
            newest = max(newest, os.path.getmtime(
                os.path.join(vault, node_path, name)))
        except OSError:
            pass
    return newest or None


def read_detail(vault, node_path, slug):
    """The head's prose and the tail of the log, for the detail panel.

    This is the one place the board reads the vault directly instead of going
    through `th`. It is reading two files it already knows the path of, rather
    than re-deriving anything th owns.
    """
    body, log = "", []
    try:
        with open(head_file(vault, node_path, slug), encoding="utf-8") as fh:
            text = fh.read()
        if text.startswith("---"):
            end = text.find("\n---", 3)
            text = text[end + 4:] if end != -1 else text
        body = text.strip()
        if len(body) > DETAIL_BODY_CHARS:
            body = body[:DETAIL_BODY_CHARS].rstrip() + "\n\n[...]"
    except OSError:
        pass
    try:
        with open(os.path.join(vault, node_path, "log.md"), encoding="utf-8") as fh:
            lines = [ln.rstrip() for ln in fh if ln.strip().startswith("- ")]
        log = lines[-DETAIL_LOG_LINES:]
    except OSError:
        pass
    notes = []
    try:
        notes = sorted(n for n in os.listdir(os.path.join(vault, node_path))
                       if n.endswith(".md") and n != "log.md"
                       and n != slug + ".md")
    except OSError:
        pass
    return {"body": body, "log": log, "notes": notes}


# --------------------------------------------------------------------------
# Link cards
#
# A node's `links:` are the only place it names the world outside the vault, and
# until now they were rendered as bare URLs. A link card is that same URL with
# whatever its own service will tell us about it.
#
# Two rules hold this together. The first is that recognising a link and
# fetching it are separate: `classify_link` is pure string work and always
# succeeds, so every link gets a card even when nothing can be fetched for it.
# The second is that no fetch happens on the board's rebuild path. The board
# polls every 2s and `gh` takes over a second, so these are asked for by the
# project page after it has already drawn, and cached.

GITHUB_PR = re.compile(r"^https?://github\.com/([^/]+)/([^/]+)/pull/(\d+)")
GITHUB_ISSUE = re.compile(r"^https?://github\.com/([^/]+)/([^/]+)/issues/(\d+)")
GITHUB_REPO = re.compile(r"^https?://github\.com/([^/]+)/([^/]+)/?$")
SLACK_MSG = re.compile(
    r"^https?://([a-z0-9-]+)\.slack\.com/archives/([A-Z0-9]+)/p(\d{10})(\d{6})")
SLACK_CHAN = re.compile(r"^https?://([a-z0-9-]+)\.slack\.com/archives/([A-Z0-9]+)")
LINEAR_ISSUE = re.compile(r"^https?://linear\.app/([^/]+)/issue/([A-Za-z0-9]+-\d+)")


SLACK_STATE = os.path.expanduser("~/.config/Slack/storage/root-state.json")
_slack_team = []


def slack_team():
    """The workspace id the Slack desktop app is signed in to, or None.

    A `slack://` deep link needs a team id and a permalink does not carry one,
    so it has to come from somewhere. The app writes it into its own state file,
    which is the only place on this machine that knows it, and reading that is
    cheaper and more honest than asking for it to be pasted into a config.
    """
    if _slack_team:
        return _slack_team[0]
    team = None
    try:
        with open(SLACK_STATE, encoding="utf-8") as fh:
            team = (json.load(fh).get("workspacesMeta") or {}).get(
                "selectedWorkspaceId")
    except (OSError, ValueError):
        pass
    _slack_team.append(team)
    return team


def classify_link(key, url):
    """What kind of thing a link points at, from the URL alone.

    The vault deliberately gives `links:` keys no meaning -- 14 different names
    across the 31 links in this vault -- so the key is a label to show and never
    something to match on. The host is what decides the card.
    """
    card = {"key": key, "url": url, "kind": "other",
            "host": re.sub(r"^https?://", "", url).split("/")[0]}
    m = GITHUB_PR.match(url)
    if m:
        card.update(kind="github-pr", repo="%s/%s" % (m.group(1), m.group(2)),
                    number=int(m.group(3)), live=True)
        return card
    m = GITHUB_ISSUE.match(url)
    if m:
        card.update(kind="github-issue", repo="%s/%s" % (m.group(1), m.group(2)),
                    number=int(m.group(3)), live=True)
        return card
    m = GITHUB_REPO.match(url)
    if m:
        card.update(kind="github-repo", repo="%s/%s" % (m.group(1), m.group(2)))
        return card
    m = SLACK_MSG.match(url)
    if m:
        # The permalink's `p1788200434373329` is the message ts with its dot
        # removed. Putting it back is what every Slack API call wants, and it
        # is also how two links to the same thread are recognised as one.
        card.update(kind="slack-thread", workspace=m.group(1),
                    channel=m.group(2), ts="%s.%s" % (m.group(3), m.group(4)))
        slack_app_url(card)
        return card
    m = SLACK_CHAN.match(url)
    if m:
        card.update(kind="slack-channel", workspace=m.group(1), channel=m.group(2))
        slack_app_url(card)
        return card
    m = LINEAR_ISSUE.match(url)
    if m:
        card.update(kind="linear-issue", team=m.group(1), issue=m.group(2).upper())
        return card
    return card


def slack_app_url(card):
    """The `slack://` form of a Slack link, when the team id is known.

    Only the channel is addressable this way. Slack's deep-link docs describe
    `channel` and `user` targets and nothing for a single message, so the card
    offers the channel in the app and the permalink in the browser rather than
    guessing at a message parameter that no primary source describes.
    """
    team = slack_team()
    if team:
        card["app_url"] = "slack://channel?team=%s&id=%s" % (team, card["channel"])
    return card


def gh_json(args):
    """One `gh` call, returning parsed JSON or raising RuntimeError.

    `gh` is used rather than the REST API because it already holds Kai's token
    in the system keyring; adding an API client here would mean a second copy of
    that credential and a place for it to go stale.
    """
    try:
        out = run(["gh"] + args, timeout=20)
    except (RuntimeError, OSError) as e:
        raise RuntimeError(str(e))
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        raise RuntimeError("gh returned something that is not json")


CHECK_FIELDS = ("number,title,state,isDraft,reviewDecision,mergeable,"
                "statusCheckRollup,reviewRequests,updatedAt,additions,deletions,"
                "changedFiles,headRefName,baseRefName,comments,url")


def pr_stage(pr, checks):
    """One line for where a PR actually is.

    The order is the order the facts override each other, not the order they are
    read. A merged PR does not care that its checks are red; a draft is not
    awaiting review however many reviewers are on it; and a red build outranks
    an approval, because the approval was given against a build that has since
    changed.
    """
    if pr.get("state") == "MERGED":
        return "merged"
    if pr.get("state") == "CLOSED":
        return "closed"
    if pr.get("isDraft"):
        return "draft"
    if checks["failed"]:
        return "CI failing"
    if checks["pending"]:
        return "CI running"
    decision = pr.get("reviewDecision") or ""
    if decision == "CHANGES_REQUESTED":
        return "changes requested"
    if decision == "APPROVED":
        if pr.get("mergeable") == "CONFLICTING":
            return "approved, conflicts"
        return "approved, ready to merge"
    if pr.get("reviewRequests"):
        return "awaiting review"
    if pr.get("mergeable") == "CONFLICTING":
        return "conflicts"
    return "open, no reviewer"


# Which stages are a call for attention, which are fine, and which are neither.
# The page colours on this rather than on the raw state, so one word decides it.
STAGE_TONE = {
    "CI failing": "bad", "changes requested": "bad", "conflicts": "bad",
    "approved, conflicts": "bad",
    "CI running": "warn", "awaiting review": "warn", "open, no reviewer": "warn",
    "approved, ready to merge": "good", "merged": "good",
    "draft": "mute", "closed": "mute",
}


def fetch_github_pr(card):
    pr = gh_json(["pr", "view", str(card["number"]), "--repo", card["repo"],
                  "--json", CHECK_FIELDS])
    checks = {"passed": 0, "failed": 0, "pending": 0, "skipped": 0}
    failing = []
    for c in pr.get("statusCheckRollup") or []:
        # A CheckRun reports status + conclusion; a StatusContext only a state.
        # Normalising both to one word here keeps the page from knowing which
        # kind of check GitHub happened to return.
        if c.get("__typename") == "StatusContext":
            got = (c.get("state") or "").upper()
            name = c.get("context") or "status"
        else:
            name = c.get("name") or "check"
            got = ((c.get("conclusion") or "") if c.get("status") == "COMPLETED"
                   else "PENDING").upper()
        if got in ("SUCCESS", "NEUTRAL"):
            checks["passed"] += 1
        elif got in ("FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED"):
            checks["failed"] += 1
            if len(failing) < 6:
                failing.append(name)
        elif got in ("SKIPPED",):
            checks["skipped"] += 1
        else:
            checks["pending"] += 1
    stage = pr_stage(pr, checks)
    reviewers = []
    for r in pr.get("reviewRequests") or []:
        reviewers.append(r.get("login") or r.get("name") or r.get("slug") or "?")
    return {
        "title": pr.get("title"), "state": pr.get("state"),
        "draft": pr.get("isDraft"), "review": pr.get("reviewDecision"),
        "mergeable": pr.get("mergeable"), "updated": pr.get("updatedAt"),
        "branch": pr.get("headRefName"), "base": pr.get("baseRefName"),
        "adds": pr.get("additions"), "dels": pr.get("deletions"),
        # `gh` returns every comment body under this field. The page wants how
        # many, and shipping the bodies would put a PR's whole discussion into
        # a payload that is polled.
        "files": pr.get("changedFiles"), "comments": len(pr.get("comments") or []),
        "checks": checks, "failing": failing, "reviewers": reviewers,
        "stage": stage, "tone": STAGE_TONE.get(stage, "mute"),
    }


def fetch_github_issue(card):
    it = gh_json(["issue", "view", str(card["number"]), "--repo", card["repo"],
                  "--json", "number,title,state,updatedAt,labels,assignees,comments"])
    stage = "closed" if it.get("state") == "CLOSED" else "open"
    return {
        "title": it.get("title"), "state": it.get("state"),
        "updated": it.get("updatedAt"),
        "labels": [l.get("name") for l in it.get("labels") or []][:6],
        "assignees": [a.get("login") for a in it.get("assignees") or []],
        "comments": len(it.get("comments") or []),
        "stage": stage, "tone": "mute" if stage == "closed" else "warn",
    }


FETCHERS = {"github-pr": fetch_github_pr, "github-issue": fetch_github_issue}


class LinkCards:
    """Fetched state for link cards, cached by URL.

    Kept off the board's own cache on purpose. The board rebuilds every couple
    of seconds and these take over a second each, so they are fetched only when
    a project page asks and then reused for LINK_SECONDS. A failure is cached
    too, for the same window -- otherwise a repo you cannot reach re-runs `gh`
    on every poll of the page that names it.
    """

    def __init__(self):
        self.lock = threading.Lock()
        self.by_url = {}

    def get(self, cards, force=False):
        now = time.time()
        want = []
        with self.lock:
            for c in cards:
                if c["kind"] not in FETCHERS:
                    continue
                hit = self.by_url.get(c["url"])
                if force or not hit or now - hit["at"] > LINK_SECONDS:
                    want.append(c)
        if want:
            workers = min(LINK_WORKERS, len(want))
            with concurrent.futures.ThreadPoolExecutor(workers) as pool:
                for c, res in zip(want, pool.map(self._one, want)):
                    with self.lock:
                        self.by_url[c["url"]] = {"at": time.time(), "data": res}
        out = []
        with self.lock:
            for c in cards:
                c = dict(c)
                hit = self.by_url.get(c["url"])
                if hit:
                    c["fetched_at"] = hit["at"]
                    if "error" in hit["data"]:
                        c["error"] = hit["data"]["error"]
                    else:
                        c["data"] = hit["data"]
                out.append(c)
        return out

    @staticmethod
    def _one(card):
        try:
            return FETCHERS[card["kind"]](card)
        except RuntimeError as e:
            return {"error": str(e)}


LINKS = LinkCards()


def set_status(vault, node_path, slug, status):
    """Rewrite a node head's `status:` and nothing else.

    Line-based on purpose. A YAML round trip would reformat the whole block --
    quoting, key order, the `repos:` mapping -- and every one of those files is
    hand-written and diffed by a person.
    """
    if status not in STATUSES:
        raise ValueError("unknown status %r" % status)
    path = head_file(vault, node_path, slug)
    if not os.path.exists(path):
        raise ValueError("no head file at %s" % path)

    with open(path, encoding="utf-8") as fh:
        lines = fh.read().split("\n")

    if not lines or lines[0].strip() != "---":
        raise ValueError("%s has no frontmatter to edit" % path)
    try:
        end = next(i for i in range(1, len(lines)) if lines[i].strip() == "---")
    except StopIteration:
        raise ValueError("%s has an unterminated frontmatter block" % path)

    for i in range(1, end):
        m = FRONTMATTER_STATUS.match(lines[i])
        if m:
            if m.group(1).strip() == status:
                return False
            lines[i] = "status: " + status
            break
    else:
        lines.insert(1, "status: " + status)

    tmp = path + ".board-tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    os.replace(tmp, path)
    return True


def jump_to_desktop(pid, desktop=None):
    """Switch to the desktop the window owning this pid is on.

    A node can be open without anything running in it, and then there is no pid
    to ask about, only the desktop the window was found on -- so `desktop` is
    the fallback rather than a second way of doing the same thing.

    Delegated to `thw`, which already owns every piece of KDE knowledge in this
    setup, rather than reimplementing the /proc walk and the KWin round trip
    here. `thw to` switches to a desktop that already has a window on it; it
    never opens one, which is the operation that drags the current desktop.
    """
    try:
        argv = ["thw", "to", str(int(pid))]
    except (TypeError, ValueError):
        try:
            argv = ["thw", "desk", str(int(desktop))]
        except (TypeError, ValueError):
            raise RuntimeError("neither %r nor %r says where to go"
                               % (pid, desktop))
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=10)
    except FileNotFoundError:
        raise RuntimeError("thw is not on PATH (it installs with the th module, "
                           "and only on KDE)")
    except subprocess.TimeoutExpired:
        raise RuntimeError("%s did not answer" % " ".join(argv))
    if p.returncode != 0:
        raise RuntimeError((p.stderr or p.stdout or "").strip()
                           or "thw exited %d" % p.returncode)
    return True


def find_node(board, token):
    """Resolve a slug, a unique fragment of one, or a full node path."""
    cards = board["cards"]
    exact = [c for c in cards if c["slug"] == token or c["path"] == token]
    if len(exact) == 1:
        return exact[0]
    if len(exact) > 1:
        raise ValueError("%r names %d nodes: %s" % (
            token, len(exact), ", ".join(c["path"] for c in exact)))
    hits = [c for c in cards if token.lower() in c["slug"].lower()]
    if not hits:
        raise ValueError("no node matching %r" % token)
    if len(hits) > 1:
        raise ValueError("%r matches %d nodes: %s" % (
            token, len(hits), ", ".join(c["slug"] for c in hits)))
    return hits[0]


# --------------------------------------------------------------------------
# Server

class Handler(BaseHTTPRequestHandler):
    cache = None

    def _send(self, code, body, ctype):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, obj, code=200):
        self._send(code, json.dumps(obj).encode("utf-8"), "application/json")

    def do_GET(self):
        # A project page is a real URL, not a fragment, so it can be opened in
        # its own window, bookmarked, and walked back out of. The server hands
        # the same page to every /node/... path and lets the client route: there
        # is one document, and adding a second would mean a second stylesheet.
        if (self.path in ("/", "/index.html")
                or self.path == "/node" or self.path.startswith("/node/")):
            self._send(200, PAGE.encode("utf-8"), "text/html; charset=utf-8")
        elif self.path.startswith("/api/links"):
            query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            try:
                card = find_node(self.cache.get(), (query.get("path") or [""])[0])
            except (ValueError, RuntimeError) as e:
                self._json({"error": str(e)}, 404)
                return
            cards = [classify_link(k, v)
                     for k, v in (card.get("links") or {}).items()]
            self._json({"links": LINKS.get(
                cards, force=bool(query.get("force")))})
        elif self.path.startswith("/api/board"):
            try:
                self._json(self.cache.get())
            except RuntimeError as e:
                self._json({"error": str(e)}, 500)
        elif self.path.startswith("/api/node"):
            query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            try:
                card = find_node(self.cache.get(), (query.get("path") or [""])[0])
            except (ValueError, RuntimeError) as e:
                self._json({"error": str(e)}, 404)
                return
            detail = read_detail(self.cache.vault, card["path"], card["slug"])
            detail["card"] = card
            self._json(detail)
        else:
            self._json({"error": "not found"}, 404)

    def do_POST(self):
        if not (self.path.startswith("/api/status")
                or self.path.startswith("/api/desktop")
                or self.path.startswith("/api/track")):
            self._json({"error": "not found"}, 404)
            return
        length = int(self.headers.get("Content-Length", 0))
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            self._json({"error": "bad json"}, 400)
            return
        if self.path.startswith("/api/track"):
            try:
                card = find_node(self.cache.get(), body.get("path") or "")
                set_tracking(self.cache.vault, card["path"], bool(body.get("on")),
                             body.get("priority", "keep"))
            except (ValueError, RuntimeError) as e:
                self._json({"error": str(e)}, 400)
                return
            entry = load_tracking(self.cache.vault).get(card["path"]) or {}
            patched = self.cache.patch(card["path"], {
                "tracked": entry.get("since"),
                "priority": entry.get("priority"),
            })
            self._json({"ok": True, "board": patched or self.cache.get()})
            return
        if self.path.startswith("/api/desktop"):
            try:
                jump_to_desktop(body.get("pid"), body.get("desktop"))
            except RuntimeError as e:
                self._json({"error": str(e)}, 400)
                return
            self._json({"ok": True})
            return
        try:
            board = self.cache.get()
            card = find_node(board, body.get("path") or body.get("slug") or "")
            changed = set_status(self.cache.vault, card["path"], card["slug"],
                                 body.get("status", ""))
        except (ValueError, RuntimeError) as e:
            self._json({"error": str(e)}, 400)
            return
        print("  %s -> %s%s" % (card["slug"], body.get("status"),
                                "" if changed else " (no change)"))
        patched = self.cache.patch(card["path"], {"status": body.get("status")})
        self._json({"ok": True, "board": patched or self.cache.get()})

    def log_message(self, *args):
        pass


def serve(vault, port, open_browser):
    Handler.cache = Cache(vault)
    Handler.cache.get()          # fail loudly here rather than in the browser
    httpd = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    url = "http://127.0.0.1:%d/" % port
    print("board: %s" % url)
    print("vault: %s" % vault)
    if open_browser:
        threading.Thread(target=lambda: (time.sleep(0.4), webbrowser.open(url)),
                         daemon=True).start()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("")


# --------------------------------------------------------------------------
# CLI

COLOR = {
    "deferred": "\033[90m", "todo": "\033[37m", "in-progress": "\033[33m",
    "in-review": "\033[32m", "blocked": "\033[31m", "done": "\033[34m",
    "canceled": "\033[90m", "": "\033[90m",
}
RESET = "\033[0m"

# Three levels drawn as filled bars rather than words, so a column of them can
# be read down rather than across.
PRI_MARK = {"high": "\u2586", "medium": "\u2584", "low": "\u2582", None: "\u00b7"}
PRI_ORDER = {"high": 0, "medium": 1, "low": 2, None: 3}


def fmt_idle(seconds):
    seconds = int(seconds)
    if seconds < 60:
        return "%ds" % seconds
    if seconds < 3600:
        return "%dm" % (seconds // 60)
    if seconds < 86400:
        return "%dh" % (seconds // 3600)
    return "%dd" % (seconds // 86400)


def cmd_list(args, vault):
    board = build_board(vault)
    tty = sys.stdout.isatty()
    shown = 0
    for status in list(STATUSES) + [""]:
        if not args.all and status in QUIET_STATUSES + ("",):
            continue
        group = [c for c in board["cards"] if c["status"] == status]
        if not group:
            continue
        label = status or "(no status)"
        head = "%s%s%s" % (COLOR.get(status, ""), label, RESET) if tty else label
        print("\n%s  %d" % (head, len(group)))
        for c in group:
            shown += 1
            # A hollow mark for something waiting on Kai and a filled one for
            # something working, so the two are told apart at a glance rather
            # than by reading the elapsed time next to them.
            mark = "  "
            a = c["agent"]
            if a:
                mark = {"idle": "○ ", "busy": "● "}.get(
                    a["state"], "· " if a["stale"] else "● ")
            elif c["open"]:
                mark = "▫ "
            trail = "/".join(c["trail"])
            tail = "  %s" % trail if trail else ""
            idle = ""
            if a and a["state"] == "idle":
                idle = "  (waiting %s)" % fmt_idle(a["state_seconds"] or 0)
            elif a and a["state"] == "busy":
                idle = "  (working %s)" % fmt_idle(a["state_seconds"] or 0)
            elif a:
                idle = "  (quiet %s)" % fmt_idle(a["idle_seconds"])
            elif c["open"]:
                idle = "  (open, desk %s)" % c["open"]
            flag = PRI_MARK.get(c["priority"], "*") if c["tracked"] else " "
            print("  %s %s%-42s%s%s" % (flag, mark, c["slug"], tail, idle))
    others = [c for c in board["cards"] if c["status"] not in STATUSES
              and c["status"]]
    if others:
        print("\noff-vocabulary  %d" % len(others))
        for c in others:
            print("  %-42s  %s" % (c["slug"], c["status"]))
    if not shown:
        print("nothing in flight")


def cmd_mv(args, vault):
    board = build_board(vault)
    card = find_node(board, args.target)
    changed = set_status(vault, card["path"], card["slug"], args.status)
    if changed:
        print("%s: %s -> %s" % (card["slug"], card["status"] or "(none)",
                                args.status))
    else:
        print("%s is already %s" % (card["slug"], args.status))


def cmd_track(args, vault):
    board = build_board(vault)
    if not args.target:
        on = sorted((c for c in board["cards"] if c["tracked"]),
                    key=lambda c: (PRI_ORDER.get(c["priority"], 3), -c["tracked"]))
        if not on:
            print("tracking nothing")
            return
        now = time.time()
        for c in on:
            print("  %s %-40s  %-12s %s" % (
                PRI_MARK.get(c["priority"], " "), c["slug"], c["status"] or "-",
                fmt_idle(now - c["tracked"]) + " ago"))
        return

    card = find_node(board, args.target)
    if args.off:
        print("%s: %s" % (card["slug"],
                          "no longer tracked" if set_tracking(vault, card["path"], False)
                          else "was not tracked"))
        return
    # A bare priority on an untracked node starts tracking it, since ranking
    # something you are not carrying is the state this design does not have.
    set_tracking(vault, card["path"], True,
                 None if args.clear else (args.priority or "keep"))
    after = load_tracking(vault)[card["path"]]
    print("%s: tracked%s" % (card["slug"],
                             ", %s" % after["priority"] if after["priority"] else ""))


def cmd_serve(args, vault):
    serve(vault, args.port, not args.no_open)


def cmd_open(args, vault):
    webbrowser.open("http://127.0.0.1:%d/" % args.port)


def build_parser():
    p = argparse.ArgumentParser(
        prog="board", description="A kanban board over a thoughts vault.")
    p.add_argument("--vault", help="vault to read, overriding the walk-up")
    sub = p.add_subparsers(dest="cmd")

    s = sub.add_parser("serve", help="run the board")
    s.add_argument("-p", "--port", type=int, default=DEFAULT_PORT)
    s.add_argument("--no-open", action="store_true",
                   help="do not open a browser")
    s.set_defaults(fn=cmd_serve)

    s = sub.add_parser("list", help="print the board")
    s.add_argument("-a", "--all", action="store_true",
                   help="include done, canceled and status-less nodes")
    s.set_defaults(fn=cmd_list)

    s = sub.add_parser("track", help="what you are carrying right now")
    s.add_argument("target", nargs="?", help="node to track; omit to list")
    s.add_argument("priority", nargs="?", choices=PRIORITIES,
                   help="optional rank, for something you are already tracking")
    s.add_argument("--off", action="store_true", help="stop tracking it")
    s.add_argument("--clear", action="store_true", help="keep it, drop its rank")
    s.set_defaults(fn=cmd_track)

    s = sub.add_parser("mv", help="set a node's status")
    s.add_argument("target", help="slug, a unique fragment of one, or a path")
    s.add_argument("status", choices=STATUSES)
    s.set_defaults(fn=cmd_mv)

    s = sub.add_parser("open", help="open the board in a browser")
    s.add_argument("-p", "--port", type=int, default=DEFAULT_PORT)
    s.set_defaults(fn=cmd_open)
    return p


def main():
    args = build_parser().parse_args()
    if not getattr(args, "fn", None):
        args = build_parser().parse_args(["serve"] + sys.argv[1:])
    try:
        vault = vault_root(args.vault)
        args.fn(args, vault)
    except (RuntimeError, ValueError) as e:
        print("board: %s" % e, file=sys.stderr)
        sys.exit(1)


PAGE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Thoughts Dashboard</title>
<style>
  :root {
    --bg: #f6f6f4; --panel: #fff; --card: #fff; --ink: #1b1b1a;
    --dim: #6f6f6a; --faint: #97978f; --line: #e2e2dd; --accent: #1f7a8c;
    --shadow: rgba(0,0,0,.07); --overlay: rgba(20,20,18,.35);
    --deferred: #9b9b95; --todo: #6b7280; --in-progress: #dd8827;
    --in-review: #349258; --blocked: #c9433a; --done: #33509b;
    --canceled: #bcbcb5; --none: #c4c4bd;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #16171a; --panel: #1c1e22; --card: #22252a; --ink: #e8e8e4;
      --dim: #8d9096; --faint: #6b6f76; --line: #2e3238; --accent: #4fb3c7;
      --shadow: rgba(0,0,0,.35); --overlay: rgba(0,0,0,.55);
      --deferred: #767b83; --todo: #9aa3b2; --in-progress: #e59a44;
      --in-review: #55b87d; --blocked: #e0736a; --done: #5a78d8;
      --canceled: #585c63; --none: #4a4d53;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--ink);
    font: 13px/1.45 ui-sans-serif, -apple-system, "Segoe UI", system-ui, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  .mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }

  header {
    border-bottom: 1px solid var(--line); background: var(--panel);
    position: sticky; top: 0; z-index: 5; padding: 10px 18px 8px;
  }
  /* Two rows rather than one wrapping row: with every group showing there are
     fourteen chips, and letting them wrap into the title row pushed the
     buttons onto a second line on top of the counts. */
  .bar { display: flex; align-items: center; gap: 12px; }
  h1 { font-size: 16px; font-weight: 600; margin: 0; letter-spacing: -.01em; }
  .vault { color: var(--faint); font-size: 12px; font-family: ui-monospace, monospace; }
  .spacer { flex: 1; }
  #live { color: var(--dim); font-size: 12px; white-space: nowrap; }
  #live b { color: var(--accent); font-weight: 600; }
  #live button {
    font: inherit; font-size: 12px; color: var(--dim); background: transparent;
    border: 1px solid transparent; border-radius: 6px; padding: 2px 7px; cursor: pointer;
  }
  #live button:hover { border-color: var(--line); }
  #live button[aria-pressed="true"] { color: var(--panel); background: var(--accent);
                                      border-color: var(--accent); }
  #live button[aria-pressed="true"] b { color: var(--panel); }
  #trackbtn[aria-pressed="true"] { color: var(--panel); background: var(--accent);
                                   border-color: var(--accent); }
  #trackbtn[aria-pressed="true"] b { color: var(--panel); }

  input[type="search"] {
    font: inherit; font-size: 12.5px; color: var(--ink); background: var(--bg);
    border: 1px solid var(--line); border-radius: 6px; padding: 4px 9px;
    width: 230px; outline: none;
  }
  input[type="search"]:focus { border-color: var(--accent); }
  input[type="search"]::placeholder { color: var(--faint); }

  button {
    font: inherit; font-size: 12px; color: var(--ink); background: var(--card);
    border: 1px solid var(--line); border-radius: 6px; padding: 4px 10px;
    cursor: pointer;
  }
  button:hover { border-color: var(--dim); }
  #colsbtn[aria-pressed="true"] {
    background: var(--ink); color: var(--panel); border-color: var(--ink);
  }
  /* An icon rather than the word, which sat in the corner looking like a label
     nobody had finished writing. */
  #colsbtn { padding: 4px 7px; display: inline-flex; align-items: center; }
  #colsbtn svg { width: 14px; height: 14px; }

  /* Reopening the sidebar is the sidebar's own job, so hiding it leaves a rail
     behind rather than putting a control for it up in the top bar. */
  #rail {
    width: 22px; flex: none; background: var(--panel);
    border-right: 1px solid var(--line); display: flex; justify-content: center;
    padding-top: 9px;
  }
  #rail.hidden { display: none; }
  .railbtn, .sidefold {
    width: 20px; height: 20px; display: flex; align-items: center;
    justify-content: center; border: 1px solid transparent; border-radius: 5px;
    background: transparent; color: var(--faint); cursor: pointer; padding: 0;
  }
  .railbtn:hover, .sidefold:hover { color: var(--ink); background: var(--bg); }
  .railbtn svg, .sidefold svg { width: 11px; height: 11px; }
  .railbtn svg { transform: rotate(180deg); }

  /* Column menu: one toggle per column, because "show resolved" bundled three
     unrelated things (done, canceled, and never-triaged) behind one button. */
  .menuwrap { position: relative; }
  .menu {
    position: absolute; right: 0; top: calc(100% + 6px); z-index: 20;
    background: var(--panel); border: 1px solid var(--line); border-radius: 8px;
    box-shadow: 0 6px 24px var(--shadow); padding: 6px; min-width: 190px;
  }
  .menu h2 { font-size: 10.5px; font-weight: 600; color: var(--faint); margin: 6px 6px 4px;
             text-transform: uppercase; letter-spacing: .06em; }
  .menu label {
    display: flex; align-items: center; gap: 8px; padding: 4px 6px;
    border-radius: 5px; cursor: pointer; font-size: 12.5px;
  }
  .menu label:hover { background: var(--bg); }
  .menu input { accent-color: var(--accent); margin: 0; }
  .menu .swatch { width: 8px; height: 8px; border-radius: 50%; background: var(--c); flex: none; }
  .menu .n { margin-left: auto; color: var(--faint); font-size: 11px;
             font-variant-numeric: tabular-nums; }
  .menu .row { display: flex; gap: 4px; padding: 4px 4px 2px; border-top: 1px solid var(--line);
               margin-top: 4px; }
  .menu .row button { flex: 1; font-size: 11.5px; padding: 3px 0; }

  #err {
    display: none; margin: 0; padding: 8px 18px; background: var(--blocked);
    color: #fff; font-family: ui-monospace, monospace; font-size: 12px;
    white-space: pre-wrap;
  }

  #main { display: flex; align-items: stretch; height: calc(100vh - 92px); }

  /* The tree the vault actually is. The chip rows it replaces were a flat list
     that had reached eleven entries and could not show nesting at all. */
  #side {
    width: var(--sidew, 264px); flex: none; background: var(--panel);
    border-right: 1px solid var(--line);
    display: flex; flex-direction: column; min-height: 0; position: relative;
  }
  #side.hidden { display: none; }
  /* Drag the edge to widen. A deep tree with long slugs needs more than one
     fixed width, and which width depends on how far in you are. */
  #grip {
    position: absolute; top: 0; right: -3px; bottom: 0; width: 7px; cursor: col-resize;
    z-index: 6;
  }
  #grip:hover, #grip.dragging { background: color-mix(in srgb, var(--accent) 45%, transparent); }
  /* #main sets display:flex, which outranks the hidden attribute on its own. */
  [hidden] { display: none !important; }
  body.resizing { cursor: col-resize; user-select: none; }
  .sidehead {
    display: flex; align-items: center; gap: 4px; padding: 8px 8px 8px 12px;
    border-bottom: 1px solid var(--line); flex: none;
  }
  .sidehead .grow { flex: 1; }
  .sidehead button {
    font-size: 12px; padding: 3px 8px; color: var(--dim); background: transparent;
    border-color: transparent;
  }
  .sidehead button:hover { color: var(--ink); border-color: var(--line); }
  /* Time is a scope like any other, so it sits with the tree rather than in
     the top bar: the sidebar is where "what am I looking at" is decided. */
  .sidetime {
    display: flex; align-items: center; gap: 2px; padding: 6px 8px 7px 12px;
    border-bottom: 1px solid var(--line); flex: none; font-size: 11.5px;
    color: var(--faint);
  }
  .sidetime span { margin-right: 4px; width: 46px; flex: none; }
  .sidetime button {
    font: inherit; font-size: 11.5px; font-family: ui-monospace, monospace;
    padding: 2px 7px; border-radius: 5px; border: 1px solid transparent;
    background: transparent; color: var(--dim); cursor: pointer;
  }
  .sidetime button:hover { color: var(--ink); border-color: var(--line); }
  .sidetime button[aria-pressed="true"] {
    color: var(--panel); background: var(--accent); border-color: var(--accent);
  }

  #tree { overflow-y: auto; padding: 6px 4px 18px; min-height: 0; flex: 1; }

  /* Every scrolling region, in one place. The old rules styled the thumb only,
     so the track, the corner and the arrow buttons kept their defaults and drew
     as pale blocks against the dark theme. `scrollbar-color` covers the browsers
     that do not take the -webkit- pseudo-elements at all. */
  #tree, .cards, #project, .primenu, #ctx {
    scrollbar-width: thin;
    scrollbar-color: var(--line) transparent;
  }
  ::-webkit-scrollbar { width: 8px; height: 8px; }
  ::-webkit-scrollbar-track,
  ::-webkit-scrollbar-corner { background: transparent; }
  ::-webkit-scrollbar-thumb {
    background: var(--line); border-radius: 4px;
    border: 2px solid transparent; background-clip: content-box;
  }
  ::-webkit-scrollbar-thumb:hover { background: var(--faint); background-clip: content-box; }
  ::-webkit-scrollbar-button { display: none; width: 0; height: 0; }

  .row {
    display: flex; align-items: center; gap: 7px; padding: 2px 8px 2px 0;
    border-radius: 5px; cursor: default; font-size: 13.5px; white-space: nowrap;
    line-height: 1.55;
  }
  .row:hover { background: var(--bg); }
  .row.sel { background: color-mix(in srgb, var(--accent) 14%, var(--panel)); }
  /* A drawn chevron rather than a text glyph: the arrows rendered at a
     different weight and baseline to everything around them. */
  .twist {
    width: 16px; height: 16px; flex: none; color: var(--faint); cursor: pointer;
    display: flex; align-items: center; justify-content: center; border-radius: 4px;
  }
  .twist:hover { color: var(--ink); background: var(--bg); }
  .twist svg { width: 10px; height: 10px; transition: transform .12s ease; }
  .twist.shut svg { transform: rotate(-90deg); }
  .twist.leaf { visibility: hidden; }
  .row input { accent-color: var(--accent); margin: 0; flex: none; cursor: pointer;
               width: 14px; height: 14px; }
  .rdot { width: 8px; height: 8px; border-radius: 50%; background: var(--c); flex: none; }
  .row.tracked .rname { color: var(--accent); }
  .rname {
    overflow: hidden; text-overflow: ellipsis; cursor: pointer; flex: 1; min-width: 0;
  }
  .row.off .rname, .row.off .rn { opacity: .42; }
  .row.bare .rname { color: var(--faint); }
  .row.bare .rdot { opacity: .35; }
  .rn { color: var(--faint); font-size: 12px; font-variant-numeric: tabular-nums;
        flex: none; font-family: ui-monospace, monospace; }
  .rgo {
    flex: none; font-size: 11px; font-family: ui-monospace, monospace; color: var(--accent);
    border: 1px solid transparent; border-radius: 4px; padding: 0 4px; cursor: pointer;
    background: transparent;
  }
  .rgo:hover { border-color: var(--accent); }

  #board {
    display: flex; gap: 12px; padding: 14px 18px 18px; align-items: stretch;
    overflow-x: auto; flex: 1; min-width: 0;
  }
  .col {
    flex: 1 1 0; min-width: 215px; background: var(--panel);
    border: 1px solid var(--line); border-radius: 10px; padding: 8px;
    display: flex; flex-direction: column; min-height: 0;
  }
  .col.over { border-color: var(--accent); background: color-mix(in srgb, var(--accent) 7%, var(--panel)); }
  .colhead {
    display: flex; align-items: center; gap: 7px; padding: 2px 4px 6px;
    border-bottom: 1px solid var(--line); font-size: 12px; font-weight: 600;
    flex: none;
  }
  .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--c); flex: none; }
  .count { color: var(--faint); font-weight: 400; margin-left: auto; font-variant-numeric: tabular-nums; }
  /* Columns scroll on their own so a 26-card column cannot push the board
     off-screen and hide the five next to it. */
  .cards {
    display: flex; flex-direction: column; gap: 8px;
    /* Room under the last card. At 2px it sat flush against the column's
       rounded corner, so a card that happened to end there looked sliced off
       rather than scrolled to. */
    /* `clip` on the cross axis rather than leaving it to compute to `auto`:
       setting overflow on one axis alone turns the other into a scroll
       container, which drew a horizontal scrollbar under every column that had
       a card a few pixels wide of its content box. */
    overflow-y: auto; overflow-x: clip;
    min-height: 0; padding: 8px 2px 10px; margin: 0 -2px;
  }

  .card {
    background: var(--card); border: 1px solid var(--line); border-left: 3px solid var(--c);
    border-radius: 8px; padding: 8px 10px; cursor: grab;
    box-shadow: 0 1px 2px var(--shadow); transition: box-shadow .08s, border-color .08s;
  }
  /* Every hover and selected state keeps the left edge, because that edge is
     the status and nothing else on the card says it. Before, three different
     things all reached for `border-color` and whichever won took the status
     stripe with it. */
  .card:hover { box-shadow: 0 2px 8px var(--shadow); border-color: var(--dim);
                border-left-color: var(--c); }
  .card.dragging { opacity: .4; cursor: grabbing; }
  .card.open { border-color: var(--accent); border-left-color: var(--c); }
  .row .rlive {
    width: 7px; height: 7px; border-radius: 50%; background: var(--accent);
    flex: none; animation: pulse 1.8s ease-in-out infinite;
  }

  /* Right-click menu. One flat menu with sections rather than submenus: every
     action is one press away and nothing has to be hovered to be found. */
  #ctx {
    position: fixed; z-index: 62; min-width: 216px; max-width: 280px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 9px;
    box-shadow: 0 10px 34px var(--shadow); padding: 5px; font-size: 12.5px;
  }
  #ctx .ctxhead {
    padding: 4px 8px 6px; border-bottom: 1px solid var(--line); margin-bottom: 4px;
  }
  #ctx .ctxhead b { display: block; font-size: 12.5px; overflow-wrap: anywhere; }
  #ctx .ctxhead span {
    color: var(--faint); font-size: 11px; font-family: ui-monospace, monospace;
    display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  }
  #ctx button {
    display: flex; align-items: center; gap: 8px; width: 100%; border: 0;
    background: transparent; padding: 5px 8px; border-radius: 6px; color: var(--ink);
    cursor: pointer; text-align: left; font: inherit; font-size: 12.5px;
  }
  #ctx button:hover:not(:disabled) { background: var(--bg); }
  #ctx button:disabled { color: var(--faint); cursor: default; }
  #ctx button svg { width: 12px; height: 12px; flex: none; }
  #ctx hr { border: 0; border-top: 1px solid var(--line); margin: 4px 0; }
  #ctx .ctxlabel {
    color: var(--faint); font-size: 10.5px; text-transform: uppercase;
    letter-spacing: .06em; padding: 3px 8px 2px;
  }
  #ctx .ctxrow { display: flex; flex-wrap: wrap; gap: 3px; padding: 1px 6px 3px; }
  #ctx .ctxrow button {
    width: auto; padding: 2px 8px; border-radius: 999px; font-size: 11.5px;
    font-family: ui-monospace, monospace; border: 1px solid var(--c, var(--line));
    color: var(--c, var(--dim));
  }
  #ctx .ctxrow button[aria-current="true"] {
    background: var(--c, var(--accent)); color: var(--panel);
  }
  #ctx a.ctxlink {
    display: flex; gap: 8px; padding: 5px 8px; border-radius: 6px;
    color: var(--accent); text-decoration: none; font-size: 12px;
    font-family: ui-monospace, monospace;
  }
  #ctx a.ctxlink:hover { background: var(--bg); }
  /* One channel per concern, so two facts are never read off one shape:
       status   -> the left edge stripe, never overridden by anything below
       tracked  -> the bookmark, which is the only filled accent shape on a card
       priority -> the bars, which only exist on something already tracked
       running  -> the bar across the foot, which is the only thing that moves
     They had been sharing a border and a tint, which is why "open somewhere"
     and "tracked" looked like the same card with a slightly different edge. */
  .card.tracked { background: color-mix(in srgb, var(--accent) 10%, var(--card)); }
  .card { position: relative; }
  /* The two controls sit together but do different jobs: the bookmark decides
     whether this is being carried at all, the bars rank something already
     carried. Priority only appears once there is something to rank. */
  /* The two marks sit on one baseline, a little below the top edge. The
     bookmark had been hung off the edge itself, which made it the loudest thing
     on the card and left it visibly unbalanced against the priority bars beside
     it. The card's own tint already says "tracked", so the bookmark only has to
     confirm it rather than carry it alone. */
  .marks {
    position: absolute; top: 6px; right: 7px; display: flex; align-items: center;
    gap: 4px;
  }
  .pri {
    flex: none; width: 19px; height: 19px; display: flex; align-items: center;
    justify-content: center; cursor: pointer; border: 0; background: transparent;
    color: var(--faint); border-radius: 5px; opacity: 0; padding: 0;
  }
  .pin {
    flex: none; width: 14px; height: 19px; display: flex; align-items: center;
    justify-content: center; cursor: pointer; border: 0; background: transparent;
    color: var(--faint); opacity: 0; padding: 0;
  }
  .card:hover .pin, .card:hover .pri, .pin.on, .pri.on { opacity: 1; }
  /* Stated outright rather than left to `.pin.on` winning the cascade: the
     bookmark is the tracked signal, and a rule elsewhere that happens to reach
     opacity would silently take it away and leave only the tint. */
  .card.tracked .pin { opacity: 1; }
  /* A tracked card always shows its rank control, ranked or not. Hiding it
     until hover meant nothing on screen said the control existed. */
  .card.tracked .pri { opacity: 1; }
  .card.tracked .pri:not(.on) { color: var(--line); }
  .card.tracked .pri:not(.on):hover { color: var(--accent); }
  .pin.on { color: var(--accent); }
  .pin:not(.on):hover { color: var(--accent); }
  .pri:hover { background: var(--bg); color: var(--accent); }
  /* `flex: none` on the glyphs, not only on the buttons holding them. An svg
     flex item has a min-content width of zero, so on a card where the marks row
     was the least bit tight the bookmark shrank to 0x15 and vanished -- which
     read as "this tracked card has no bookmark" rather than as a layout bug,
     because the card's tint was still there. */
  .pin svg { flex: none; width: 12px; height: 15px; }
  .pri svg { flex: none; width: 15px; height: 15px; }
  .pri.high { color: var(--blocked); }
  .pri.medium { color: var(--in-progress); }
  .pri.low { color: var(--dim); }

  /* The rank menu. Four rows, because "none" has to be reachable. */
  .primenu {
    position: absolute; top: 26px; right: 4px; z-index: 20; min-width: 124px;
    background: var(--panel); border: 1px solid var(--line); border-radius: 8px;
    box-shadow: 0 6px 24px var(--shadow); padding: 4px;
  }
  .primenu button {
    display: flex; align-items: center; gap: 8px; width: 100%; border: 0;
    background: transparent; padding: 4px 7px; border-radius: 5px; font-size: 12px;
    color: var(--ink); cursor: pointer; text-align: left;
  }
  .primenu button:hover { background: var(--bg); }
  .primenu svg { width: 12px; height: 12px; flex: none; }
  /* The marks float over this row, so it ends before they start rather than
     running under them and being covered mid-word. Reserved unconditionally:
     the bookmark appears on hover, and a trail that reflowed on hover would be
     worse than one that is always a little short. */
  .card .trail { padding-right: 44px; }
  .trail { color: var(--faint); font-size: 11px; font-family: ui-monospace, monospace;
           white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .title { font-weight: 600; font-size: 14px; margin: 1px 0 3px; overflow-wrap: anywhere; }
  .desc { color: var(--dim); font-size: 12.5px; overflow-wrap: anywhere; }
  .meta { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; margin-top: 6px; }
  /* Repo chips say where the work lives; link chips are things to click. With
     the arrow glyph gone they were identical, so the difference is carried by
     fill and color instead. */
  .tag {
    font-size: 11px; font-family: ui-monospace, monospace; color: var(--faint);
    border: 1px solid var(--line); border-radius: 4px; padding: 0 5px;
    text-decoration: none; white-space: nowrap;
  }
  a.tag {
    color: var(--accent);
    border-color: color-mix(in srgb, var(--accent) 30%, var(--line));
    text-decoration: underline;
    text-decoration-color: color-mix(in srgb, var(--accent) 40%, transparent);
    text-underline-offset: 2px;
  }
  a.tag:hover { color: var(--ink); border-color: var(--dim);
                text-decoration-color: currentColor; }
  .tag.more { cursor: pointer; border-style: dashed; color: var(--dim); }
  .jump {
    font: inherit; font-size: 11px; font-family: ui-monospace, monospace;
    color: var(--accent); background: transparent; border: 1px solid transparent;
    border-radius: 4px; padding: 0 5px; cursor: pointer; margin-left: -2px;
  }
  .jump:hover { border-color: var(--accent); }
  .roll { display: inline-flex; gap: 5px; align-items: center; }
  .roll i { font-style: normal; font-size: 11px; font-family: ui-monospace, monospace;
            color: var(--r); font-variant-numeric: tabular-nums; }
  .agent {
    display: inline-flex; align-items: center; gap: 5px; font-size: 11px;
    color: var(--accent); font-family: ui-monospace, monospace;
  }
  .agent.stale { color: var(--faint); }
  .agent.waits { color: var(--in-progress); }
  .pulse {
    width: 7px; height: 7px; border-radius: 50%; background: currentColor;
    animation: pulse 1.8s ease-in-out infinite;
  }
  .agent.stale .pulse { animation: none; opacity: .6; }
  @keyframes pulse { 0%,100% { opacity: 1; transform: scale(1); }
                     50% { opacity: .35; transform: scale(.75); } }
  .when { font-size: 11px; color: var(--faint); font-family: ui-monospace, monospace; }

  /* The state bar across the foot of a card. Full width and its own row, so
     "waiting for you" is read without looking for it, and the whole bar is the
     jump target rather than a chip inside it. Named `state`, not `bar`: the
     header already owns `.bar`, and sharing it put this padding and border on
     the header too.

     The negative margins have to match the card's padding exactly (8px 10px)
     or the background overshoots and shows as a sliver beside the left edge
     stripe, which is a 3px border the margin never gets to cross. */
  .state {
    display: flex; align-items: center; gap: 7px;
    margin: 9px -10px -8px; padding: 6px 10px;
    border-top: 1px solid var(--line);
    border-radius: 0 0 5px 5px;
    font-size: 11.5px; font-family: ui-monospace, monospace;
    color: var(--dim); background: transparent;
  }
  .state.jumpable { cursor: pointer; transition: background .08s, box-shadow .08s; }
  /* The hover had been 14% of the state colour, which on a waiting bar already
     tinted to 11% was a change too small to notice -- so the bar read as not
     clickable and only the glyph inside it looked live. It now lifts to a
     clearly different fill and outlines itself, so the whole strip says it is
     one target. `inset` rather than a border: a border would resize the bar and
     shift the row under the cursor. */
  .state.jumpable:hover {
    background: color-mix(in srgb, currentColor 30%, transparent);
    box-shadow: inset 0 0 0 1px color-mix(in srgb, currentColor 55%, transparent);
    color: var(--ink);
  }
  .state.waiting.jumpable:hover { color: var(--in-progress); }
  .state.working.jumpable:hover { color: var(--accent); }
  .state.jumpable:hover .since { color: inherit; }
  .state .what { font-weight: 600; letter-spacing: .01em; }
  .state .since { color: var(--faint); }
  .state .dot { width: 7px; height: 7px; border-radius: 50%; background: currentColor; }
  /* Waiting is the only state that wants something, so it is the only one that
     carries colour. Working and open are facts to read, not calls to act. */
  .state.waiting {
    color: var(--in-progress);
    border-top-color: color-mix(in srgb, var(--in-progress) 35%, var(--line));
    background: color-mix(in srgb, var(--in-progress) 11%, transparent);
  }
  .state.working { color: var(--accent); }
  .state.unknown, .state.idle-open { color: var(--faint); }
  /* The desktop is a fact the bar reports, not a second control inside a
     control: the bar is already the button. */
  .state .desk {
    margin-left: auto; display: inline-flex; align-items: center; gap: 4px;
    color: var(--faint); font-size: 11px;
  }
  .state.jumpable:hover .desk { color: inherit; }
  .state .desk svg { width: 13px; height: 13px; }
  .empty { color: var(--faint); font-size: 12px; padding: 6px 4px; font-style: italic; }

  /* Project page.
     A page rather than a panel, so it gets the whole window and can hold as
     many cards as a node has links. Everything here is prefixed `p`: three
     class collisions in this stylesheet have already cost a round of
     screenshots each, and a prefix is cheaper than checking every name. */
  /* The same height #main gets, so swapping one for the other does not move
     the header or the footer. */
  #project { height: calc(100vh - 92px); overflow-y: auto; background: var(--bg); }
  .phead {
    padding: 14px 20px 13px; border-bottom: 1px solid var(--line);
    background: var(--panel);
  }
  .phead h2 { margin: 4px 0 3px; font-size: 18px; overflow-wrap: anywhere; }
  .pback {
    display: inline-flex; align-items: center; gap: 5px; font-size: 12px;
    margin-bottom: 2px;
  }
  .pback svg { width: 10px; height: 10px; }
  .phead .agent, .phead .when { font-size: 12px; white-space: nowrap; }
  .phead .jump { font-size: 12px; padding: 1px 7px; }

  .pgrid {
    display: grid; gap: 13px; padding: 15px 20px 32px;
    grid-template-columns: repeat(auto-fill, minmax(330px, 1fr));
    align-items: start;
  }
  .pcard {
    background: var(--card); border: 1px solid var(--line); border-radius: 8px;
    padding: 12px 14px 13px; min-width: 0;
  }
  /* A card whose content is prose, not facts, gets the full width: wrapping a
     head or a log into a 330px column makes every line a fragment. */
  .pcard.pwide { grid-column: 1 / -1; }
  .pcard > h3 {
    font-size: 10.5px; font-weight: 600; color: var(--faint); margin: 0 0 9px;
    text-transform: uppercase; letter-spacing: .06em;
    display: flex; align-items: center; gap: 7px;
  }
  .pcard > h3 .grow { flex: 1; }
  .pcard > h3 a { color: var(--faint); font-weight: 600; }
  .pcard > h3 a:hover { color: var(--accent); }
  .pcard p { margin: 0 0 8px; color: var(--dim); overflow-wrap: anywhere; }
  .pcard .ptitle {
    font-size: 13.5px; color: var(--ink); margin: 0 0 8px; line-height: 1.35;
    overflow-wrap: anywhere;
  }
  .pcard .prose { font-size: 13px; }

  /* The one word that says where a thing stands. It carries the card's colour
     so the grid can be read without reading any of it. */
  .pbadge {
    display: inline-flex; align-items: center; gap: 5px; font-size: 11.5px;
    font-weight: 600; border-radius: 999px; padding: 2px 9px;
    border: 1px solid color-mix(in srgb, var(--t) 45%, transparent);
    background: color-mix(in srgb, var(--t) 13%, transparent); color: var(--t);
    white-space: nowrap;
  }
  .pbadge.good { --t: var(--in-review); }
  .pbadge.warn { --t: var(--in-progress); }
  .pbadge.bad  { --t: var(--blocked); }
  .pbadge.mute { --t: var(--faint); }

  .prow {
    display: flex; flex-wrap: wrap; align-items: center; gap: 6px 10px;
    font-size: 12px; color: var(--dim); margin-top: 9px;
  }
  .prow .sep { color: var(--line); }
  /* Nothing else in the stylesheet colours a bare anchor, so one inside a card
     drew as the browser's default blue-on-dark and was unreadable. */
  .prow a { color: var(--accent); }
  .pfail {
    margin-top: 8px; font-size: 11.5px; color: var(--blocked);
    font-family: ui-monospace, monospace; overflow-wrap: anywhere;
  }
  .pmono {
    font-family: ui-monospace, monospace; font-size: 11.5px; color: var(--faint);
    overflow-wrap: anywhere;
  }
  .pnote { font-size: 11.5px; color: var(--faint); font-style: italic; margin-top: 9px; }
  .pcard .logline:last-child { border-bottom: none; }
  /* Two rows, not one. Five controls in a 520px panel had nothing telling them
     to stay whole, so every label broke mid-word: "in-/progress", "no/priority",
     "jump to desktop/8". The controls sit on one line and the facts about the
     node on the next, and nothing in either wraps. */
  .statusline {
    display: flex; align-items: center; flex-wrap: wrap; gap: 6px;
    margin-top: 9px;
  }
  .factline {
    display: flex; align-items: center; flex-wrap: wrap; gap: 6px 14px;
    margin-top: 8px; font-size: 12px; color: var(--dim);
  }
  /* One shape for everything on the control row, so they line up and share a
     height instead of each carrying its own inline style. */
  .pill, .dbtn {
    display: inline-flex; align-items: center; gap: 6px; height: 24px;
    padding: 0 10px; border-radius: 999px; font-size: 12px; white-space: nowrap;
    font-family: ui-monospace, monospace; border: 1px solid var(--line);
    background: transparent; color: var(--dim); cursor: default;
  }
  .pill { border-color: var(--c); color: var(--c); }
  button.pill { cursor: pointer; }
  button.pill:hover { background: color-mix(in srgb, var(--c) 12%, transparent); }
  .pill svg { width: 9px; height: 9px; opacity: .7; }
  button.dbtn { cursor: pointer; }
  button.dbtn:hover { border-color: var(--dim); color: var(--ink); }
  .dbtn.on { border-color: var(--accent); color: var(--accent); }
  button.dbtn.on:hover { color: var(--accent); border-color: var(--accent); }
  .dbtn svg { width: 12px; height: 12px; flex: none; }
  .dbtn.high { color: var(--blocked); border-color: var(--blocked); }
  .dbtn.medium { color: var(--in-progress); border-color: var(--in-progress); }
  .dbtn.low { color: var(--dim); }
  .kv { display: grid; grid-template-columns: max-content 1fr; gap: 6px 14px; font-size: 12px;
        align-items: baseline; }
  .kv dt { color: var(--faint); font-family: ui-monospace, monospace; font-size: 11px; }
  .kv dd { margin: 0; overflow-wrap: anywhere; font-family: ui-monospace, monospace; font-size: 11.5px; }
  .links { display: flex; flex-direction: column; gap: 4px; }
  .links a {
    display: flex; gap: 10px; align-items: baseline; text-decoration: none;
    color: var(--ink); font-size: 12px; padding: 4px 7px; border-radius: 5px;
    border: 1px solid var(--line);
  }
  .links a:hover { border-color: var(--accent); }
  .links .k { font-family: ui-monospace, monospace; font-size: 11px; color: var(--accent);
              flex: none; min-width: 96px; }
  .links .v { color: var(--faint); font-size: 11px; overflow: hidden;
              text-overflow: ellipsis; white-space: nowrap; }
  .logline {
    font-size: 12.5px; color: var(--dim); padding: 0 0 9px 12px;
    border-left: 2px solid var(--line); overflow-wrap: anywhere; line-height: 1.5;
  }
  .logline:last-child { border-left-color: var(--accent); color: var(--ink);
                        padding-bottom: 0; }
  /* The panel already scrolls. An inner scroller on the head gave it a second
     scrollbar and left a band of dead space under it. */
  .prose { font-size: 12.5px; color: var(--dim); overflow-wrap: anywhere; }
  .prose > :first-child { margin-top: 0; }
  .prose p { margin: 0 0 9px; }
  .prose h4, .prose h5, .prose h6 {
    font-size: 13px; font-weight: 600; color: var(--ink);
    margin: 16px 0 6px; text-transform: none; letter-spacing: 0;
  }
  .prose ul { margin: 0 0 9px; padding-left: 18px; }
  .prose li { margin: 0 0 3px; }
  .prose blockquote {
    margin: 0 0 9px; padding: 2px 0 2px 11px; border-left: 2px solid var(--line);
    color: var(--faint);
  }
  .prose pre {
    background: var(--bg); border: 1px solid var(--line); border-radius: 6px;
    padding: 8px 10px; overflow-x: auto; font-size: 11.5px; margin: 0 0 9px;
  }
  .prose code, .logline code {
    font-family: ui-monospace, monospace; font-size: .92em;
    background: var(--bg); border-radius: 3px; padding: 0 3px;
  }
  .prose a, .logline a { color: var(--accent); }
  .wiki {
    font-family: ui-monospace, monospace; font-size: .92em; color: var(--faint);
    border-bottom: 1px dotted var(--line);
  }
  .notes { display: flex; flex-wrap: wrap; gap: 4px; }

  /* Its own band, matching the header's rule at the other end. It had no top
     padding at all, and the board above it is a scroll container whose bottom
     padding goes under its own scrollbar, so the key hints ended up touching
     the columns. */
  footer {
    border-top: 1px solid var(--line); background: var(--panel);
    padding: 9px 18px 10px; color: var(--faint); font-size: 11px;
  }
  kbd { font-family: ui-monospace, monospace; border: 1px solid var(--line);
        border-radius: 3px; padding: 0 4px; }
</style>
</head>
<body>
<header>
  <div class="bar">
    <h1>Thoughts Dashboard</h1>
    <span class="vault" id="vault"></span>
    <input type="search" id="q" placeholder="filter by name, description, path" autocomplete="off">
    <span class="spacer"></span>
    <span id="live"></span>
    <span class="menuwrap">
      <button id="colsbtn" title="which columns to show"><svg viewBox="0 0 14 14" fill="currentColor" aria-hidden="true"><rect x="1" y="2" width="3.4" height="10" rx="1"/><rect x="5.3" y="2" width="3.4" height="10" rx="1" opacity=".65"/><rect x="9.6" y="2" width="3.4" height="10" rx="1" opacity=".35"/></svg></button>
      <div class="menu" id="colsmenu" hidden></div>
    </span>
  </div>
</header>
<pre id="err"></pre>
<div id="main">
  <div id="rail"><button class="railbtn" id="show" title="show the sidebar (b)"><svg viewBox="0 0 10 10" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6.5 2 L3.5 5 L6.5 8"/></svg></button></div>
  <aside id="side">
    <div class="sidehead">
      <button id="all" title="check everything">all</button>
      <button id="none" title="uncheck everything">none</button>
      <span class="grow"></span>
      <button id="collapse" title="collapse or expand every branch">fold</button>
      <button class="sidefold" id="hide" title="hide the sidebar (b)"><svg viewBox="0 0 10 10" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6.5 2 L3.5 5 L6.5 8"/></svg></button>
    </div>
    <div class="sidetime" id="sidetime"></div>
    <div class="sidetime" id="sideonly"></div>
    <div id="tree"></div>
    <div id="grip" title="drag to resize"></div>
  </aside>
  <div id="board"></div>
</div>
<div id="project" hidden></div>
<footer>
  <kbd>/</kbd> search &middot; <kbd>b</kbd> tree &middot; <kbd>c</kbd> columns &middot;
  <kbd>r</kbd> refresh &middot; <kbd>esc</kbd> back &middot; click a card to open its project,
  drag it to change its node's <code>status:</code> &middot; bookmark to track it, bars to rank it
  &middot; <kbd>alt</kbd>-click a checkbox for that node alone, not its children
</footer>
<script>
const NO_STATUS = "";
let board = null, dragging = null, rendered = null, detailPath = null;

// Polling is held during a drag so a re-render cannot pull the card out from
// under the cursor. It is held by timestamp rather than by a flag: `dragend`
// is the only thing that would clear a flag, and it fires on the element the
// drop already replaced, so one missed event used to stop the board refreshing
// for the rest of the session with no sign that anything was wrong.
let holdUntil = 0;
const hold = () => { holdUntil = Date.now() + 8000; };
const release = () => { holdUntil = 0; };

// ---- persisted view state ------------------------------------------------
// Every access is wrapped: a private window or blocked site data should give
// back a default board, never an error.
function load(key, fallback) {
  try {
    const raw = localStorage.getItem("board." + key);
    return raw === null ? fallback : JSON.parse(raw);
  } catch (e) { return fallback; }
}
function save(key, value) {
  try { localStorage.setItem("board." + key, JSON.stringify(value)); } catch (e) {}
}

let onlyLive = false;
let onlyOpen = false;
let onlyTracked = load("trackedonly", false);
let priMenu = null;
// Which nodes are NOT on the board. Storing the exceptions rather than the
// selection means a node added to the vault tomorrow shows up by default
// instead of being invisible because it was not in a saved list.
let off = new Set(load("off", []));
// Collapsed rather than expanded, for the same reason: a new child appears
// under an open parent instead of being hidden by a stale record.
let shut = new Set(load("shut", null) || []);
let shutInit = !load("shut", null);
let sideHidden = load("side", false);
let sideWidth = load("sidew", 264);
// Windows in seconds, `0` meaning no limit. Short ones first because "what did
// I touch today" is asked far more often than "what moved this quarter".
const WINDOWS = [["any", 0], ["1d", 86400], ["3d", 3 * 86400],
                 ["1w", 7 * 86400], ["1mo", 30 * 86400]];
let within = load("within", 0);
let query = "";

// Which columns are on. Absent from the map means "use the default", so a
// status the vault grows later shows up instead of being silently hidden.
// done, canceled and untriaged are off to begin with; everything else is on.
let cols = load("cols", {});
const colDefault = s => !(s === "done" || s === "canceled" || s === NO_STATUS);
const colOn = s => (s in cols) ? cols[s] : colDefault(s);

// Enough markdown for what a vault note actually contains: headings, emphasis,
// code, lists, links and the wiki-links the vault is built on. Deliberately not
// a full parser -- it escapes first and only ever adds tags it put there itself.
function md(src) {
  const lines = esc(src).split("\n");
  const out = [];
  let inList = false, inCode = false;
  const inline = s => s
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    // A wiki-link is a reference to another vault note. It is not a URL, so it
    // renders as the thing it names rather than as a dead link.
    .replace(/\[\[([^\]|]+)\|([^\]]+)\]\]/g, '<span class="wiki">$2</span>')
    .replace(/\[\[([^\]]+)\]\]/g, (m, p) =>
      '<span class="wiki">' + p.split("/").pop() + '</span>')
    .replace(/\[([^\]]+)\]\((https?:[^)\s]+)\)/g,
      '<a href="$2" target="_blank" rel="noreferrer">$1</a>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/(^|[^*])\*([^*]+)\*/g, '$1<em>$2</em>');
  const closeList = () => { if (inList) { out.push("</ul>"); inList = false; } };
  for (const raw of lines) {
    const line = raw.trimEnd();
    if (/^```/.test(line)) {
      closeList();
      out.push(inCode ? "</pre>" : "<pre>");
      inCode = !inCode;
      continue;
    }
    if (inCode) { out.push(line); continue; }
    const h = /^(#{1,6})\s+(.*)$/.exec(line);
    if (h) { closeList(); out.push(`<h${h[1].length + 3}>${inline(h[2])}</h${h[1].length + 3}>`); continue; }
    if (/^\s*[-*]\s+/.test(line)) {
      if (!inList) { out.push("<ul>"); inList = true; }
      out.push(`<li>${inline(line.replace(/^\s*[-*]\s+/, ""))}</li>`);
      continue;
    }
    if (/^\s*&gt;\s?/.test(line)) {
      closeList();
      out.push(`<blockquote>${inline(line.replace(/^\s*&gt;\s?/, ""))}</blockquote>`);
      continue;
    }
    if (!line) { closeList(); continue; }
    closeList();
    out.push(`<p>${inline(line)}</p>`);
  }
  closeList();
  if (inCode) out.push("</pre>");
  return out.join("\n");
}

const esc = s => String(s == null ? "" : s).replace(/[&<>"]/g,
  c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

const label = s => s === NO_STATUS ? "untriaged" : s;
const cssVar = s => "var(--" + (s || "none").replace(/[^a-z-]/g, "") + ", var(--none))";

function ago(seconds) {
  const s = Math.floor(seconds);
  if (s < 60) return s + "s";
  if (s < 3600) return Math.floor(s / 60) + "m";
  if (s < 86400) return Math.floor(s / 3600) + "h";
  if (s < 86400 * 30) return Math.floor(s / 86400) + "d";
  if (s < 86400 * 365) return Math.floor(s / 86400 / 30) + "mo";
  return Math.floor(s / 86400 / 365) + "y";
}

// ---- filtering -----------------------------------------------------------
function matches(c) {
  if (onlyTracked && !c.tracked) return false;
  // A node with no log and no head mtime cannot answer "when", so a time filter
  // excludes it rather than guessing that it is recent.
  if (within && !(c.touched && board.now - c.touched <= within)) return false;
  if (onlyOpen && !c.open) return false;
  if (onlyLive && !(c.agent && !c.agent.stale)) return false;
  if (off.has(c.path)) return false;
  if (query) {
    const hay = (c.slug + " " + c.description + " " + c.path).toLowerCase();
    if (!query.split(/\s+/).every(w => hay.includes(w))) return false;
  }
  return true;
}
const visible = () => board.cards.filter(matches);

// ---- rendering -----------------------------------------------------------
// Everything a rebuild would change. Deliberately excludes idle_seconds,
// which ticks every poll: rebuilding the board every 2s threw away column
// scroll position and made a long column impossible to read.
function signature(b) {
  return JSON.stringify([[...off].sort(), [...shut].sort(), sideHidden, query, cols,
    detailPath, onlyLive, onlyOpen, onlyTracked, priMenu, within, sideWidth,
    b.cards.map(c => [c.path, c.status, c.description, c.touched, c.tracked, c.priority,
                      c.open, !!c.agent, c.agent && c.agent.stale,
                      c.agent && c.agent.state])]);
}

// The cheap path: only the elapsed labels move, so only they get rewritten.
// Rebuilding the board for them threw away column scroll position every poll.
function tick() {
  for (const el of document.querySelectorAll(".card .state .since")) {
    const host = el.closest(".card");
    if (!host) continue;
    const card = board.cards.find(c => c.path === host.dataset.path);
    const a = card && card.agent;
    if (!a) continue;
    const secs = a.state ? a.state_seconds : a.idle_seconds;
    if (secs != null) el.textContent = ago(secs);
  }
}

function columns() {
  const known = board.statuses.slice();
  const extra = [];
  for (const c of visible()) {
    if (!known.includes(c.status) && c.status && !extra.includes(c.status))
      extra.push(c.status);
  }
  return known.concat(extra, [NO_STATUS]).filter(colOn);
}

// What this node is doing, across the foot of the card.
//
// This replaced a chip in the metadata row that showed seconds since the
// transcript last moved. That number could not tell a session thinking for four
// minutes from one that finished four minutes ago, which is the one question
// the card is read to answer, so making it bigger would only have made a
// misleading fact louder. `state` comes from the session itself.
//
// A node with no session but a window open still gets a bar, because "I have
// this open over there" is the same kind of fact and the same jump.
function liveBar(c) {
  const a = c.agent;
  const desktop = (a && a.desktop) || c.open;
  // The whole bar is the target, not a chip inside it. Aiming at a 40px button
  // to change desktop was the original complaint about `desk 8`, and moving the
  // button without widening it would have left the same aim.
  const jump = desktop
    ? `<span class="desk">${SCREEN}${esc(desktop)}</span>` : "";
  const hit = desktop
    // Switching to a desktop that already has a window on it never opens
    // anything, so this is the safe half of the workspace verbs.
    ? ` jumpable" data-pid="${a ? a.pid : ""}" data-desk="${esc(desktop)}"
        title="switch to desktop ${esc(desktop)}`
    : '"';
  if (!a) {
    return c.open
      ? `<div class="state idle-open${hit}><span class="what">open</span>${jump}</div>` : "";
  }
  if (a.state === "idle") {
    const waited = a.state_seconds == null ? "" : ago(a.state_seconds);
    return `<div class="state waiting${hit}><span class="dot"></span>
      <span class="what">waiting for you</span>
      <span class="since">${waited}</span>${jump}</div>`;
  }
  if (a.state === "busy") {
    const going = a.state_seconds == null ? "" : ago(a.state_seconds);
    return `<div class="state working${hit}><span class="dot pulse"></span>
      <span class="what">working</span>
      <span class="since">${going}</span>${jump}</div>`;
  }
  // No state reported: this is the old signal, and it is labelled as what it
  // measures rather than dressed up as one of the two above.
  return `<div class="state unknown${hit}><span class="dot"></span>
    <span class="what">quiet</span>
    <span class="since">${ago(a.idle_seconds)}</span>${jump}</div>`;
}

function cardHtml(c) {
  const color = cssVar(c.status);
  const keys = Object.keys(c.links || {});
  // A card carrying thirteen links turned into a block of chips that dwarfed
  // the description. Three, then a count that opens the detail panel.
  const shown = keys.slice(0, 3).map(k =>
    `<a class="tag" href="${esc(c.links[k])}" target="_blank" rel="noreferrer"
        onclick="event.stopPropagation()">${esc(k)}</a>`);
  if (keys.length > shown.length)
    shown.push(`<span class="tag more">+${keys.length - shown.length}</span>`);
  const repos = (c.repos || []).map(r =>
    `<span class="tag">${esc(r.split("/").pop())}</span>`);
  const live = c.agent && !c.agent.stale;
  const agent = !c.agent && c.touched
    ? `<span class="when">${ago(board.now - c.touched)}</span>` : "";
  // A bare "9 sub" said nothing a reader did not already know. The vault's own
  // docs say a rollup is walked rather than stored, so this is that walk.
  const roll = c.children ? `<span class="roll">` + Object.entries(c.rollup || {})
      .filter(([s]) => s !== "done" && s !== "canceled" && s !== "")
      .sort((a, b) => b[1] - a[1])
      .map(([s, n]) => `<i style="--r:${cssVar(s)}">${n} ${esc(label(s))}</i>`)
      .join("") + `<span class="tag">${c.children} sub</span></span>` : "";
  const trail = (c.trail || []).join(" / ");
  return `<div class="card${c.tracked ? " tracked" : ""}${c.path === detailPath ? " open" : ""}"
       draggable="true" data-path="${esc(c.path)}" style="--c:${color}" title="${esc(c.path)}">
    <div class="marks">
      ${c.tracked ? `<button class="pri ${esc(c.priority || "")} ${c.priority ? "on" : ""}"
          data-pri="${esc(c.path)}"
          title="${c.priority ? esc(c.priority) + " priority \u2014 click to change"
                              : "no priority \u2014 click to set one"}"
          >${BARS(PRI_LEVEL[c.priority] || 0)}</button>` : ""}
      <button class="pin ${c.tracked ? "on" : ""}" data-track="${esc(c.path)}"
        data-on="${c.tracked ? "0" : "1"}"
        title="${c.tracked ? "stop tracking" : "track this"}"
        >${c.tracked ? PIN_ON : PIN}</button>
    </div>
    ${priMenu === c.path ? `<div class="primenu">
      ${["high", "medium", "low"].map(k =>
        `<button data-set="${esc(c.path)}" data-level="${k}"
          style="color:var(--${k === "high" ? "blocked" : k === "medium" ? "in-progress" : "dim"})"
          >${BARS(PRI_LEVEL[k])}${k}</button>`).join("")}
      <button data-set="${esc(c.path)}" data-level="">${BARS(0)}none</button>
    </div>` : ""}
    ${trail ? `<div class="trail">${esc(trail)}</div>` : ""}
    <div class="title">${esc(c.slug)}</div>
    ${c.description ? `<div class="desc">${esc(c.description)}</div>` : ""}
    <div class="meta">${agent}${repos.join("")}${shown.join("")}${roll}
      ${c.ambiguous ? `<span class="tag" title="another node has this slug">dup slug</span>` : ""}</div>
    ${liveBar(c)}
  </div>`;
}

function render() {
  if (!board) return;
  const scroll = {};
  for (const c of document.querySelectorAll(".col"))
    scroll[c.dataset.status] = c.querySelector(".cards").scrollTop;

  document.getElementById("vault").textContent = board.vault;
  renderTree();
  if (!document.getElementById("colsmenu").hidden) renderMenu();

  const shown = visible();
  const running = shown.filter(c => c.agent && !c.agent.stale).length;
  const flight = shown.filter(c => !["done", "canceled", NO_STATUS].includes(c.status)).length;
  const live = document.getElementById("live");
  // The header counts what is on the board and nothing more. Every control that
  // decides what is on it lives in the sidebar, so there is one place to look.
  live.textContent = `${flight} in flight`;

  const el = document.getElementById("board");
  const cols_ = columns();
  el.innerHTML = cols_.length ? cols_.map(s => {
    const group = shown.filter(c => c.status === s);
    return `<section class="col" data-status="${esc(s)}" style="--c:${cssVar(s)}">
      <div class="colhead"><span class="dot"></span>${esc(label(s))}
        <span class="count">${group.length}</span></div>
      <div class="cards">${group.length ? group.map(cardHtml).join("")
                     : '<div class="empty">empty</div>'}</div>
    </section>`;
  }).join("") : '<div class="empty">every column is hidden &mdash; press c</div>';

  for (const c of el.querySelectorAll(".col")) {
    const keep = scroll[c.dataset.status];
    if (keep) c.querySelector(".cards").scrollTop = keep;
  }
  rendered = signature(board);
  wire();
}

function countBy(cards, fn) {
  const m = new Map();
  for (const c of cards) {
    const k = fn(c);
    if (k === null) continue;
    m.set(k, (m.get(k) || 0) + 1);
  }
  return m;
}

// One drawn chevron, rotated for the closed state, instead of two text glyphs
// that sat at different baselines from the text beside them.
// Drawn rather than emoji: these sit on a card and must not look like they came
// from a different font. Priority is three bars of rising height, which reads as
// a level down a column without needing the word.
const BARS = level => `<svg viewBox="0 0 14 14" fill="currentColor" aria-hidden="true">
  <rect x="1" y="9" width="3" height="4" rx="1" opacity="${level >= 1 ? 1 : .25}"/>
  <rect x="5.5" y="6" width="3" height="7" rx="1" opacity="${level >= 2 ? 1 : .25}"/>
  <rect x="10" y="3" width="3" height="10" rx="1" opacity="${level >= 3 ? 1 : .25}"/>
</svg>`;
const PRI_LEVEL = { low: 1, medium: 2, high: 3 };

// A bookmark, drawn rather than an emoji: it has to sit on a card without
// looking like it came from a different font.
// A monitor, for the desktop a window is on. The word "desk" next to a number
// was two tokens saying one thing, in a bar that is already narrow.
const SCREEN = `<svg viewBox="0 0 16 16" fill="none" stroke="currentColor"
  stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round" aria-hidden="true"
  ><rect x="1.5" y="2.5" width="13" height="9" rx="1.5"/><path d="M5.5 14h5"/></svg>`;
const RIBBON = "M2 0h10v15.5l-5-3.6-5 3.6z";
const PIN = `<svg viewBox="0 0 14 17" fill="none" stroke="currentColor"
  stroke-width="1.4" stroke-linejoin="round" aria-hidden="true"
  ><path d="${RIBBON}"/></svg>`;
const PIN_ON = `<svg viewBox="0 0 14 17" fill="currentColor" stroke="currentColor"
  stroke-width="1.4" stroke-linejoin="round" aria-hidden="true"
  ><path d="${RIBBON}"/></svg>`;


const BACK = `<svg viewBox="0 0 10 10" fill="none" stroke="currentColor"
  stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
  <path d="M6.5 2 L3.5 5 L6.5 8"/></svg>`;
const CARET = `<svg viewBox="0 0 10 10" fill="none" stroke="currentColor"
  stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"
  aria-hidden="true"><path d="M2 3.5 L5 6.5 L8 3.5"/></svg>`;

const CHEVRON = `<svg viewBox="0 0 10 10" fill="none" stroke="currentColor"
  stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"
  aria-hidden="true"><path d="M2 3.5 L5 6.5 L8 3.5"/></svg>`;

// ---- the tree -----------------------------------------------------------
// One node per directory, built from the card paths so it cannot disagree with
// the board about what exists.
function buildTree(cards) {
  const root = { name: "", path: "projects", kids: new Map(), card: null };
  for (const c of cards) {
    const segs = c.path.split("/").slice(1);
    let node = root, acc = "projects";
    for (const s of segs) {
      acc += "/" + s;
      if (!node.kids.has(s))
        node.kids.set(s, { name: s, path: acc, kids: new Map(), card: null });
      node = node.kids.get(s);
    }
    node.card = c;
  }
  return root;
}

function subtree(node, out = []) {
  if (node.card) out.push(node.path);
  for (const k of node.kids.values()) subtree(k, out);
  return out;
}

// Every directory in the tree, card or not. A folder that holds nodes without
// being one itself has no card, so keying collapse off card paths left exactly
// those folders permanently open.
function branches(node, out = []) {
  for (const k of node.kids.values()) {
    if (k.kids.size) out.push(k.path);
    branches(k, out);
  }
  return out;
}

// A checked node is on the board. Checking a parent checks everything under it,
// which is the rule a file picker already taught everyone.
function setSubtree(node, on) {
  for (const path of subtree(node)) on ? off.delete(path) : off.add(path);
  save("off", [...off]);
}

function tally(node) {
  const paths = subtree(node);
  const onCount = paths.filter(p => !off.has(p)).length;
  return { total: paths.length, on: onCount };
}

// How many of this subtree's cards a visible column would actually hold, which
// is the number worth printing next to a name.
function shownUnder(node) {
  const paths = new Set(subtree(node));
  return board.cards.filter(c => paths.has(c.path) && colOn(c.status) && matches(c)).length;
}

function rowHtml(node, depth) {
  const c = node.card;
  const kids = [...node.kids.values()].sort((a, b) => a.name.localeCompare(b.name));
  const t = tally(node);
  const state = t.on === 0 ? "off" : t.on === t.total ? "on" : "some";
  const shut_ = shut.has(node.path);
  const n = shownUnder(node);
  const rlive = c && c.agent && !c.agent.stale;
  const row = `<div class="row ${state === "off" ? "off" : ""} ${n ? "" : "bare"} ${c && c.tracked ? "tracked" : ""} ${c && c.path === detailPath ? "sel" : ""}"
       style="padding-left:${6 + depth * 13}px" data-path="${esc(node.path)}">
    <span class="twist ${kids.length ? "" : "leaf"} ${shut_ ? "shut" : ""}"
          data-twist="${esc(node.path)}">${CHEVRON}</span>
    <input type="checkbox" data-check="${esc(node.path)}"
      ${state === "on" ? "checked" : ""} ${state === "some" ? 'data-some="1"' : ""}>
    <span class="rdot" style="--c:${cssVar(c ? c.status : "")}"></span>
    <span class="rname" data-open="${esc(node.path)}" title="${esc(node.path)}">${esc(node.name)}</span>
    ${rlive ? `<span class="rlive" title="a claude session is working here"></span>` : ""}
    ${rlive && c.agent.desktop
      ? `<button class="rgo jump" data-pid="${c.agent.pid}"
           title="switch to desktop ${esc(c.agent.desktop)}">d${esc(c.agent.desktop)}</button>` : ""}
    <span class="rn">${n}</span>
  </div>`;
  if (shut_ || !kids.length) return row;
  return row + kids.map(k => rowHtml(k, depth + 1)).join("");
}

function renderTree() {
  const side = document.getElementById("side");
  side.style.setProperty("--sidew", sideWidth + "px");
  side.classList.toggle("hidden", sideHidden);
  document.getElementById("rail").classList.toggle("hidden", !sideHidden);
  if (sideHidden) return;
  const tracked = board.cards.filter(c => c.tracked).length;
  const opened = board.cards.filter(c => c.open).length;
  const live = board.cards.filter(c => c.agent && !c.agent.stale).length;
  document.getElementById("sideonly").innerHTML =
    `<span>only</span>
     <button id="onlytracked" aria-pressed="${onlyTracked}"
       title="only what you are tracking">tracked ${tracked}</button>
     <button id="onlyopen" aria-pressed="${onlyOpen}"
       title="only nodes with a window open on a desktop">open ${opened}</button>
     <button id="onlylive" aria-pressed="${onlyLive}"
       title="only nodes with a session in them">running ${live}</button>`;
  document.getElementById("onlytracked").addEventListener("click", () => {
    onlyTracked = !onlyTracked;
    save("trackedonly", onlyTracked);
    render();
  });
  document.getElementById("onlyopen").addEventListener("click", () => {
    onlyOpen = !onlyOpen;
    render();
  });
  document.getElementById("onlylive").addEventListener("click", () => {
    onlyLive = !onlyLive;
    render();
  });

  document.getElementById("sidetime").innerHTML =
    `<span>touched</span>` + WINDOWS.map(([label, secs]) =>
      `<button data-within="${secs}" aria-pressed="${within === secs}"
        >${label}</button>`).join("");
  for (const b of document.querySelectorAll("#sidetime button")) {
    b.addEventListener("click", () => {
      within = Number(b.dataset.within);
      save("within", within);
      render();
    });
  }

  const root = buildTree(board.cards);
  const top = [...root.kids.values()].sort((a, b) => a.name.localeCompare(b.name));
  if (shutInit) {
    // First run on this browser: every branch closed, so the tree opens at the
    // fourteen top-level nodes rather than at a hundred and fifty-seven.
    for (const b of branches(root)) shut.add(b);
    shutInit = false;
    save("shut", [...shut]);
  }
  document.getElementById("tree").innerHTML = top.map(k => rowHtml(k, 0)).join("");

  // A partly-checked parent is neither on nor off, and the browser only shows
  // that if it is set from script.
  for (const box of document.querySelectorAll("#tree input[data-some]"))
    box.indeterminate = true;

  const find = path => {
    let node = root;
    for (const s of path.split("/").slice(1)) node = node.kids.get(s);
    return node;
  };
  for (const box of document.querySelectorAll("#tree input[data-check]")) {
    // A modifier takes just this one node, leaving its children alone. That is
    // how you drop a parent's own card -- "cyvl" sitting in in-progress next to
    // the work it contains -- without dropping the work with it.
    box.addEventListener("click", e => {
      if (!(e.shiftKey || e.metaKey || e.altKey || e.ctrlKey)) return;
      e.preventDefault();
      const path = box.dataset.check;
      off.has(path) ? off.delete(path) : off.add(path);
      save("off", [...off]);
      render();
    });
    box.addEventListener("change", () => {
      setSubtree(find(box.dataset.check), box.checked);
      render();
    });
  }
  for (const tw of document.querySelectorAll("#tree .twist:not(.leaf)")) {
    tw.addEventListener("click", () => {
      const path = tw.dataset.twist;
      shut.has(path) ? shut.delete(path) : shut.add(path);
      save("shut", [...shut]);
      render();
    });
  }
  for (const name of document.querySelectorAll("#tree .rname")) {
    name.addEventListener("click", () => gotoNode(name.dataset.open));
  }
  wire();
}

// Dragging the grip writes the width straight to the element; a full re-render
// per mousemove would rebuild a hundred and fifty rows thirty times a second.
(function () {
  const grip = document.getElementById("grip");
  const side = document.getElementById("side");
  let dragging = false;
  grip.addEventListener("mousedown", e => {
    e.preventDefault();
    dragging = true;
    grip.classList.add("dragging");
    document.body.classList.add("resizing");
  });
  addEventListener("mousemove", e => {
    if (!dragging) return;
    sideWidth = Math.max(180, Math.min(680, e.clientX - side.getBoundingClientRect().left));
    side.style.setProperty("--sidew", sideWidth + "px");
  });
  addEventListener("mouseup", () => {
    if (!dragging) return;
    dragging = false;
    grip.classList.remove("dragging");
    document.body.classList.remove("resizing");
    save("sidew", sideWidth);
  });
  // Double-click restores the default, so a drag to 680 is not a one-way door.
  grip.addEventListener("dblclick", () => {
    sideWidth = 264;
    save("sidew", sideWidth);
    render();
  });
})();

function toggleSide() {
  sideHidden = !sideHidden;
  save("side", sideHidden);
  render();
}
document.getElementById("hide").addEventListener("click", toggleSide);
document.getElementById("show").addEventListener("click", toggleSide);
document.getElementById("all").addEventListener("click", () => {
  off.clear();
  save("off", []);
  render();
});
document.getElementById("none").addEventListener("click", () => {
  off = new Set(board.cards.map(c => c.path));
  save("off", [...off]);
  render();
});
document.getElementById("collapse").addEventListener("click", () => {
  const all = branches(buildTree(board.cards));
  const anyOpen = all.some(b => !shut.has(b));
  shut = anyOpen ? new Set(all) : new Set();
  save("shut", [...shut]);
  render();
});

// ---- column menu ---------------------------------------------------------
function renderMenu() {
  const counts = countBy(board.cards.filter(matches), c => c.status);
  const known = board.statuses.slice();
  for (const c of board.cards) if (c.status && !known.includes(c.status)) known.push(c.status);
  const rows = known.concat([NO_STATUS]).map(s =>
    `<label><input type="checkbox" data-status="${esc(s)}" ${colOn(s) ? "checked" : ""}>
      <span class="swatch" style="--c:${cssVar(s)}"></span>${esc(label(s))}
      <span class="n">${counts.get(s) || 0}</span></label>`).join("");
  document.getElementById("colsmenu").innerHTML =
    `<h2>columns</h2>${rows}
     <div class="row"><button data-preset="flight">in flight</button>
       <button data-preset="all">all</button></div>`;

  for (const box of document.querySelectorAll("#colsmenu input")) {
    box.addEventListener("change", () => {
      cols[box.dataset.status] = box.checked;
      save("cols", cols);
      render();
    });
  }
  for (const b of document.querySelectorAll("#colsmenu [data-preset]")) {
    b.addEventListener("click", () => {
      cols = {};
      if (b.dataset.preset === "all")
        for (const s of known.concat([NO_STATUS])) cols[s] = true;
      save("cols", cols);
      render();
    });
  }
}

function toggleMenu(force) {
  const m = document.getElementById("colsmenu");
  const show = force === undefined ? m.hidden : force;
  m.hidden = !show;
  if (show) renderMenu();
}
document.getElementById("colsbtn").addEventListener("click", e => {
  e.stopPropagation();
  toggleMenu();
});
document.addEventListener("click", e => {
  if (!e.target.closest("#ctx")) closeCtx();
  if (!e.target.closest(".menuwrap")) toggleMenu(false);
  if (priMenu && !e.target.closest(".primenu") && !e.target.closest("[data-pri]")) {
    priMenu = null;
    render();
  }
});

// ---- project page --------------------------------------------------------
//
// One node, the whole window, as a grid of cards. The board stays the hub and
// this is where a node is actually read.
//
// It is a real URL under /node/, not a fragment, which is what makes it a page
// rather than a panel: back and forward work, it can be bookmarked, and it can
// be opened in a window of its own and left there.

const NODE_URL = p => "/node/" + p.split("/").map(encodeURIComponent).join("/");

function nodeFromUrl() {
  if (!location.pathname.startsWith("/node/")) return null;
  const rest = location.pathname.slice("/node/".length);
  if (!rest) return null;
  try { return rest.split("/").map(decodeURIComponent).join("/"); }
  catch (e) { return null; }
}

function gotoNode(path) {
  if (!path || path === detailPath) return;
  try { history.pushState(null, "", NODE_URL(path)); } catch (e) {}
  route();
}

function gotoBoard() {
  try { history.pushState(null, "", "/"); } catch (e) {}
  route();
}

// Everything that decides which of the two views is up, in one place, driven by
// the URL rather than by a flag. A click, the back button, a pasted link and a
// reload then all arrive the same way and cannot disagree.
function route() {
  const path = nodeFromUrl();
  const moved = path !== detailPath;
  detailPath = path;
  if (moved) { priMenu = null; closeCtx(); }
  document.getElementById("main").hidden = !!path;
  document.getElementById("project").hidden = !path;
  if (path) renderProject(moved); else render();
}

// The page is drawn from three things that arrive at different times: the card
// (already in the board poll), the node's own files, and whatever each link's
// service says about it. Each redraw uses what has landed so far, so the page
// is never blank waiting on `gh`.
let pNode = null, pLinks = null, pFor = null;

function renderProject(reload) {
  const path = detailPath;
  if (reload || pFor !== path) {
    pFor = path; pNode = null; pLinks = null;
    drawProject();
    loadProject(path);
    return;
  }
  drawProject();
}

async function loadProject(path) {
  try {
    const r = await fetch("/api/node?path=" + encodeURIComponent(path));
    const d = await r.json();
    if (d.error) throw new Error(d.error);
    if (detailPath !== path) return;
    pNode = d;
    drawProject();
  } catch (e) { fail(e.message); return; }
  try {
    const r = await fetch("/api/links?path=" + encodeURIComponent(path));
    const d = await r.json();
    if (detailPath !== path) return;
    pLinks = d.links || [];
  } catch (e) {
    if (detailPath !== path) return;
    pLinks = [];
  }
  drawProject();
}

function card(cls, head, body) {
  return `<section class="pcard ${cls}"><h3>${head}</h3>${body}</section>`;
}

function badge(tone, text) {
  return `<span class="pbadge ${esc(tone)}">${esc(text)}</span>`;
}

// ISO 8601 from a service, rendered the way the board renders its own ages, so
// "updated 2h ago" means the same thing everywhere on the page.
function isoAgo(iso) {
  if (!iso) return "";
  const t = Date.parse(iso);
  if (isNaN(t)) return "";
  return ago(Math.max(0, (Date.now() - t) / 1000)) + " ago";
}

const CHECK_MARK = {passed: "✓", failed: "✗", pending: "○"};

function linkCard(l) {
  // A glyph rather than the word "open": the card head is uppercased, so "OPEN"
  // sitting beside a `merged` badge read as the PR's state rather than a link.
  const out = `<a href="${esc(l.url)}" target="_blank" rel="noreferrer"
    title="${esc(l.url)}">\u2197</a>`;
  const head = k => `${esc(k)}<span class="grow"></span>${out}`;

  if (l.kind === "github-pr" || l.kind === "github-issue") {
    const what = l.kind === "github-pr" ? "pull" : "issue";
    const title = `${esc(l.repo)} <span class="sep">#</span>${l.number}`;
    if (l.error) {
      return card("", head("github " + what),
        `<div class="ptitle">${title}</div>
         <div class="pfail">${esc(l.error)}</div>`);
    }
    const d = l.data;
    if (!d) {
      return card("", head("github " + what),
        `<div class="ptitle">${title}</div><div class="pnote">reading…</div>`);
    }
    const checks = d.checks
      ? Object.entries(CHECK_MARK)
          .filter(([k]) => d.checks[k])
          .map(([k, m]) => `${m} ${d.checks[k]}`).join(" ")
      : "";
    const bits = [];
    if (checks) bits.push(`<span class="pmono">${esc(checks)}</span>`);
    if (d.review) bits.push(esc(d.review.toLowerCase().replace(/_/g, " ")));
    if (d.reviewers && d.reviewers.length) bits.push("to " + esc(d.reviewers.join(", ")));
    if (d.labels && d.labels.length) bits.push(esc(d.labels.join(", ")));
    if (d.assignees && d.assignees.length) bits.push(esc(d.assignees.join(", ")));
    if (d.adds != null) bits.push(`<span class="pmono">+${d.adds} −${d.dels}</span>`);
    if (d.files != null) bits.push(d.files + (d.files === 1 ? " file" : " files"));
    if (d.comments) bits.push(d.comments + (d.comments === 1 ? " comment" : " comments"));
    if (d.updated) bits.push(esc(isoAgo(d.updated)));
    return card("", head("github " + what), `
      <div class="ptitle">${badge(d.tone, d.stage)} ${esc(d.title || "")}</div>
      <div class="pmono">${title}${d.branch ? " · " + esc(d.branch) + " → " + esc(d.base) : ""}</div>
      <div class="prow">${bits.join('<span class="sep">·</span>')}</div>
      ${d.failing && d.failing.length
        ? `<div class="pfail">failing: ${esc(d.failing.join(", "))}</div>` : ""}`);
  }

  if (l.kind === "slack-thread" || l.kind === "slack-channel") {
    // slack:// reaches the desktop app instead of the browser. It is documented
    // for a channel and not for a message, so the thread link offers both and
    // says which is which rather than pretending one of them is exact.
    return card("", head("slack " + (l.kind === "slack-thread" ? "thread" : "channel")), `
      <div class="pmono">${esc(l.channel)}${l.ts ? " · " + esc(l.ts) : ""}</div>
      ${l.app_url ? `<div class="prow">
        <a href="${esc(l.app_url)}">open the channel in the app</a>
      </div>` : ""}
      <div class="pnote">the conversation itself is not rendered here yet</div>`);
  }

  if (l.kind === "linear-issue") {
    return card("", head("linear"), `
      <div class="ptitle">${esc(l.issue)}</div>
      <div class="pnote">issue state is not rendered here yet</div>`);
  }

  if (l.kind === "github-repo") {
    return card("", head("github repo"), `<div class="ptitle">${esc(l.repo)}</div>`);
  }

  return card("", head(esc(l.key)), `<div class="pmono">${esc(l.host)}</div>`);
}

function drawProject() {
  const path = detailPath;
  const c = (pNode && pNode.card) || (board && board.cards.find(x => x.path === path));
  const host = document.getElementById("project");
  if (!c) {
    host.innerHTML = `<div class="phead"><button class="pback" id="pback">${BACK} board</button>
      <h2>${esc(path || "")}</h2></div>
      <div class="pgrid">${card("", "reading", '<div class="pnote">…</div>')}</div>`;
    document.getElementById("pback").addEventListener("click", gotoBoard);
    return;
  }

  const links = pLinks !== null ? pLinks
    : Object.entries(c.links || {}).map(([k, v]) => ({key: k, url: v, kind: "other",
        host: v.replace(/^https?:\/\//, "").split("/")[0]}));

  const repos = (c.repos || []).map(esc).join("<br>");
  const notes = ((pNode && pNode.notes) || []).map(n =>
    `<span class="tag">${esc(n.replace(/\.md$/, ""))}</span>`).join("");
  const log = ((pNode && pNode.log) || []).map(l =>
    `<div class="logline">${md(l.replace(/^- /, "")).replace(/^<p>|<\/p>$/g, "")}</div>`).join("");

  host.innerHTML = `
    <div class="phead" style="--c:${cssVar(c.status)}">
      <button class="pback" id="pback">${BACK} board</button>
      <div class="trail mono">${esc(c.trail.join(" / ")) || "&nbsp;"}</div>
      <h2>${esc(c.slug)}</h2>
      <div class="statusline">
        <button class="pill" data-menu="${esc(c.path)}"
          title="move it, hide it, open its links">${esc(label(c.status))}${CARET}</button>
        <button class="dbtn ${c.tracked ? "on" : ""}" data-track="${esc(c.path)}"
          data-on="${c.tracked ? "0" : "1"}"
          >${c.tracked ? PIN_ON : PIN}${c.tracked ? "tracked" : "track"}</button>
        ${c.tracked ? `<button class="dbtn ${esc(c.priority || "")}" data-pri="${esc(c.path)}"
          >${BARS(PRI_LEVEL[c.priority] || 0)}${esc(c.priority || "no priority")}</button>` : ""}
      </div>
      ${priMenu === c.path ? `<div class="primenu" style="top:96px;left:20px">
        ${["high", "medium", "low"].map(k =>
          `<button data-set="${esc(c.path)}" data-level="${k}"
            style="color:var(--${k === "high" ? "blocked" : k === "medium" ? "in-progress" : "dim"})"
            >${BARS(PRI_LEVEL[k])}${k}</button>`).join("")}
        <button data-set="${esc(c.path)}" data-level="">${BARS(0)}none</button>
      </div>` : ""}
      <div class="factline">
        ${c.agent
          ? `<span class="agent${c.agent.state === "idle" ? " waits" : ""}">
               <span class="pulse"></span>${
                 c.agent.state === "idle" ? "waiting for you"
                 : c.agent.state === "busy" ? "working"
                 : "quiet"}${c.agent.state_seconds != null
                   ? ", " + ago(c.agent.state_seconds)
                   : c.agent.state ? "" : ", " + ago(c.agent.idle_seconds)}
               ${c.agent.name ? `<span class="when">${esc(c.agent.name)}</span>` : ""}</span>`
          : c.touched ? `<span class="when">touched ${ago(board.now - c.touched)} ago</span>` : ""}
        ${(c.agent && c.agent.desktop) || c.open
          ? `<button class="jump" data-pid="${c.agent && c.agent.desktop ? c.agent.pid : ""}"
               data-desk="${esc((c.agent && c.agent.desktop) || c.open)}"
               >jump to desktop ${esc((c.agent && c.agent.desktop) || c.open)}</button>`
          : ""}
      </div>
    </div>
    <div class="pgrid">
      ${links.map(linkCard).join("")}
      ${card("", "about", `
        ${c.description ? `<p>${esc(c.description)}</p>` : '<div class="pnote">no description</div>'}
        <dl class="kv">
          <dt>node</dt><dd>${esc(c.path)}</dd>
          ${repos ? `<dt>repos</dt><dd>${repos}</dd>` : ""}
          ${c.checkout ? `<dt>checkout</dt><dd>${esc(c.checkout)}</dd>` : ""}
          ${c.branch ? `<dt>branch</dt><dd>${esc(c.branch)}</dd>` : ""}
        </dl>`)}
      ${notes ? card("", "notes", `<div class="notes">${notes}</div>`) : ""}
      ${log ? card("pwide", "recent log", log) : ""}
      ${pNode && pNode.body ? card("pwide", "head", `<div class="prose">${md(pNode.body)}</div>`) : ""}
    </div>`;
  document.getElementById("pback").addEventListener("click", gotoBoard);
  wire();
}

// One implementation of each write, so the cards, the panel and the menu cannot
// drift apart.
async function trackNode(path, on, priority) {
  try {
    const body = { path, on };
    if (priority !== undefined) body.priority = priority;
    const r = await fetch("/api/track", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const d = await r.json();
    if (d.error) throw new Error(d.error);
    board = d.board;
    fail("");
    render();
    if (detailPath === path) drawProject();
  } catch (err) { fail(err.message); }
}


async function jumpTo(pid, desktop) {
  try {
    const r = await fetch("/api/desktop", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pid: pid ? Number(pid) : null,
                             desktop: desktop ? Number(desktop) : null }),
    });
    const d = await r.json();
    if (d.error) throw new Error(d.error);
    fail("");
  } catch (err) { fail(err.message); }
}

// ---- right-click menu ---------------------------------------------------
let ctxPath = null, ctxAt = [0, 0];

function closeCtx() {
  const el = document.getElementById("ctx");
  if (el) el.remove();
  ctxPath = null;
}

function openCtx(path, x, y) {
  closeCtx();
  const c = board.cards.find(k => k.path === path);
  if (!c) return;
  ctxPath = path;
  ctxAt = [x, y];
  const live = c.agent && !c.agent.stale;
  const hidden = off.has(path);
  const links = Object.entries(c.links || {}).slice(0, 6);

  const statuses = board.statuses.map(s =>
    `<button data-move="${esc(s)}" style="--c:${cssVar(s)}"
      aria-current="${s === c.status}">${esc(s)}</button>`).join("");
  const ranks = ["high", "medium", "low"].map(k =>
    `<button data-rank="${k}" style="--c:var(--${k === "high" ? "blocked"
      : k === "medium" ? "in-progress" : "dim"})"
      aria-current="${c.priority === k}">${k}</button>`).join("") +
    `<button data-rank="" style="--c:var(--line)"
      aria-current="${!c.priority}">none</button>`;

  document.body.insertAdjacentHTML("beforeend", `
    <div id="ctx">
      <div class="ctxhead"><b>${esc(c.slug)}</b><span>${esc(c.trail.join(" / ") || "projects")}</span></div>
      <button data-act="open">${PIN.replace(RIBBON, "M2 3h10v10H2z")}open detail</button>
      <button data-act="jump" ${(live && c.agent.desktop) || c.open ? "" : "disabled"}>
        <span class="${live ? "rlive" : ""}"></span>${
          live && c.agent.desktop ? "go to desktop " + esc(c.agent.desktop)
          : c.open ? "go to desktop " + esc(c.open)
          : live ? "session here, no window found"
          : "nothing open here"}</button>
      <hr>
      <div class="ctxlabel">move to</div>
      <div class="ctxrow">${statuses}</div>
      <hr>
      <button data-act="track">${c.tracked ? PIN_ON : PIN}${c.tracked ? "stop tracking" : "track"}</button>
      <div class="ctxlabel">priority${c.tracked ? "" : " (tracks it too)"}</div>
      <div class="ctxrow">${ranks}</div>
      <hr>
      <button data-act="hide">${hidden ? "show on the board" : "hide from the board"}</button>
      ${links.length ? `<hr>` + links.map(([k, v]) =>
        `<a class="ctxlink" href="${esc(v)}" target="_blank" rel="noreferrer">${esc(k)}</a>`).join("") : ""}
    </div>`);

  // Keep it on screen when the click lands near an edge.
  const el = document.getElementById("ctx");
  const r = el.getBoundingClientRect();
  el.style.left = Math.max(4, Math.min(x, innerWidth - r.width - 6)) + "px";
  el.style.top = Math.max(4, Math.min(y, innerHeight - r.height - 6)) + "px";

  el.addEventListener("click", async e => {
    const btn = e.target.closest("button");
    if (!btn) return;                       // a link closes on its own
    e.stopPropagation();
    const act = btn.dataset.act;
    const reopen = () => openCtx(path, ctxAt[0], ctxAt[1]);
    if (btn.dataset.move !== undefined) { closeCtx(); return move(path, btn.dataset.move); }
    if (btn.dataset.rank !== undefined) {
      return trackNode(path, true, btn.dataset.rank || null).then(reopen);
    }
    if (act === "track") return trackNode(path, !c.tracked).then(reopen);
    closeCtx();
    if (act === "open") return gotoNode(path);
    if (act === "jump")
      return jumpTo(c.agent && c.agent.desktop ? c.agent.pid : null,
                    (c.agent && c.agent.desktop) || c.open);
    if (act === "hide") {
      // The one node, never its children: this is the discoverable form of the
      // alt-click, and the answer to a grouping node like `cyvl` showing up as
      // a card in in-progress.
      hidden ? off.delete(path) : off.add(path);
      save("off", [...off]);
      render();
    }
  });
}

addEventListener("keydown", e => { if (e.key === "Escape") closeCtx(); }, true);
addEventListener("scroll", closeCtx, true);
addEventListener("resize", closeCtx);

// ---- drag, drop, and the write -------------------------------------------
function wire() {
  for (const b of document.querySelectorAll(".jump, .state.jumpable")) {
    b.addEventListener("click", e => {
      e.stopPropagation();
      jumpTo(b.dataset.pid, b.dataset.desk);
    });
  }
  for (const b of document.querySelectorAll("[data-track]")) {
    b.addEventListener("click", e => {
      e.stopPropagation();
      priMenu = null;
      trackNode(b.dataset.track, b.dataset.on === "1");
    });
  }
  const redraw = el => el.closest("#project") ? drawProject() : render();
  for (const b of document.querySelectorAll("[data-pri]")) {
    b.addEventListener("click", e => {
      e.stopPropagation();
      priMenu = priMenu === b.dataset.pri ? null : b.dataset.pri;
      redraw(b);
    });
  }
  for (const b of document.querySelectorAll("[data-set]")) {
    b.addEventListener("click", e => {
      e.stopPropagation();
      priMenu = null;
      trackNode(b.dataset.set, true, b.dataset.level || null);
    });
  }
  for (const card of document.querySelectorAll(".card")) {
    card.addEventListener("click", () => gotoNode(card.dataset.path));
    card.addEventListener("contextmenu", e => {
      e.preventDefault();
      openCtx(card.dataset.path, e.clientX, e.clientY);
    });
    card.addEventListener("dragstart", e => {
      dragging = card.dataset.path;
      hold();
      card.classList.add("dragging");
      e.dataTransfer.effectAllowed = "move";
    });
    card.addEventListener("dragend", () => {
      card.classList.remove("dragging");
      dragging = null;
      release();
    });
  }
  // The same menu on a tree row, so an action does not depend on finding the
  // card first -- which is the whole problem with a node hidden from the board.
  for (const row of document.querySelectorAll("#tree .row")) {
    row.addEventListener("contextmenu", e => {
      e.preventDefault();
      openCtx(row.dataset.path, e.clientX, e.clientY);
    });
  }
  for (const b of document.querySelectorAll("[data-menu]")) {
    b.addEventListener("click", e => {
      e.stopPropagation();
      const r = b.getBoundingClientRect();
      openCtx(b.dataset.menu, r.left, r.bottom + 4);
    });
  }
  const head = document.querySelector("#project .phead");
  if (head) {
    head.addEventListener("contextmenu", e => {
      e.preventDefault();
      openCtx(detailPath, e.clientX, e.clientY);
    });
  }
  for (const col of document.querySelectorAll(".col")) {
    col.addEventListener("dragover", e => {
      if (!dragging) return;
      e.preventDefault();
      col.classList.add("over");
    });
    col.addEventListener("dragleave", () => col.classList.remove("over"));
    col.addEventListener("drop", e => {
      e.preventDefault();
      col.classList.remove("over");
      const status = col.dataset.status, path = dragging;
      dragging = null;
      release();
      if (!path) return;
      if (!status) {
        // The untriaged column is a source, not a destination: the vault has no
        // word for "un-set a status", so saying so beats a silent no-op.
        fail("untriaged is where nodes start, not somewhere to put one back");
        setTimeout(() => fail(""), 4000);
        return;
      }
      move(path, status);
    });
  }
}

function fail(msg) {
  const e = document.getElementById("err");
  e.style.display = msg ? "block" : "none";
  e.textContent = msg || "";
}

async function move(path, status) {
  const card = board.cards.find(c => c.path === path);
  if (!card || card.status === status) return;
  card.status = status;               // optimistic, so the drop feels instant
  render();
  try {
    const r = await fetch("/api/status", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ path, status }),
    });
    const data = await r.json();
    if (data.error) throw new Error(data.error);
    board = data.board;
    fail("");
  } catch (e) {
    fail(e.message);
  }
  render();
  if (detailPath === path) drawProject();
}

async function refresh() {
  if (Date.now() < holdUntil) return;
  try {
    const r = await fetch("/api/board");
    const data = await r.json();
    if (data.error) throw new Error(data.error);
    board = data;
    fail("");
    // The poll is what keeps a card's agent state and status live, and the
    // project page shows the same facts, so it redraws on the poll too rather
    // than going stale the moment it is opened.
    if (detailPath) drawProject();
    else if (signature(board) === rendered) tick();
    else render();
  } catch (e) {
    fail(e.message);
  }
}

// ---- input ---------------------------------------------------------------
const q = document.getElementById("q");
q.addEventListener("input", () => {
  query = q.value.trim().toLowerCase();
  render();
});

addEventListener("keydown", e => {
  if (e.key === "Escape") {
    if (detailPath) return gotoBoard();
    if (!document.getElementById("colsmenu").hidden) return toggleMenu(false);
    if (priMenu) { priMenu = null; return render(); }
    if (onlyTracked) { onlyTracked = false; save("trackedonly", false); return render(); }
    if (within) { within = 0; save("within", 0); return render(); }
    if (onlyLive) { onlyLive = false; return render(); }
    if (query) { q.value = ""; query = ""; return render(); }
    if (off.size) { off.clear(); save("off", []); return render(); }
    return;
  }
  if (e.target === q || e.metaKey || e.ctrlKey || e.altKey) return;
  if (e.key === "/") { e.preventDefault(); q.focus(); q.select(); }
  if (e.key === "r") refresh();
  if (e.key === "c") toggleMenu();
  if (e.key === "b") toggleSide();
});

// The page was addressed by a #node= fragment before it was a page of its own.
// Those links are in the vault and in Kai's tabs, so they still work: the hash
// is swapped for the path once and then forgotten about.
function fromHash() {
  const m = /^#node=(.+)$/.exec(location.hash);
  if (!m) return;
  try {
    history.replaceState(null, "", NODE_URL(decodeURIComponent(m[1])));
  } catch (e) {}
}
addEventListener("hashchange", () => { fromHash(); route(); });
addEventListener("popstate", route);
fromHash();
refresh().then(route);
setInterval(refresh, 2000);
</script>
</body>
</html>
"""


if __name__ == "__main__":
    main()
