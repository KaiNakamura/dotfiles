#!/usr/bin/env python3
"""D-Bus service that keeps the latest KWin window list on disk.

The window-list-publisher KWin script calls Publish via callDBus whenever a
window changes, and on a heartbeat. Each call replaces the snapshot file that
kwin-window-list prints, so a read never has to touch KWin at all.
"""

import os

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

SNAPSHOT = os.path.join(
    os.environ.get("XDG_RUNTIME_DIR", "/run/user/%d" % os.getuid()),
    "kwin-window-list",
)


class WindowList(dbus.service.Object):
    @dbus.service.method("org.hjkl.WindowList", in_signature="s")
    def Publish(self, lines):
        # Written aside and renamed over, so a reader never sees half a list.
        tmp = SNAPSHOT + ".tmp"
        with open(tmp, "w") as f:
            f.write(lines)
            if lines:
                f.write("\n")
        os.replace(tmp, SNAPSHOT)


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    _name = dbus.service.BusName("org.hjkl.WindowList", bus, do_not_queue=True)
    _service = WindowList(bus, "/WindowList")
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
