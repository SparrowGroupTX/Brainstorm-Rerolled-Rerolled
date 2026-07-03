import argparse
import ctypes
import ctypes.wintypes as wt
from pathlib import Path


CCH_RM_SESSION_KEY = 32
CCH_RM_MAX_APP_NAME = 255
CCH_RM_MAX_SVC_NAME = 63
ERROR_MORE_DATA = 234


class RM_UNIQUE_PROCESS(ctypes.Structure):
    _fields_ = [("dwProcessId", wt.DWORD), ("ProcessStartTime", wt.FILETIME)]


class RM_PROCESS_INFO(ctypes.Structure):
    _fields_ = [
        ("Process", RM_UNIQUE_PROCESS),
        ("strAppName", wt.WCHAR * (CCH_RM_MAX_APP_NAME + 1)),
        ("strServiceShortName", wt.WCHAR * (CCH_RM_MAX_SVC_NAME + 1)),
        ("ApplicationType", wt.UINT),
        ("AppStatus", wt.ULONG),
        ("TSSessionId", wt.DWORD),
        ("bRestartable", wt.BOOL),
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path")
    args = parser.parse_args()

    target = str(Path(args.path).resolve())
    rstrtmgr = ctypes.WinDLL("Rstrtmgr")
    handle = wt.DWORD()
    key = ctypes.create_unicode_buffer(CCH_RM_SESSION_KEY + 1)
    res = rstrtmgr.RmStartSession(ctypes.byref(handle), 0, key)
    if res != 0:
        raise RuntimeError(f"RmStartSession failed: {res}")
    try:
        resources = (ctypes.c_wchar_p * 1)(target)
        res = rstrtmgr.RmRegisterResources(handle, 1, resources, 0, None, 0, None)
        if res != 0:
            raise RuntimeError(f"RmRegisterResources failed: {res}")

        needed = wt.UINT()
        count = wt.UINT()
        reasons = wt.DWORD()
        res = rstrtmgr.RmGetList(
            handle,
            ctypes.byref(needed),
            ctypes.byref(count),
            None,
            ctypes.byref(reasons),
        )
        if res == 0:
            print("count=0")
            return 0
        if res != ERROR_MORE_DATA:
            raise RuntimeError(f"Initial RmGetList failed: {res}")

        infos = (RM_PROCESS_INFO * needed.value)()
        count = wt.UINT(needed.value)
        res = rstrtmgr.RmGetList(
            handle,
            ctypes.byref(needed),
            ctypes.byref(count),
            infos,
            ctypes.byref(reasons),
        )
        if res != 0:
            raise RuntimeError(f"Second RmGetList failed: {res}")

        print(f"count={count.value}")
        for i in range(count.value):
            info = infos[i]
            print(
                f"pid={info.Process.dwProcessId} app={info.strAppName} svc={info.strServiceShortName}"
            )
        return 0
    finally:
        rstrtmgr.RmEndSession(handle)


if __name__ == "__main__":
    raise SystemExit(main())
