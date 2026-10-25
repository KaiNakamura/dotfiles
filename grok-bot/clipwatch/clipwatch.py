#!/usr/bin/env python3
# Logs CLIPBOARD owner changes and whether the new owner answers a TARGETS request within 3s.
import ctypes, subprocess, time, datetime
x=ctypes.cdll.LoadLibrary("libX11.so.6"); r=ctypes.cdll.LoadLibrary("libXRes.so.1")
x.XOpenDisplay.restype=ctypes.c_void_p
x.XInternAtom.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_int]; x.XInternAtom.restype=ctypes.c_ulong
x.XGetSelectionOwner.argtypes=[ctypes.c_void_p,ctypes.c_ulong]; x.XGetSelectionOwner.restype=ctypes.c_ulong
class Spec(ctypes.Structure): _fields_=[("client",ctypes.c_ulong),("mask",ctypes.c_uint)]
class CID(ctypes.Structure): _fields_=[("spec",Spec),("length",ctypes.c_long),("value",ctypes.c_void_p)]
r.XResQueryClientIds.argtypes=[ctypes.c_void_p,ctypes.c_long,ctypes.POINTER(Spec),ctypes.POINTER(ctypes.c_long),ctypes.POINTER(ctypes.POINTER(CID))]
d=x.XOpenDisplay(None); CB=x.XInternAtom(d,b"CLIPBOARD",0)
def pid(w):
    s=Spec(w,2); n=ctypes.c_long(); ids=ctypes.POINTER(CID)()
    r.XResQueryClientIds(d,1,ctypes.byref(s),ctypes.byref(n),ctypes.byref(ids))
    for i in range(n.value):
        if ids[i].spec.mask==2 and ids[i].length==4: return ctypes.cast(ids[i].value,ctypes.POINTER(ctypes.c_uint32))[0]
def name(p):
    try: return open(f"/proc/{p}/cmdline","rb").read().split(b"\0")[0].decode()
    except Exception: return "?"
last=None
while True:
    w=x.XGetSelectionOwner(d,CB)
    if w!=last:
        last=w; p=pid(w) if w else None
        t0=time.time()
        try:
            out=subprocess.run(["xclip","-selection","clipboard","-o","-t","TARGETS"],capture_output=True,text=True,timeout=3).stdout
            res=f"answered in {time.time()-t0:.2f}s targets={','.join(out.split())[:300]}"
        except subprocess.TimeoutExpired:
            res="NO ANSWER within 3s  <-- this owner would freeze Grok Bot"
        print(f"{datetime.datetime.now():%H:%M:%S} owner={hex(w)} pid={p} exe={name(p) if p else '-'} {res}",flush=True)
    time.sleep(0.3)
