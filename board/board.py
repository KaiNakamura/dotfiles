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


# Trailing markdown that a URL picks up when it is written into prose rather
# than into a frontmatter value: `pull/690**`, `pull/690,`, `pull/690).`
URL_IN_PROSE = re.compile(r'https?://[^\s)\]>"\'`]+')
URL_TAIL = re.compile(r'[*,.;:)\]}>]+$')


def node_urls(vault, node_path):
    """Every link the node names anywhere, not only in its frontmatter.

    `links:` is curated and most nodes never get around to filling it in: 57 of
    165 have one, while 74 name a GitHub, Slack or Linear URL somewhere in their
    files. A node whose PR is mentioned in a note and not in its head is the
    common case, not the exception, so the page reads the whole node.
    """
    found = []
    try:
        names = sorted(n for n in os.listdir(os.path.join(vault, node_path))
                       if n.endswith(".md"))
    except OSError:
        return found
    for name in names:
        try:
            with open(os.path.join(vault, node_path, name), encoding="utf-8") as fh:
                text = fh.read()
        except OSError:
            continue
        for url in URL_IN_PROSE.findall(text):
            url = URL_TAIL.sub("", url)
            if any(h in url for h in ("github.com", "slack.com", "linear.app")):
                found.append(url)
    return found


def link_identity(card):
    """What makes two links the same thing.

    The URL is the wrong key. One node cites the same PR three times with three
    different bits of markdown stuck to the end, and a Slack thread is linked
    once by its parent and once by a reply, which are different permalinks to
    the same conversation.
    """
    if card["kind"] in ("github-pr", "github-issue"):
        return (card["kind"], card["repo"], card["number"])
    if card["kind"] == "slack-thread":
        return ("slack", card["channel"], card["ts"])
    if card["kind"] == "slack-channel":
        return ("slack", card["channel"], None)
    if card["kind"] == "linear-issue":
        return ("linear", card["issue"])
    return ("url", card["url"])


def node_link_cards(vault, card):
    """The node's links, curated first and then whatever its prose mentions.

    A frontmatter link keeps its key as a label and wins any tie, because
    someone chose to put it there.
    """
    out, seen = [], set()
    for key, url in (card.get("links") or {}).items():
        c = classify_link(key, url)
        ident = link_identity(c)
        if ident in seen:
            continue
        seen.add(ident)
        out.append(c)
    for url in node_urls(vault, card["path"]):
        c = classify_link("", url)
        ident = link_identity(c)
        if ident in seen:
            continue
        seen.add(ident)
        c["found"] = True
        out.append(c)
    return out


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


# --------------------------------------------------------------------------
# Slack
#
# The board holds no Slack credential of its own and cannot get one: the Slack
# connector Claude uses is an OAuth grant held at mcp.slack.com, and nothing on
# this machine carries a token. So the page reads whatever is put in
# SLACK_CONF, and says what is missing when there is nothing there.
#
# Two kinds of token work. A `xoxp-`/`xoxb-` token from a workspace app stands
# on its own. A `xoxc-` token is the one the desktop app already holds, and it
# is only accepted alongside the `d` cookie that was issued with it.

SLACK_CONF = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "board", "slack.json")
SLACK_API = "https://slack.com/api/"
SLACK_SECONDS = 25        # how long a fetched thread is reused
_slack_users = {}


def slack_creds():
    """The Slack token and cookie, or None.

    Two places, so a new machine has a quick path and a durable one. The
    environment wins -- `BOARD_SLACK_TOKEN` (and `BOARD_SLACK_COOKIE` for an
    xoxc token) in a shell rc is the one-line way to bring a laptop up -- and
    the file at SLACK_CONF is the standing config. Both are read on every call,
    so dropping either in place needs no restart.
    """
    token = (os.environ.get("BOARD_SLACK_TOKEN") or "").strip()
    cookie = (os.environ.get("BOARD_SLACK_COOKIE") or "").strip()
    if not token:
        try:
            with open(SLACK_CONF, encoding="utf-8") as fh:
                conf = json.load(fh)
            token = (conf.get("token") or "").strip()
            cookie = (conf.get("cookie") or "").strip()
        except (OSError, ValueError):
            return None
    if not token:
        return None
    if token.startswith("xoxc-") and not cookie:
        return None
    return {"token": token, "cookie": cookie}


def slack_call(method, params, creds):
    """One Slack Web API call, as the signed-in user.

    urllib rather than a client library, because the board has no dependencies
    and this is two calls with four parameters between them.
    """
    import urllib.request
    data = urllib.parse.urlencode(params).encode()
    req = urllib.request.Request(SLACK_API + method, data=data)
    req.add_header("Authorization", "Bearer " + creds["token"])
    req.add_header("Content-Type",
                   "application/x-www-form-urlencoded; charset=utf-8")
    if creds["cookie"]:
        req.add_header("Cookie", "d=" + urllib.parse.quote(creds["cookie"], safe=""))
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            body = json.loads(r.read().decode("utf-8"))
    except Exception as e:
        raise RuntimeError(str(e))
    if not body.get("ok"):
        raise RuntimeError(body.get("error") or "slack said no")
    return body


def slack_who(user_id, creds):
    """A {name, avatar} for a user id, remembered for the life of the process.

    Every message in a thread carries an id and no name, and a thread of twenty
    messages is usually three people, so this is the difference between three
    calls and twenty. The avatar is Slack's own `image_48`, a public CDN URL
    that loads in the page without the session token.
    """
    if not user_id:
        return {"name": "someone", "avatar": ""}
    if user_id in _slack_users:
        return _slack_users[user_id]
    who = {"name": user_id, "avatar": ""}
    try:
        u = slack_call("users.info", {"user": user_id}, creds)["user"]
        p = u.get("profile") or {}
        who["name"] = (p.get("display_name") or p.get("real_name")
                       or u.get("real_name") or u.get("name") or user_id)
        who["avatar"] = p.get("image_48") or p.get("image_72") or ""
    except RuntimeError:
        pass
    _slack_users[user_id] = who
    return who


def slack_thread(channel, ts, creds):
    """A thread as a list of messages, oldest first.

    `conversations.replies` returns the parent as the first element, which is
    why nothing here special-cases it.
    """
    body = slack_call("conversations.replies",
                      {"channel": channel, "ts": ts, "limit": 100}, creds)
    out = []
    for m in body.get("messages") or []:
        text = m.get("text") or ""
        # A bot posting blocks leaves `text` empty and the words in attachments.
        # Firewatch alerts are exactly that shape, so a thread of them would
        # otherwise render as a column of blank messages.
        if not text.strip():
            bits = []
            for a in (m.get("attachments") or []):
                bits.append(a.get("fallback") or a.get("text") or a.get("title") or "")
            for b in (m.get("blocks") or []):
                t = (b.get("text") or {}).get("text")
                if t:
                    bits.append(t)
            text = "\n".join(x for x in bits if x)
        if m.get("username"):
            who = {"name": m["username"], "avatar": m.get("icons", {}).get("image_48", "")}
        else:
            who = slack_who(m.get("user") or m.get("bot_id"), creds)
        out.append({
            "ts": m.get("ts"), "who": who["name"], "avatar": who["avatar"],
            "text": text, "files": len(m.get("files") or []),
            "reactions": [{"name": r.get("name"), "count": r.get("count", 0)}
                          for r in (m.get("reactions") or [])],
        })
    return {"messages": out, "channel": channel}


class SlackThreads:
    """Threads, cached like link cards and for the same reason."""

    def __init__(self):
        self.lock = threading.Lock()
        self.by_key = {}

    def get(self, channel, ts, force=False):
        creds = slack_creds()
        if not creds:
            return {"error": "no-creds", "conf": SLACK_CONF,
                    "env": "BOARD_SLACK_TOKEN"}
        key = (channel, ts)
        now = time.time()
        with self.lock:
            hit = self.by_key.get(key)
            if hit and not force and now - hit["at"] < SLACK_SECONDS:
                return hit["data"]
        try:
            data = slack_thread(channel, ts, creds)
        except RuntimeError as e:
            data = {"error": str(e)}
        with self.lock:
            self.by_key[key] = {"at": time.time(), "data": data}
        return data

    def drop(self, channel, ts):
        with self.lock:
            self.by_key.pop((channel, ts), None)


THREADS = SlackThreads()


def slack_reply(channel, ts, text):
    """Post a reply into a thread and hand back its permalink.

    The permalink is the point. Replying in the browser means finding the new
    message, opening its menu and copying its link before it can be given to an
    agent; `chat.postMessage` returns the ts it just created, so the link is
    known without going and looking for it.
    """
    creds = slack_creds()
    if not creds:
        raise RuntimeError("no Slack token configured at " + SLACK_CONF)
    body = slack_call("chat.postMessage",
                      {"channel": channel, "thread_ts": ts, "text": text}, creds)
    new_ts = body.get("ts") or ""
    link = ""
    try:
        link = slack_call("chat.getPermalink",
                          {"channel": channel, "message_ts": new_ts},
                          creds).get("permalink") or ""
    except RuntimeError:
        pass
    THREADS.drop(channel, ts)
    return {"ts": new_ts, "permalink": link}


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
                "statusCheckRollup,reviewRequests,updatedAt,createdAt,additions,"
                "deletions,changedFiles,headRefName,baseRefName,comments,reviews,"
                "author,body,url")


EVENT_BODY_CAP = 900   # per comment/review; agents post very long ones


def is_bot(login):
    return bool(re.search(r"(\[bot\]$|-bot$|^github-actions$|^linear$|^codecov)",
                          login or "", re.I))


def clip_body(body):
    """A body capped so one long agent reply cannot dominate the payload.

    The card is a glance; the full text is a click away on GitHub. The cap is on
    characters and falls on a line boundary so a code block is not sliced mid-
    token.
    """
    body = body or ""
    if len(body) <= EVENT_BODY_CAP:
        return body, False
    cut = body.rfind("\n", 0, EVENT_BODY_CAP)
    return body[:cut if cut > 400 else EVENT_BODY_CAP], True


def gh_timeline(pr):
    """The PR's conversation as one list, oldest first.

    GitHub keeps issue comments and reviews in separate arrays; they are
    interleaved here by time. A review with no body and the COMMENTED state is
    dropped: it is the empty envelope GitHub makes to hold inline code comments,
    and rendering it claims a review that did not happen. An APPROVED or
    CHANGES_REQUESTED review is kept even empty, because the act is the content.
    Each event is tagged bot/human and its body is clipped, so the page can lead
    with what people said and keep the machine noise short.
    """
    events = []
    for c in pr.get("comments") or []:
        who = (c.get("author") or {}).get("login") or "someone"
        body, clipped = clip_body(c.get("body"))
        events.append({
            "kind": "comment", "who": who, "bot": is_bot(who),
            "assoc": c.get("authorAssociation"), "body": body,
            "clipped": clipped, "at": c.get("createdAt"),
        })
    for r in pr.get("reviews") or []:
        state = (r.get("state") or "").upper()
        raw = r.get("body") or ""
        if state in ("COMMENTED", "") and not raw.strip():
            continue
        who = (r.get("author") or {}).get("login") or "someone"
        body, clipped = clip_body(raw)
        events.append({
            "kind": "review", "state": state, "who": who, "bot": is_bot(who),
            "assoc": r.get("authorAssociation"), "body": body,
            "clipped": clipped, "at": r.get("submittedAt"),
        })
    events.sort(key=lambda e: e.get("at") or "")
    return events


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


def pr_situation(pr, stage):
    """Whose move it is, on what, and since when -- the one thing to read first.

    `stage` already says what state the PR is in; this turns that into the
    question actually being asked of a PR list: is the ball in my court or
    theirs, and how long has it sat there. `court` is "mine", "theirs" or
    "done"; `since` is the moment the ball last moved, so the card can say how
    long the wait has run.
    """
    reviews = pr.get("reviews") or []

    def last(state):
        hit = [r for r in reviews if (r.get("state") or "").upper() == state]
        return hit[-1] if hit else None

    requested = [r.get("login") or r.get("name") or r.get("slug") or "?"
                 for r in pr.get("reviewRequests") or []]
    opened, updated = pr.get("createdAt"), pr.get("updatedAt")

    if stage == "merged":
        return {"court": "done", "verb": "merged", "who": "", "since": updated}
    if stage == "closed":
        return {"court": "done", "verb": "closed", "who": "", "since": updated}
    if stage == "draft":
        return {"court": "mine", "verb": "not sent for review yet",
                "who": "", "since": opened}
    if stage == "CI failing":
        return {"court": "mine", "verb": "CI failing, your move",
                "who": "", "since": updated}
    if stage == "CI running":
        return {"court": "theirs", "verb": "CI running", "who": "", "since": updated}
    if stage == "changes requested":
        r = last("CHANGES_REQUESTED")
        return {"court": "mine", "verb": "changes requested, your move",
                "who": (r or {}).get("author", {}).get("login") if r else "",
                "since": (r or {}).get("submittedAt") or updated}
    if stage in ("approved, ready to merge", "approved, conflicts"):
        r = last("APPROVED")
        return {"court": "mine",
                "verb": "approved, ready to merge" if stage.endswith("merge")
                        else "approved, but has conflicts",
                "who": (r or {}).get("author", {}).get("login") if r else "",
                "since": (r or {}).get("submittedAt") or updated}
    if stage == "awaiting review":
        # The ball moved to them at the last thing you did; the closest stamp to
        # that without the events API is the last update.
        return {"court": "theirs", "verb": "waiting on review",
                "who": ", ".join(requested), "since": updated}
    if stage == "conflicts":
        return {"court": "mine", "verb": "conflicts to resolve", "who": "", "since": updated}
    return {"court": "mine", "verb": "no reviewer yet, request one",
            "who": "", "since": opened}


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
        "opened": pr.get("createdAt"),
        "author": (pr.get("author") or {}).get("login"),
        "body": pr.get("body") or "",
        "branch": pr.get("headRefName"), "base": pr.get("baseRefName"),
        "adds": pr.get("additions"), "dels": pr.get("deletions"),
        "files": pr.get("changedFiles"), "comments": len(pr.get("comments") or []),
        "timeline": gh_timeline(pr),
        "checks": checks, "failing": failing, "reviewers": reviewers,
        "stage": stage, "tone": STAGE_TONE.get(stage, "mute"),
        "situation": pr_situation(pr, stage),
    }


def fetch_github_issue(card):
    it = gh_json(["issue", "view", str(card["number"]), "--repo", card["repo"],
                  "--json", "number,title,state,createdAt,updatedAt,labels,"
                  "assignees,comments,author,body"])
    stage = "closed" if it.get("state") == "CLOSED" else "open"
    events = [{
        "kind": "comment",
        "who": (c.get("author") or {}).get("login") or "someone",
        "assoc": c.get("authorAssociation"), "body": c.get("body") or "",
        "at": c.get("createdAt"),
    } for c in it.get("comments") or []]
    return {
        "title": it.get("title"), "state": it.get("state"),
        "updated": it.get("updatedAt"), "opened": it.get("createdAt"),
        "author": (it.get("author") or {}).get("login"),
        "body": it.get("body") or "",
        "labels": [l.get("name") for l in it.get("labels") or []][:6],
        "assignees": [a.get("login") for a in it.get("assignees") or []],
        "comments": len(it.get("comments") or []), "timeline": events,
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
        elif self.path.startswith("/api/slack"):
            query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            self._json(THREADS.get((query.get("channel") or [""])[0],
                                   (query.get("ts") or [""])[0],
                                   force=bool(query.get("force"))))
        elif self.path.startswith("/api/links"):
            query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            try:
                card = find_node(self.cache.get(), (query.get("path") or [""])[0])
            except (ValueError, RuntimeError) as e:
                self._json({"error": str(e)}, 404)
                return
            cards = node_link_cards(self.cache.vault, card)
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
                or self.path.startswith("/api/track")
                or self.path.startswith("/api/reply")
                or self.path.startswith("/api/comment")):
            self._json({"error": "not found"}, 404)
            return
        length = int(self.headers.get("Content-Length", 0))
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            self._json({"error": "bad json"}, 400)
            return
        if self.path.startswith("/api/reply"):
            try:
                self._json(slack_reply(body.get("channel") or "",
                                       body.get("ts") or "",
                                       body.get("text") or ""))
            except RuntimeError as e:
                self._json({"error": str(e)}, 400)
            return
        if self.path.startswith("/api/comment"):
            # `gh` writes the comment, for the same reason it reads the PR: the
            # token is already where gh keeps it and there is no second copy.
            try:
                run(["gh", ("pr" if body.get("kind") == "github-pr" else "issue"),
                     "comment", str(body.get("number")), "--repo",
                     body.get("repo") or "", "--body", body.get("text") or ""],
                    timeout=25)
            except (RuntimeError, OSError) as e:
                self._json({"error": str(e)}, 400)
                return
            LINKS.by_url.pop(body.get("url"), None)
            self._json({"ok": True})
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


SLACK_AUTH_HELP = """\
Connect Slack so the board can show and reply to threads. It reads the API as
you; there is no board-owned Slack app, so it needs one of your own tokens.

Two ways to get one:

  A. Durable, works on every machine (recommended). Make a user token once:
       1. https://api.slack.com/apps  ->  Create New App  ->  From scratch
       2. OAuth & Permissions -> User Token Scopes -> add:
            channels:history  groups:history  im:history  mpim:history
            channels:read  users:read  chat:write
       3. Install to Workspace, approve, copy the "User OAuth Token" (xoxp-...)
       4. board slack-auth xoxp-your-token

  B. Fastest, this machine only. Borrow the desktop app's own session:
       token:  open Slack, Help -> Troubleshooting -> Open Console, paste:
                 JSON.parse(localStorage.localConfig_v2).teams[
                   Object.keys(JSON.parse(localStorage.localConfig_v2).teams)[0]].token
               (copy the xoxc-... it prints)
       cookie: DevTools -> Application -> Cookies -> https://app.slack.com
               -> the row named `d`, copy its value (xoxd-...)
       then:   board slack-auth xoxc-your-token xoxd-your-cookie

The token is written to %s. To carry it between machines instead, export
BOARD_SLACK_TOKEN (and BOARD_SLACK_COOKIE for an xoxc token) in your shell.
""" % SLACK_CONF


def cmd_slack_auth(args, vault):
    if not args.token:
        print(SLACK_AUTH_HELP)
        return
    token = args.token.strip()
    cookie = (args.cookie or "").strip()
    if token.startswith("xoxc-") and not cookie:
        raise RuntimeError("an xoxc- token needs its xoxd- cookie as the second "
                           "argument; run `board slack-auth` for how to get it")
    # Verify before writing, so a wrong paste fails here with Slack's own reason
    # rather than silently on the card later.
    who = slack_call("auth.test", {}, {"token": token, "cookie": cookie})
    os.makedirs(os.path.dirname(SLACK_CONF), exist_ok=True)
    tmp = SLACK_CONF + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump({"token": token, "cookie": cookie}, fh, indent=2)
    os.chmod(tmp, 0o600)          # it is a credential; keep it to the owner
    os.replace(tmp, SLACK_CONF)
    print("Connected as %s in %s. Written to %s"
          % (who.get("user"), who.get("team"), SLACK_CONF))


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

    s = sub.add_parser("slack-auth", help="connect Slack (run bare for how)")
    s.add_argument("token", nargs="?", help="xoxp- or xoxc- token")
    s.add_argument("cookie", nargs="?", help="xoxd- cookie, for an xoxc- token")
    s.set_defaults(fn=cmd_slack_auth)

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
     Everything here is prefixed `p` (or `s` for the Slack thread, `pr`/`c` for
     the pull request): class collisions in this stylesheet have already cost a
     round of screenshots each, so the page keeps its own namespace.

     A fixed viewport with one scroll region, so the header stays put and the
     cards below it scroll as a body. */
  #project {
    height: calc(100vh - 92px); display: flex; flex-direction: column;
    background: var(--bg); overflow: hidden;
  }
  .phead { padding: 9px 18px 11px; border-bottom: 1px solid var(--line);
           background: var(--panel); flex: none; position: relative; }
  .pline { display: flex; align-items: center; gap: 9px; }
  .ptop { margin-top: 5px; flex-wrap: wrap; }
  .phead h2 { margin: 0; font-size: 17px; }
  .pdesc {
    margin: 0; color: var(--dim); font-size: 12.5px; line-height: 1.4;
    flex: 1 1 340px; min-width: 240px; border-left: 2px solid var(--c, var(--line));
    padding-left: 10px;
  }
  .pback { display: inline-flex; align-items: center; gap: 5px; font-size: 12px; flex: none; }
  .pback svg { width: 10px; height: 10px; }
  .phead .grow { flex: 1; }
  .phead .agent, .phead .when { font-size: 12px; white-space: nowrap; }
  .phead .jump { font-size: 12px; padding: 1px 7px; }

  /* A flex column, so the big grid takes the height that is going and the chip
     row sits under it rather than the page ending halfway down. */
  .pscroll {
    flex: 1; overflow-y: auto; padding: 14px 18px 18px;
    display: flex; flex-direction: column; gap: 14px;
  }
  .pquiet { color: var(--faint); font-size: 13px; padding: 8px 2px; }

  /* The big tier: threads and pull requests. It grows to fill the space left
     over, and its rows stretch with it, so one PR fills the window and four
     share it -- the layout answers to how many cards there are instead of
     leaving a fixed card stranded in an empty page. Each row is at least tall
     enough to be worth reading. */
  .pgrid {
    flex: 1 0 auto; min-height: 0; display: grid; gap: 14px;
    grid-template-columns: repeat(auto-fit, minmax(460px, 1fr));
    grid-auto-rows: minmax(340px, 1fr); align-content: stretch;
  }
  /* The chip tier: everything that is just a link, packed tight, natural height
     at the foot. */
  .pmini {
    flex: none; display: grid; gap: 10px;
    grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  }

  .pcard {
    background: var(--card); border: 1px solid var(--line); border-radius: 10px;
    display: flex; flex-direction: column; overflow: hidden; min-width: 0;
  }
  /* A conversation card fills its grid cell and scrolls its own body, so a
     40-message thread and a 2-message one are the same size and each is as tall
     as the row the grid gave it. */
  .pcard.tall { height: 100%; min-height: 0; }
  .pmini .pcard { min-height: 92px; }

  .pcard > h3 {
    flex: none; display: flex; align-items: center; gap: 8px;
    font-size: 11px; font-weight: 600; color: var(--faint);
    letter-spacing: .04em; margin: 0; padding: 9px 12px;
    border-bottom: 1px solid var(--line); background: var(--panel);
  }
  .pcard > h3 .pk { color: var(--dim); font-family: ui-monospace, monospace;
                    text-transform: none; letter-spacing: 0; }
  .pcard > h3 .grow { flex: 1; }
  /* The open-in link, given room and a hit target rather than a 10px glyph in
     the corner. */
  .popen {
    color: var(--accent); font-weight: 600; white-space: nowrap;
    padding: 2px 8px; border: 1px solid var(--line); border-radius: 6px;
  }
  .popen:hover { border-color: var(--accent); }
  .pbody { flex: 1; overflow-y: auto; padding: 11px 13px; min-height: 0; }
  .pfoot {
    flex: none; border-top: 1px solid var(--line); padding: 8px 10px;
    display: flex; flex-direction: column; gap: 6px; background: var(--panel);
  }
  .pfootrow { display: flex; gap: 10px; }
  .linkish {
    background: none; border: none; color: var(--accent); font: inherit;
    font-size: 11.5px; padding: 0; cursor: pointer;
  }

  .pcard p { margin: 0 0 7px; color: var(--dim); overflow-wrap: anywhere; }
  .pempty { color: var(--faint); font-size: 13px; }
  .pempty p { color: inherit; margin-bottom: 8px; }
  .pslackempty { padding: 4px 2px; }
  .pslackempty pre {
    background: var(--bg); border: 1px solid var(--line); border-radius: 6px;
    padding: 8px 10px; margin: 4px 0 10px; font-size: 11.5px; overflow-x: auto;
    color: var(--dim); font-family: ui-monospace, monospace;
  }
  .pconnrow { color: var(--ink); margin-bottom: 5px; }
  /* A code block with the copy control inside it, top-right, the way a docs
     snippet reads: the command fills the block, the button sits over it. */
  .pcopy {
    position: relative; margin: 4px 0 12px; background: var(--bg);
    border: 1px solid var(--line); border-radius: 7px; padding: 10px 40px 10px 12px;
  }
  .pcopy code {
    font-family: ui-monospace, monospace; font-size: 12.5px; color: var(--ink);
    overflow-wrap: anywhere;
  }
  .pcopybtn {
    position: absolute; top: 6px; right: 6px; display: inline-flex;
    align-items: center; justify-content: center; width: 26px; height: 26px;
    background: none; border: 1px solid var(--line); border-radius: 6px;
    color: var(--faint); cursor: pointer; padding: 0;
  }
  .pcopybtn:hover { color: var(--ink); border-color: var(--accent); background: var(--panel); }
  .pcopybtn.ok { color: var(--in-review); border-color: var(--in-review); }
  .pcopybtn svg { width: 14px; height: 14px; }
  .ptitle {
    font-size: 13.5px; color: var(--ink); margin: 0 0 6px; line-height: 1.4;
    overflow-wrap: anywhere;
  }
  .pfound {
    color: var(--faint); font-weight: 400; letter-spacing: 0; font-size: 10px;
    font-style: italic;
  }
  .pdim { color: var(--faint); font-weight: 400; }
  .pmono {
    font-family: ui-monospace, monospace; font-size: 11.5px; color: var(--faint);
    overflow-wrap: anywhere;
  }
  .sep { color: var(--line); margin: 0 2px; }
  .pbody a, .pfoot a { color: var(--accent); }
  .pfail {
    margin-top: 6px; font-size: 11.5px; color: var(--blocked);
    font-family: ui-monospace, monospace; white-space: pre-wrap;
    overflow-wrap: anywhere;
  }

  /* An avatar: the service's own image over a coloured initial, so it reads
     even before the image loads and if it never does. */
  .pav {
    flex: none; width: 26px; height: 26px; border-radius: 50%; position: relative;
    display: inline-flex; align-items: center; justify-content: center;
    font-size: 12px; font-weight: 600; color: #fff; overflow: hidden;
    background: hsl(var(--h, 210), 45%, 45%);
  }
  .pav img {
    position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover;
    opacity: 0; transition: opacity .15s;
  }

  .pbadge {
    display: inline-flex; align-items: center; font-size: 11px;
    font-weight: 600; border-radius: 999px; padding: 1px 9px;
    border: 1px solid color-mix(in srgb, var(--t) 45%, transparent);
    background: color-mix(in srgb, var(--t) 14%, transparent); color: var(--t);
    white-space: nowrap; flex: none;
  }
  .pbadge.good { --t: var(--in-review); }
  .pbadge.warn { --t: var(--in-progress); }
  .pbadge.bad  { --t: var(--blocked); }
  .pbadge.mute { --t: var(--faint); }

  /* Pull request: state first, then description, then the conversation behind a
     toggle -- the card answers "whose move, how long" before anything else. */
  .prhead { border-bottom: 1px solid var(--line); padding-bottom: 11px; }
  .prtitle { display: flex; align-items: baseline; gap: 8px; }
  .prtitle span { font-size: 15px; font-weight: 600; color: var(--ink);
                  line-height: 1.35; overflow-wrap: anywhere; }
  /* The court-and-clock banner. Its tint is the whole point: mine is a nudge,
     theirs is a neutral wait, done is settled. */
  .psit {
    display: flex; align-items: center; gap: 8px; margin-top: 9px;
    font-size: 12.5px; border-radius: 7px; padding: 6px 10px;
    border: 1px solid color-mix(in srgb, var(--t) 40%, transparent);
    background: color-mix(in srgb, var(--t) 12%, transparent);
  }
  .psit.warn { --t: var(--in-progress); }
  .psit.mute { --t: var(--faint); }
  .psit.good { --t: var(--in-review); }
  .psitdot { width: 8px; height: 8px; border-radius: 50%; background: var(--t); flex: none; }
  .psitverb { font-weight: 600; color: var(--ink); }
  .psitwho { color: var(--dim); }
  .psitcourt { color: var(--t); font-weight: 600; text-transform: lowercase; }
  .psitdur { color: var(--dim); font-family: ui-monospace, monospace;
             font-size: 11.5px; }
  .prmeta { font-size: 12px; color: var(--dim); margin-top: 8px;
            display: flex; flex-wrap: wrap; align-items: center; gap: 3px 2px; }
  .prdesc {
    font-size: 12.5px; color: var(--dim); line-height: 1.5; padding: 11px 0 3px;
    overflow-wrap: anywhere;
  }
  .prdesc > :first-child { margin-top: 0; }
  .prdesc pre { background: var(--panel); border: 1px solid var(--line);
                border-radius: 5px; padding: 6px 8px; overflow-x: auto; font-size: 11.5px; }
  .prdesc code { font-family: ui-monospace, monospace; font-size: .92em; }
  .prdesc ul { margin: 4px 0; padding-left: 18px; }
  /* The one control that shows or hides the thread. */
  .pconvtoggle {
    display: flex; align-items: center; gap: 6px; width: 100%;
    background: none; border: none; border-top: 1px solid var(--line);
    padding: 9px 0 2px; margin-top: 4px; color: var(--dim); font: inherit;
    font-size: 12.5px; cursor: pointer; text-align: left;
  }
  .pconvtoggle:hover { color: var(--ink); }
  .pcaret { display: inline-flex; transition: transform .12s; }
  .pcaret svg { width: 9px; height: 9px; }
  .pcaret.open { transform: rotate(90deg); }
  .padd { color: var(--in-review); font-family: ui-monospace, monospace; }
  .pdel { color: var(--blocked); font-family: ui-monospace, monospace; }
  .pchecks { display: flex; flex-wrap: wrap; gap: 4px 10px; margin-top: 8px;
             font-size: 11.5px; font-family: ui-monospace, monospace; }
  .cgood { color: var(--in-review); }
  .cwarn { color: var(--in-progress); }
  .cbad  { color: var(--blocked); }
  .cmute { color: var(--faint); }

  .pconvo { display: flex; flex-direction: column; gap: 13px; padding-top: 11px; }
  /* A section label inside the conversation: reviews, then comments. Small caps
     the way the card heads are, so the eye groups them. */
  .pconvhead {
    font-size: 10px; font-weight: 600; color: var(--faint); letter-spacing: .06em;
    text-transform: uppercase; margin: 5px 0 -3px;
  }
  .pmoreconv, .pmoreline { font-size: 11.5px; color: var(--accent); cursor: default; }
  .pmoreconv { margin-top: 2px; }
  .pmoreline { margin-top: 4px; }
  .pev { display: flex; gap: 9px; }
  .pevmain { flex: 1; min-width: 0; }
  .pevhead { display: flex; align-items: center; flex-wrap: wrap; gap: 6px;
             font-size: 12.5px; }
  .pevhead b { color: var(--ink); }
  .ptag {
    font-size: 10px; color: var(--faint); border: 1px solid var(--line);
    border-radius: 999px; padding: 0 6px; text-transform: lowercase;
  }
  .pverdict { font-size: 11px; font-weight: 600; }
  .pverdict.good { color: var(--in-review); }
  .pverdict.bad  { color: var(--blocked); }
  .pverdict.mute { color: var(--dim); }
  /* The comment body reads like GitHub's: a bordered block under the byline. */
  .pev-body {
    margin-top: 5px; font-size: 12.5px; color: var(--dim); line-height: 1.5;
    background: var(--panel); border: 1px solid var(--line); border-radius: 7px;
    padding: 8px 10px; overflow-wrap: anywhere;
  }
  /* A comment is clamped to a few lines by default, with a fade at the cut, so
     one agent essay does not run the length of the card. Clicking it opens. */
  .pev-body.clamp {
    max-height: 8.2em; overflow: hidden; cursor: pointer;
    -webkit-mask-image: linear-gradient(180deg, #000 68%, transparent);
    mask-image: linear-gradient(180deg, #000 68%, transparent);
  }
  .pev-body > :first-child { margin-top: 0; }
  .pev-body > :last-child { margin-bottom: 0; }
  .pmoreline { margin-top: 6px; }
  .pev-body h4, .pev-body h5, .pev-body h6 { font-size: 12.5px; margin: 9px 0 4px; color: var(--ink); }
  .pev-body pre { background: var(--bg); border: 1px solid var(--line);
                  border-radius: 5px; padding: 6px 8px; overflow-x: auto; font-size: 11.5px; }
  .pev-body code { font-family: ui-monospace, monospace; font-size: .92em; }
  .pev-body ul { margin: 4px 0; padding-left: 18px; }
  .pev-body blockquote { border-left: 2px solid var(--line); margin: 4px 0;
                         padding-left: 9px; color: var(--faint); }

  /* Slack thread: avatar, name, time, message -- the thread pane. */
  .sthread { display: flex; flex-direction: column; gap: 13px; }
  .smsg { display: flex; gap: 9px; }
  .smain { flex: 1; min-width: 0; }
  .shead { display: flex; align-items: baseline; gap: 7px; font-size: 12px; }
  .shead b { color: var(--ink); font-size: 13px; }
  .stext { color: var(--ink); font-size: 13px; line-height: 1.46; margin-top: 1px;
           overflow-wrap: anywhere; }
  .stext a { color: var(--accent); }
  .stext pre { background: var(--panel); border: 1px solid var(--line);
               border-radius: 5px; padding: 6px 8px; margin: 5px 0; overflow-x: auto;
               font-size: 11.5px; }
  .stext code { font-family: ui-monospace, monospace; font-size: .92em; }
  .sreacts { display: flex; flex-wrap: wrap; gap: 5px; margin-top: 5px; }
  .preact {
    font-size: 11px; color: var(--dim); background: var(--panel);
    border: 1px solid var(--line); border-radius: 999px; padding: 0 7px;
  }

  .psend { display: flex; gap: 6px; align-items: flex-end; }
  .psend textarea {
    flex: 1; resize: vertical; min-height: 32px; max-height: 160px;
    background: var(--bg); color: var(--ink); border: 1px solid var(--line);
    border-radius: 6px; padding: 7px 9px; font: inherit; font-size: 12.5px;
  }
  .psend textarea:focus { outline: none; border-color: var(--accent); }
  .psend button { flex: none; }
  .psent { font-size: 11.5px; color: var(--faint); overflow-wrap: anywhere;
           display: flex; gap: 8px; align-items: center; }
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

// The two-sheets clipboard glyph, drawn rather than an emoji so it takes the
// theme's colour and sits on the pixel grid.
const CLIP = `<svg viewBox="0 0 14 14" fill="none" stroke="currentColor"
  stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"
  aria-hidden="true"><rect x="3" y="3" width="7" height="9" rx="1.3"/>
  <path d="M5.4 3 V2.2 A1 1 0 0 1 6.4 1.2 H10 A1 1 0 0 1 11 2.2 V9.6"/></svg>`;

const CHECK = `<svg viewBox="0 0 14 14" fill="none" stroke="currentColor"
  stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"
  aria-hidden="true"><path d="M2.5 7.5 L5.5 10.5 L11.5 3.5"/></svg>`;

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
// One node, the whole window. The board stays the hub; this is where a node is
// worked rather than looked at, so the page carries only the things that can be
// acted on -- the conversations and the pull requests -- and nothing the vault
// already shows better in the editor.
//
// It is a real URL under /node/, not a fragment, which is what makes it a page:
// back and forward work, it can be bookmarked, and it can be opened in a window
// of its own and left on a screen.

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

// The page is drawn from things that arrive at different times: the card is
// already in the board poll, the links come from reading the node, and each
// conversation is fetched on its own. Every redraw uses what has landed so far,
// so the page is never blank waiting on a network call.
let pLinks = null, pFor = null, pRendered = null;
const pThread = {};      // channel|ts -> {loading|error|messages}
const pSent = {};        // channel|ts -> the permalink of the last reply sent
const pDraft = {};       // key -> what is typed but not sent, kept across polls
const pConvOpen = {};    // pr url -> whether its conversation is expanded

// A fingerprint of everything the page draws, so the poll can tell a real
// change from a no-op and leave the DOM (and the scroll position) alone when
// nothing moved.
function projectSig() {
  const c = board && board.cards.find(x => x.path === detailPath);
  if (!c) return detailPath + "|nocard";
  const a = c.agent ? c.agent.state + c.agent.name : "";
  const links = (pLinks || []).map(l => {
    const d = l.data || {};
    const t = pThread[tkey(l.channel, l.ts)] || {};
    return l.url + (d.stage || "") + (d.updated || "") + (d.timeline || []).length
      + (t.error || "") + ((t.messages || []).length) + (pSent[tkey(l.channel, l.ts)] || "");
  }).join(";");
  return [detailPath, c.status, c.tracked, c.priority, a, c.open,
          pLinks === null ? "loading" : "loaded", links].join("|");
}

function renderProject(reload) {
  const path = detailPath;
  if (reload || pFor !== path) {
    pFor = path; pLinks = null;
    drawProject();
    loadProject(path);
    return;
  }
  drawProject();
}

async function loadProject(path) {
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
  for (const l of pLinks) {
    if (l.kind === "slack-thread") loadThread(l.channel, l.ts);
  }
}

const tkey = (channel, ts) => channel + "|" + ts;

async function loadThread(channel, ts, force) {
  const k = tkey(channel, ts);
  if (pThread[k] && pThread[k].loading) return;
  pThread[k] = {loading: true, ...(pThread[k] || {})};
  try {
    const r = await fetch("/api/slack?channel=" + encodeURIComponent(channel)
      + "&ts=" + encodeURIComponent(ts) + (force ? "&force=1" : ""));
    pThread[k] = await r.json();
  } catch (e) {
    pThread[k] = {error: e.message};
  }
  drawProject();
}

// ---- card chrome ---------------------------------------------------------

function card(cls, head, body, foot, key) {
  return `<section class="pcard ${cls}"><h3>${head}</h3>
    <div class="pbody"${key ? ` data-scroll="${esc(key)}"` : ""}>${body}</div>${foot || ""}</section>`;
}

function badge(tone, text) {
  return `<span class="pbadge ${esc(tone)}">${esc(text)}</span>`;
}

function isoAgo(iso) {
  if (!iso) return "";
  const t = Date.parse(iso);
  if (isNaN(t)) return "";
  return ago(Math.max(0, (Date.now() - t) / 1000)) + " ago";
}

// A Slack ts is epoch seconds with microseconds after the dot.
function slackWhen(ts) {
  const t = parseFloat(ts);
  if (!t) return "";
  const d = new Date(t * 1000);
  const sameDay = new Date().toDateString() === d.toDateString();
  return sameDay
    ? d.toLocaleTimeString([], {hour: "numeric", minute: "2-digit"})
    : d.toLocaleDateString([], {month: "short", day: "numeric"})
      + " " + d.toLocaleTimeString([], {hour: "numeric", minute: "2-digit"});
}

// Slack's own markup, which is not markdown: <@U123> mentions, <url|label>
// links, and &amp;-escaped text. Rendering it as markdown would leave the angle
// brackets on screen, which is how every naive Slack mirror gives itself away.
function slackText(s) {
  let out = esc(s || "");
  out = out.replace(/&lt;([^&|>]+)\|([^&>]*)&gt;/g,
    (m, href, label) => `<a href="${href}" target="_blank" rel="noreferrer">${label}</a>`);
  out = out.replace(/&lt;(https?:[^&>]+)&gt;/g,
    (m, href) => `<a href="${href}" target="_blank" rel="noreferrer">${href}</a>`);
  out = out.replace(/&lt;[@#]([A-Z0-9]+)(\|([^&>]*))?&gt;/g,
    (m, id, _p, label) => `<b>@${label || id}</b>`);
  out = out.replace(/```([\s\S]*?)```/g, (m, code) => `<pre>${code.trim()}</pre>`);
  out = out.replace(/`([^`\n]+)`/g, "<code>$1</code>");
  out = out.replace(/\*([^*\n]+)\*/g, "<b>$1</b>");
  out = out.replace(/\n/g, "<br>");
  return out;
}

// A box that sends somewhere, remembered across the two-second poll so a redraw
// cannot eat what is half typed. The draft is keyed, not read off the DOM,
// because the DOM is rebuilt under it.
function sendBox(key, placeholder, label) {
  return `<div class="psend">
    <textarea data-draft="${esc(key)}" rows="1" placeholder="${esc(placeholder)}"
      >${esc(pDraft[key] || "")}</textarea>
    <button data-send="${esc(key)}">${esc(label)}</button>
  </div>`;
}

// ---- the cards themselves -------------------------------------------------
//
// Each of the two that can be acted on borrows the layout of the app it mirrors,
// so the eye already knows where to look: the GitHub card reads top-to-bottom
// like a pull request (title, the opening post, then the conversation), and the
// Slack card reads like a thread (avatar, name, time, message). Using the known
// shape is the point -- an invented layout would have to be learned.

// A GitHub avatar is a public URL keyed by login, so it loads with no token and
// makes the timeline read like the real one. The initial is what shows while it
// loads and if it 404s.
function avatar(login, url) {
  const initial = esc((login || "?")[0].toUpperCase());
  const src = url || (login ? `https://github.com/${encodeURIComponent(login)}.png?size=48` : "");
  return `<span class="pav" style="--h:${hue(login || "?")}">${initial}${
    src ? `<img src="${esc(src)}" alt="" loading="lazy"
      onload="this.style.opacity=1" onerror="this.remove()">` : ""}</span>`;
}

// A stable colour per name for the initial fallback, so the same person is the
// same colour every time rather than a colour per render.
function hue(s) {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 360;
  return h;
}

// Only the workspace member is `MEMBER`; everyone else on a PR shows their
// association the way GitHub badges it, and a bot says bot.
function assoc(a, bot) {
  if (bot) return "bot";
  if (!a || a === "NONE" || a === "MEMBER" || a === "OWNER") return "";
  return a.toLowerCase().replace(/_/g, " ");
}

const REVIEW_WORD = {
  APPROVED: "approved", CHANGES_REQUESTED: "requested changes",
  COMMENTED: "reviewed", DISMISSED: "review dismissed",
};
const REVIEW_TONE = {
  APPROVED: "good", CHANGES_REQUESTED: "bad", COMMENTED: "mute", DISMISSED: "mute",
};

// A GitHub body before markdown: turn image embeds -- markdown and raw <img> --
// into a plain link, because those images sit behind GitHub auth and load as a
// broken box here, and the raw tag rendered as escaped text was worse. Every
// body is line-clamped in CSS regardless, so a long one shows its start and
// says "more on GitHub".
function ghBody(raw, clipped) {
  let s = (raw || "")
    .replace(/!\[[^\]]*\]\((https?:[^)\s]+)\)/g, "[▢ image]($1)")
    .replace(/<img[^>]*\bsrc="([^"]+)"[^>]*>/gi, "[▢ image]($1)");
  return md(s) + (clipped ? '<div class="pmoreline">… more on GitHub</div>' : "");
}

function timelineEntry(e, opts) {
  opts = opts || {};
  const tag = assoc(e.assoc, e.bot);
  const rv = e.kind === "review" ? REVIEW_WORD[e.state] || "reviewed" : "";
  const has = e.body && e.body.trim();
  return `<div class="pev${opts.open ? " pev-open" : ""}">
    ${avatar(e.who)}
    <div class="pevmain">
      <div class="pevhead">
        <b>${esc(e.who)}</b>
        ${tag ? `<span class="ptag">${esc(tag)}</span>` : ""}
        ${rv ? `<span class="pverdict ${REVIEW_TONE[e.state] || "mute"}">${esc(rv)}</span>`
             : (opts.opening ? '<span class="pdim">opened this</span>'
                             : '<span class="pdim">commented</span>')}
        <span class="pdim">${esc(isoAgo(e.at))}</span>
      </div>
      ${has ? `<div class="pev-body${opts.open ? "" : " clamp"}">${ghBody(e.body, e.clipped)}</div>`
            : (rv ? "" : '<div class="pdim">(no text)</div>')}
    </div>
  </div>`;
}

// How much of a PR's conversation the card shows. The description and every
// human review are the signal Kai asked for; comments are capped and bot chatter
// (CI preview links, coverage bots) is counted, not shown, because agents post
// long and often and would otherwise bury the reviews.
const PR_COMMENTS_SHOWN = 4;

// The court-and-clock line: whose move it is, on what, and for how long. This
// is what a PR list is really asking, so it sits at the top, coloured by court
// -- mine wants my attention, theirs is a wait, done is settled.
const COURT_TONE = {mine: "warn", theirs: "mute", done: "good"};

function prSituation(d) {
  const s = d.situation;
  if (!s) return "";
  const tone = s.court === "done" ? "good" : COURT_TONE[s.court] || "mute";
  const dur = s.since ? isoAgo(s.since).replace(" ago", "") : "";
  const whose = s.court === "mine" ? "your court"
    : s.court === "theirs" ? "their court" : "";
  return `<div class="psit ${tone}">
    <span class="psitdot"></span>
    <span class="psitverb">${esc(s.verb)}</span>
    ${s.who ? `<span class="psitwho">${esc(s.who)}</span>` : ""}
    <span class="grow"></span>
    ${whose ? `<span class="psitcourt">${whose}</span>` : ""}
    ${dur ? `<span class="psitdur">${esc(dur)}</span>` : ""}
  </div>`;
}

// The whole conversation, reviews first, comments capped, bots counted. Returned
// as a block that the card shows or hides as one -- collapsed by default, so the
// card leads with state and description and the thread is there when wanted.
function prThread(d) {
  const tl = d.timeline || [];
  const reviews = tl.filter(e => e.kind === "review");
  const humanComments = tl.filter(e => e.kind === "comment" && !e.bot);
  const botComments = tl.filter(e => e.kind === "comment" && e.bot);
  const shown = humanComments.slice(-PR_COMMENTS_SHOWN);
  const hidden = (humanComments.length - shown.length) + botComments.length;

  let out = "";
  if (reviews.length) {
    out += `<div class="pconvhead">reviews</div>`
      + reviews.map(e => timelineEntry(e)).join("");
  }
  if (shown.length) {
    out += `<div class="pconvhead">${
      humanComments.length > shown.length
        ? `latest ${shown.length} of ${humanComments.length} comments` : "comments"}</div>`
      + shown.map(e => timelineEntry(e)).join("");
  }
  if (!reviews.length && !humanComments.length) {
    out += '<div class="pdim pquiet">no comments or reviews yet</div>';
  }
  if (hidden > 0) {
    const onlyBots = botComments.length && humanComments.length <= shown.length;
    out += `<div class="pmoreconv">+ ${hidden}${onlyBots ? " automated" : ""} more on GitHub</div>`;
  }
  return out;
}

function threadCount(d) {
  const tl = d.timeline || [];
  const r = tl.filter(e => e.kind === "review").length;
  const c = tl.filter(e => e.kind === "comment" && !e.bot).length;
  const parts = [];
  if (r) parts.push(r + (r === 1 ? " review" : " reviews"));
  if (c) parts.push(c + (c === 1 ? " comment" : " comments"));
  return parts.join(", ");
}

function prCard(l) {
  const what = l.kind === "github-pr" ? "pull request" : "issue";
  const head = `<span class="pk">${esc(l.repo)} #${l.number}</span>
    ${l.found ? '<span class="pfound">in the notes</span>' : ""}
    <span class="grow"></span>
    <a class="popen" href="${esc(l.url)}" target="_blank" rel="noreferrer">open on GitHub</a>`;

  if (l.error) return card("tall", head, `<div class="pempty"><p class="pfail">${esc(l.error)}</p></div>`);
  const d = l.data;
  if (!d) return card("tall", head, `<div class="pempty"><p>reading the ${what}…</p></div>`);

  const meta = [];
  if (d.author) meta.push(`<b>${esc(d.author)}</b> opened ${esc(isoAgo(d.opened))}`);
  if (d.branch) meta.push(`<span class="pmono">${esc(d.branch)} → ${esc(d.base)}</span>`);
  if (d.adds != null) meta.push(`<span class="padd">+${d.adds}</span> <span class="pdel">−${d.dels}</span>`);
  if (d.files != null) meta.push(d.files + (d.files === 1 ? " file" : " files"));

  const counts = d.checks ? [
    d.checks.failed ? `<span class="cbad">✗ ${d.checks.failed} failing</span>` : "",
    d.checks.pending ? `<span class="cwarn">○ ${d.checks.pending} running</span>` : "",
    d.checks.passed ? `<span class="cgood">✓ ${d.checks.passed} passed</span>` : "",
    d.checks.skipped ? `<span class="cmute">${d.checks.skipped} skipped</span>` : "",
  ].filter(Boolean).join("") : "";

  const opening = (d.body && d.body.trim())
    ? `<div class="prdesc">${ghBody(d.body, false)}</div>` : "";
  const count = threadCount(d);
  const open = !!pConvOpen[l.url];

  return card("tall wide", head, `
    <div class="prhead">
      <div class="prtitle">${badge(d.tone, d.stage)}<span>${esc(d.title || "")}</span></div>
      ${prSituation(d)}
      <div class="prmeta">${meta.join('<span class="sep">·</span>')}</div>
      ${counts ? `<div class="pchecks">${counts}</div>` : ""}
      ${d.failing && d.failing.length
        ? `<div class="pfail">${esc(d.failing.join("\n"))}</div>` : ""}
    </div>
    ${opening}
    ${count ? `<button class="pconvtoggle" data-conv="${esc(l.url)}">
      <span class="pcaret${open ? " open" : ""}">${CARET}</span>
      ${open ? "hide" : "show"} conversation <span class="pdim">${esc(count)}</span></button>` : ""}
    ${open && count ? `<div class="pconvo">${prThread(d)}</div>` : ""}`,
    `<div class="pfoot">
       ${sendBox("gh|" + l.url, "comment on this " + what + "…", "comment")}
       <div class="pfootrow">
         ${d.branch ? `<button class="linkish" data-copy="${esc(d.branch)}">copy branch name</button>` : ""}
       </div>
     </div>`, l.url);
}

function slackCard(l) {
  const k = tkey(l.channel, l.ts);
  const t = pThread[k] || {};
  const head = `<span class="pk"># ${esc(l.chan_name || l.channel)}</span>
    ${l.found ? '<span class="pfound">in the notes</span>' : ""}
    <span class="grow"></span>
    ${l.app_url ? `<a class="popen" href="${esc(l.app_url)}">open in Slack</a>` : ""}
    <a class="popen" href="${esc(l.url)}" target="_blank" rel="noreferrer">open in browser</a>`;

  if (t.error === "no-creds") {
    return card("tall wide", head, `<div class="pempty pslackempty">
      <p><b>Slack isn't connected yet.</b> The thread is there — it just needs
         one of your Slack tokens to read it as you.</p>
      <p class="pconnrow"><b>One command sets it up:</b></p>
      <div class="pcopy">
        <code>board slack-auth</code>
        <button class="pcopybtn" data-copy="board slack-auth"
          data-icon="1" title="copy">${CLIP}</button>
      </div>
      <p>Run it with no arguments and it prints the two ways to get a token —
         a durable workspace-app token that works on every machine, or the
         desktop app's own session for this one — then finishes with
         <code>board slack-auth &lt;token&gt;</code>.</p>
      <p class="pdim">It writes ${esc(t.conf || "")} and the card fills on the next
         refresh. No server restart.</p></div>`, "", l.url);
  }
  if (t.error) {
    return card("tall wide", head, `<div class="pempty"><p class="pfail">${esc(t.error)}</p></div>`, "", l.url);
  }
  if (!t.messages) {
    return card("tall wide", head, `<div class="pempty"><p>reading the thread…</p></div>`);
  }

  const msgs = t.messages.map((m, i) => {
    const react = (m.reactions || []).map(r =>
      `<span class="preact">:${esc(r.name)}: ${r.count}</span>`).join("");
    return `<div class="smsg">
      ${avatar(m.who, m.avatar)}
      <div class="smain">
        <div class="shead"><b>${esc(m.who)}</b>
          <span class="pdim">${esc(slackWhen(m.ts))}</span>
          ${i === 0 ? '<span class="ptag">thread start</span>' : ""}</div>
        <div class="stext">${slackText(m.text)}</div>
        ${m.files ? `<div class="pdim">${m.files} file${m.files === 1 ? "" : "s"}</div>` : ""}
        ${react ? `<div class="sreacts">${react}</div>` : ""}
      </div>
    </div>`;
  }).join("");

  const sent = pSent[k];
  return card("tall wide", head,
    `<div class="sthread">${msgs || '<div class="pempty"><p>no messages</p></div>'}</div>`,
    `<div class="pfoot">
       ${sendBox(k, "reply in thread…", "send")}
       ${sent ? `<div class="psent">sent ·
         <a href="${esc(sent)}" target="_blank" rel="noreferrer">view</a>
         <button class="linkish" data-copy="${esc(sent)}">copy link</button></div>` : ""}
     </div>`, l.url);
}

function linkCard(l) {
  if (l.kind === "slack-thread") return slackCard(l);
  if (l.kind === "github-pr" || l.kind === "github-issue") return prCard(l);

  const label = l.kind === "linear-issue" ? "linear"
    : l.kind === "slack-channel" ? "slack channel"
    : l.kind === "github-repo" ? "github repo"
    : (l.key || l.host);
  const head = `<span class="pk">${esc(label)}</span>
    ${l.found ? '<span class="pfound">in the notes</span>' : ""}
    <span class="grow"></span>
    ${l.app_url ? `<a class="popen" href="${esc(l.app_url)}">app</a>` : ""}
    <a class="popen" href="${esc(l.url)}" target="_blank" rel="noreferrer">open</a>`;
  const what = l.issue || l.channel || l.repo || l.key || "";
  return card("", head,
    `${what ? `<div class="ptitle">${esc(what)}</div>` : ""}
     <div class="pmono">${esc(l.url.replace(/^https?:\/\//, ""))}</div>`);
}

// ---- the page -------------------------------------------------------------

function drawProject() {
  const path = detailPath;
  const c = board && board.cards.find(x => x.path === path);
  const host = document.getElementById("project");
  pRendered = projectSig();
  // A rebuild is sometimes unavoidable even when the signature gate lets it
  // through -- an action redraws on purpose -- so scroll positions are captured
  // by a stable key and put back, and the page does not lurch.
  const scroll = {};
  for (const el of host.querySelectorAll("[data-scroll]")) {
    if (el.scrollTop) scroll[el.dataset.scroll] = el.scrollTop;
  }
  const restore = () => {
    for (const el of host.querySelectorAll("[data-scroll]")) {
      if (scroll[el.dataset.scroll]) el.scrollTop = scroll[el.dataset.scroll];
    }
  };
  if (!c) {
    host.innerHTML = `<div class="phead"><button class="pback" id="pback">${BACK} board</button>
      <h2>${esc(path || "")}</h2></div>`;
    document.getElementById("pback").addEventListener("click", gotoBoard);
    return;
  }

  const links = pLinks !== null ? pLinks : [];
  // Two tiers, because they want different room. Threads and pull requests are
  // worked in, so they get large, uniform cards; a plain link is a chip. Each
  // tier is its own grid so one tall card cannot leave a hole beside a short
  // one -- the ragged-grid problem is solved by not mixing the two heights.
  const isBig = l => l.kind === "slack-thread"
    || l.kind === "github-pr" || l.kind === "github-issue";
  const rank = l => l.kind === "slack-thread" ? 0
    : l.kind === "github-pr" ? 1 : 2;
  const big = links.filter(isBig).sort((a, b) => rank(a) - rank(b));
  const mini = links.filter(l => !isBig(l));

  host.innerHTML = `
    <div class="phead" style="--c:${cssVar(c.status)}">
      <div class="pline">
        <button class="pback" id="pback">${BACK} board</button>
        <span class="trail mono">${esc(c.trail.join(" / "))}</span>
        <span class="grow"></span>
        ${c.agent
          ? `<span class="agent${c.agent.state === "idle" ? " waits" : ""}">
               <span class="pulse"></span>${
                 c.agent.state === "idle" ? "waiting for you"
                 : c.agent.state === "busy" ? "working" : "quiet"}
               ${c.agent.name ? `<span class="when">${esc(c.agent.name)}</span>` : ""}</span>`
          : c.touched ? `<span class="when">touched ${ago(board.now - c.touched)} ago</span>` : ""}
        ${(c.agent && c.agent.desktop) || c.open
          ? `<button class="jump" data-pid="${c.agent && c.agent.desktop ? c.agent.pid : ""}"
               data-desk="${esc((c.agent && c.agent.desktop) || c.open)}"
               >desktop ${esc((c.agent && c.agent.desktop) || c.open)}</button>`
          : ""}
      </div>
      <div class="pline ptop">
        <h2>${esc(c.slug)}</h2>
        <button class="pill" data-menu="${esc(c.path)}"
          title="move it, hide it, open its links">${esc(label(c.status))}${CARET}</button>
        <button class="dbtn ${c.tracked ? "on" : ""}" data-track="${esc(c.path)}"
          data-on="${c.tracked ? "0" : "1"}"
          >${c.tracked ? PIN_ON : PIN}${c.tracked ? "tracked" : "track"}</button>
        ${c.tracked ? `<button class="dbtn ${esc(c.priority || "")}" data-pri="${esc(c.path)}"
          >${BARS(PRI_LEVEL[c.priority] || 0)}${esc(c.priority || "no priority")}</button>` : ""}
        ${c.description ? `<p class="pdesc">${esc(c.description)}</p>` : ""}
      </div>
      ${priMenu === c.path ? `<div class="primenu" style="top:70px;left:150px">
        ${["high", "medium", "low"].map(k =>
          `<button data-set="${esc(c.path)}" data-level="${k}"
            style="color:var(--${k === "high" ? "blocked" : k === "medium" ? "in-progress" : "dim"})"
            >${BARS(PRI_LEVEL[k])}${k}</button>`).join("")}
        <button data-set="${esc(c.path)}" data-level="">${BARS(0)}none</button>
      </div>` : ""}
    </div>
    <div class="pscroll" data-scroll="page">
      ${pLinks === null ? '<div class="pdim pquiet">reading the node…</div>' : ""}
      ${big.length ? `<div class="pgrid">${big.map(linkCard).join("")}</div>` : ""}
      ${mini.length ? `<div class="pmini">${mini.map(linkCard).join("")}</div>` : ""}
      ${pLinks !== null && !links.length
        ? `<div class="pquiet"><b>Nothing linked.</b> This node names no pull request,
             thread or issue — not in its frontmatter and not anywhere in its notes.</div>` : ""}
    </div>`;
  document.getElementById("pback").addEventListener("click", gotoBoard);
  wireProject();
  wire();
  restore();
}

function wireProject() {
  // The whole conversation toggles as one, collapsed by default, so the card
  // leads with state and reads short until the thread is actually wanted.
  for (const b of document.querySelectorAll("[data-conv]")) {
    b.addEventListener("click", () => {
      pConvOpen[b.dataset.conv] = !pConvOpen[b.dataset.conv];
      drawProject();
    });
  }
  // A clamped comment opens in place on a click, so a long one is available
  // without leaving the board and without being tall by default.
  for (const b of document.querySelectorAll(".pev-body.clamp")) {
    b.addEventListener("click", () => b.classList.remove("clamp"));
  }
  for (const t of document.querySelectorAll("[data-draft]")) {
    t.addEventListener("input", () => { pDraft[t.dataset.draft] = t.value; });
    // Enter sends and shift-enter breaks the line, which is what the box it is
    // standing in for does.
    t.addEventListener("keydown", e => {
      if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(t.dataset.draft); }
      e.stopPropagation();
    });
  }
  for (const b of document.querySelectorAll("[data-send]")) {
    b.addEventListener("click", () => send(b.dataset.send));
  }
  for (const b of document.querySelectorAll("[data-copy]")) {
    b.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(b.dataset.copy);
        // An icon button flashes a check in place; a text link says "copied".
        // Both restore themselves without a full redraw, so nothing else moves.
        if (b.dataset.icon) {
          const was = b.innerHTML;
          b.innerHTML = CHECK;
          b.classList.add("ok");
          setTimeout(() => { b.innerHTML = was; b.classList.remove("ok"); }, 1200);
        } else {
          const was = b.textContent;
          b.textContent = "copied";
          setTimeout(() => { b.textContent = was; }, 1200);
        }
      } catch (e) { fail("could not copy: " + e.message); }
    });
  }
}

async function send(key) {
  const text = (pDraft[key] || "").trim();
  if (!text) return;
  const btn = document.querySelector(`[data-send="${CSS.escape(key)}"]`);
  if (btn) { btn.disabled = true; btn.textContent = "sending"; }
  try {
    if (key.startsWith("gh|")) {
      const url = key.slice(3);
      const l = (pLinks || []).find(x => x.url === url);
      const r = await fetch("/api/comment", {method: "POST", body: JSON.stringify(
        {url, repo: l.repo, number: l.number, kind: l.kind, text})});
      const d = await r.json();
      if (d.error) throw new Error(d.error);
      pDraft[key] = "";
      loadProject(detailPath);
    } else {
      const [channel, ts] = key.split("|");
      const r = await fetch("/api/reply", {method: "POST", body: JSON.stringify(
        {channel, ts, text})});
      const d = await r.json();
      if (d.error) throw new Error(d.error);
      pDraft[key] = "";
      if (d.permalink) pSent[key] = d.permalink;
      loadThread(channel, ts, true);
    }
  } catch (e) {
    fail(e.message);
  }
  drawProject();
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
    // The poll keeps agent state and status live, and the project page shows
    // the same facts, so it redraws on the poll too -- but only when something
    // it shows actually changed. Rebuilding its DOM every two seconds threw
    // away the scroll position inside a long conversation, which read as the
    // page jumping to the top. And never while a reply is being typed.
    if (detailPath) {
      const composing = document.activeElement
        && document.activeElement.matches(".psend textarea");
      if (!composing && projectSig() !== pRendered) drawProject();
    } else if (signature(board) === rendered) tick();
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
