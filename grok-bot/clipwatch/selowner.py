import ctypes, subprocess
x=ctypes.cdll.LoadLibrary("libX11.so.6")
x.XOpenDisplay.restype=ctypes.c_void_p
x.XInternAtom.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_int]; x.XInternAtom.restype=ctypes.c_ulong
x.XGetSelectionOwner.argtypes=[ctypes.c_void_p,ctypes.c_ulong]; x.XGetSelectionOwner.restype=ctypes.c_ulong
d=x.XOpenDisplay(None)
for s in [b"CLIPBOARD",b"PRIMARY",b"CLIPBOARD_MANAGER"]:
    w=x.XGetSelectionOwner(d,x.XInternAtom(d,s,0))
    print("==",s.decode(),hex(w))
    if w:
        out=subprocess.run(["xprop","-id",hex(w),"WM_CLASS","WM_NAME","_NET_WM_PID","WM_CLIENT_LEADER"],capture_output=True,text=True).stdout
        print(out.strip())
        for line in out.splitlines():
            if "_NET_WM_PID" in line and "=" in line:
                pid=line.split("=")[1].strip()
                print(subprocess.run(["ps","-o","pid,comm,args","-p",pid],capture_output=True,text=True).stdout[:300])
