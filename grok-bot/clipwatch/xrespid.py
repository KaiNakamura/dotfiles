import ctypes,sys
x=ctypes.cdll.LoadLibrary("libX11.so.6"); r=ctypes.cdll.LoadLibrary("libXRes.so.1")
x.XOpenDisplay.restype=ctypes.c_void_p
class Spec(ctypes.Structure): _fields_=[("client",ctypes.c_ulong),("mask",ctypes.c_uint)]
class CID(ctypes.Structure): _fields_=[("spec",Spec),("length",ctypes.c_long),("value",ctypes.c_void_p)]
d=x.XOpenDisplay(None)
w=int(sys.argv[1],16)
spec=Spec(w,2)  # XRES_CLIENT_ID_PID_MASK
n=ctypes.c_long(); ids=ctypes.POINTER(CID)()
r.XResQueryClientIds.argtypes=[ctypes.c_void_p,ctypes.c_long,ctypes.POINTER(Spec),ctypes.POINTER(ctypes.c_long),ctypes.POINTER(ctypes.POINTER(CID))]
r.XResQueryClientIds(d,1,ctypes.byref(spec),ctypes.byref(n),ctypes.byref(ids))
for i in range(n.value):
    if ids[i].spec.mask==2 and ids[i].length==4:
        print(ctypes.cast(ids[i].value,ctypes.POINTER(ctypes.c_uint32))[0])
