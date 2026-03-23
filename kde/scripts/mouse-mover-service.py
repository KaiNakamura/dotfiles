#!/usr/bin/env python3
"""D-Bus service that moves the mouse cursor using dotool.

Called from the hjkl-edge-guard KWin script via callDBus when focus
or a window moves to a different screen.
"""

import os

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

DOTOOL_PIPE = os.environ.get("DOTOOL_PIPE", "/tmp/dotool-pipe")


class MouseMover(dbus.service.Object):
    @dbus.service.method("org.hjkl.MouseMover", in_signature="ss")
    def MoveTo(self, x, y):
        try:
            with open(DOTOOL_PIPE, "w") as f:
                f.write(f"mouseto {x} {y}\n")
        except OSError:
            pass


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    dbus.service.BusName("org.hjkl.MouseMover", bus)
    MouseMover(bus, "/MouseMover")
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
