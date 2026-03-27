#!/usr/bin/env python3
"""D-Bus service that moves the mouse cursor using dotool.

Called from the hjkl-edge-guard KWin script via callDBus when focus
or a window moves to a different screen.

Spawns dotool as a persistent subprocess and writes mouseto commands
directly to its stdin, eliminating the need for dotoold and the FIFO.
"""

import os
import subprocess

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

DOTOOL_PATH = os.path.expanduser("~/.local/bin/dotool")


class MouseMover(dbus.service.Object):
    def __init__(self, bus, path):
        super().__init__(bus, path)
        self._dotool = None
        self._start_dotool()

    def _start_dotool(self):
        self._dotool = subprocess.Popen(
            [DOTOOL_PATH],
            stdin=subprocess.PIPE,
            text=True,
            bufsize=1,
        )

    def _ensure_dotool(self):
        if self._dotool is None or self._dotool.poll() is not None:
            self._start_dotool()

    @dbus.service.method("org.hjkl.MouseMover", in_signature="ss")
    def MoveTo(self, x, y):
        try:
            self._ensure_dotool()
            self._dotool.stdin.write(f"mouseto {x} {y}\n")
            self._dotool.stdin.flush()
        except (OSError, BrokenPipeError):
            self._dotool = None


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    _name = dbus.service.BusName("org.hjkl.MouseMover", bus, do_not_queue=True)
    _mover = MouseMover(bus, "/MouseMover")
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
