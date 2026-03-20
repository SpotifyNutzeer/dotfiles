#!/usr/bin/env python3
import os, re, glob

ICON_DIRS = [
    "/usr/share/icons/hicolor",
    "/usr/share/icons/Papirus",
    "/usr/share/icons/breeze",
    "/usr/share/icons/Adwaita",
    os.path.expanduser("~/.local/share/icons/hicolor"),
]
SIZES = ["48x48", "32x32", "64x64", "256x256", "scalable"]
EXTS  = ["png", "svg", "xpm"]

def find_icon(name):
    if not name:
        return ""
    if os.path.isfile(name):
        return name
    for base in ICON_DIRS:
        for size in SIZES:
            for ext in EXTS:
                p = f"{base}/{size}/apps/{name}.{ext}"
                if os.path.isfile(p):
                    return p
    for ext in EXTS:
        p = f"/usr/share/pixmaps/{name}.{ext}"
        if os.path.isfile(p):
            return p
    return ""

apps = {}
search_dirs = [
    "/usr/share/applications",
    os.path.expanduser("~/.local/share/applications"),
]

for d in search_dirs:
    for path in glob.glob(os.path.join(d, "**/*.desktop"), recursive=True):
        try:
            name = exec_ = icon = ""
            nodisplay = hidden = in_entry = False
            with open(path, encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.rstrip("\n")
                    if line == "[Desktop Entry]":
                        in_entry = True
                    elif line.startswith("[") and line != "[Desktop Entry]":
                        in_entry = False
                    elif in_entry:
                        if   line.startswith("Name=")      and not name:  name  = line[5:]
                        elif line.startswith("Exec="):                    exec_ = re.sub(r" *%[a-zA-Z]", "", line[5:])
                        elif line.startswith("Icon="):                    icon  = line[5:]
                        elif line == "NoDisplay=true":                    nodisplay = True
                        elif line == "Hidden=true":                       hidden    = True
            if not nodisplay and not hidden and name and exec_:
                if name not in apps:
                    apps[name] = (exec_, find_icon(icon))
        except Exception:
            pass

for name in sorted(apps):
    exec_, icon_path = apps[name]
    print(f"{name}|{exec_}|{icon_path}")
