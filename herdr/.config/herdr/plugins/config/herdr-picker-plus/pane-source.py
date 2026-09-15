#!/usr/bin/env python3
"""Open-pane source for Herdr Picker Plus.

Picker Plus only indexes workspaces and agent panes out of the box; plain
panes (shells, btop, nvim, ...) are invisible to it. This script feeds them
in through the [[integrations]] command/JSON mechanism:

  pane-source.py list          -> JSON array of non-agent panes
  pane-source.py focus PANE_ID -> focus workspace, tab, then pane

Focusing uses the raw socket because the CLI only exposes directional pane
focus, while the socket API has pane.focus by id (protocol 16).
"""

import json
import os
import socket
import subprocess
import sys

SOCK = os.path.expanduser("~/.config/herdr/herdr.sock")

# Overlay/split panes spawned by Picker Plus itself; focusing them is useless
# because they close when the picker exits.
SELF_TITLES = {"Picker Plus", "Picker Side"}


def rpc(method, params):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCK)
    s.settimeout(5)
    s.sendall((json.dumps({"id": "pane-source", "method": method, "params": params}) + "\n").encode())
    buf = b""
    while b"\n" not in buf:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf += chunk
    s.close()
    return json.loads(buf.decode())


def herdr_json(*argv):
    out = subprocess.run(["herdr", *argv], capture_output=True, text=True, timeout=10)
    return json.loads(out.stdout)


def list_panes():
    panes = herdr_json("pane", "list")["result"]["panes"]
    workspaces = herdr_json("workspace", "list")["result"]["workspaces"]
    ws_labels = {w["workspace_id"]: w.get("label", w["workspace_id"]) for w in workspaces}
    items = []
    for p in panes:
        if p.get("agent"):
            continue  # already covered by the built-in agent source
        title = p.get("label") or p.get("terminal_title_stripped") or p["pane_id"]
        if title in SELF_TITLES:
            continue
        ws = ws_labels.get(p.get("workspace_id", ""), p.get("workspace_id", ""))
        cwd = p.get("foreground_cwd") or p.get("cwd") or ""
        items.append({
            "id": p["pane_id"],
            "title": f"{title} · {ws}",
            "subtitle": f"{p['pane_id']} · {cwd}",
            "path": cwd,
            "kind": "pane",
        })
    print(json.dumps(items))


def focus(pane_id):
    info = rpc("pane.get", {"pane_id": pane_id})
    pane = info["result"]["pane"]
    rpc("workspace.focus", {"workspace_id": pane["workspace_id"]})
    rpc("tab.focus", {"tab_id": pane["tab_id"]})
    resp = rpc("pane.focus", {"pane_id": pane_id})
    if "error" in resp:
        sys.exit(resp["error"].get("message", "pane.focus failed"))


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "list":
        list_panes()
    elif len(sys.argv) >= 3 and sys.argv[1] == "focus":
        focus(sys.argv[2])
    else:
        sys.exit("usage: pane-source.py list | focus PANE_ID")
