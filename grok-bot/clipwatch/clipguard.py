#!/usr/bin/env python3
"""Watch CLIPBOARD; if the owner ignores TARGETS, re-own with plain text.

Mitigates Electron/Chromium X11 paste hang (no SelectionRequester timeout
until Electron PR #54914 lands). Only steals when the owner is already
unresponsive, so that copy was unusable anyway.
"""
import ctypes
import datetime
import subprocess
import time

x = ctypes.cdll.LoadLibrary("libX11.so.6")
r = ctypes.cdll.LoadLibrary("libXRes.so.1")
x.XOpenDisplay.restype = ctypes.c_void_p
x.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
x.XInternAtom.restype = ctypes.c_ulong
x.XGetSelectionOwner.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
x.XGetSelectionOwner.restype = ctypes.c_ulong


class Spec(ctypes.Structure):
    _fields_ = [("client", ctypes.c_ulong), ("mask", ctypes.c_uint)]


class CID(ctypes.Structure):
    _fields_ = [("spec", Spec), ("length", ctypes.c_long), ("value", ctypes.c_void_p)]


r.XResQueryClientIds.argtypes = [
    ctypes.c_void_p,
    ctypes.c_long,
    ctypes.POINTER(Spec),
    ctypes.POINTER(ctypes.c_long),
    ctypes.POINTER(ctypes.POINTER(CID)),
]

d = x.XOpenDisplay(None)
CB = x.XInternAtom(d, b"CLIPBOARD", 0)
TIMEOUT = 1.5


def pid_of(w):
    if not w:
        return None
    s = Spec(w, 2)
    n = ctypes.c_long()
    ids = ctypes.POINTER(CID)()
    r.XResQueryClientIds(d, 1, ctypes.byref(s), ctypes.byref(n), ctypes.byref(ids))
    for i in range(n.value):
        if ids[i].spec.mask == 2 and ids[i].length == 4:
            return ctypes.cast(ids[i].value, ctypes.POINTER(ctypes.c_uint32))[0]
    return None


def exe(p):
    try:
        return open(f"/proc/{p}/cmdline", "rb").read().split(b"\0")[0].decode()
    except Exception:
        return "?"


def answers(timeout=TIMEOUT):
    try:
        subprocess.run(
            ["xclip", "-selection", "clipboard", "-o", "-t", "TARGETS"],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return True
    except subprocess.TimeoutExpired:
        return False


def reown(msg=" "):
    subprocess.run(
        ["xclip", "-selection", "clipboard", "-i", "-t", "text/plain"],
        input=msg.encode(),
        check=False,
    )


last = None
print(f"clipguard started timeout={TIMEOUT}s", flush=True)
while True:
    w = x.XGetSelectionOwner(d, CB)
    if w != last:
        last = w
        p = pid_of(w) if w else None
        stamp = datetime.datetime.now().strftime("%H:%M:%S")
        if not w:
            print(f"{stamp} owner=none", flush=True)
        elif answers():
            print(f"{stamp} owner={hex(w)} pid={p} exe={exe(p) if p else '-'} ok", flush=True)
        else:
            print(
                f"{stamp} owner={hex(w)} pid={p} exe={exe(p) if p else '-'} "
                f"NO ANSWER, re-owning plain text",
                flush=True,
            )
            reown(" ")
            last = None
    time.sleep(0.25)
