#!/usr/bin/env fish
set d /opt/resolve/libs/disabled
sudo mkdir -p $d
for lib in libglib-2.0 libgio-2.0 libgmodule-2.0 libgobject-2.0
    sudo mv /opt/resolve/libs/$lib.so* $d/ 2>/dev/null
end
echo "Bundle-glib deaktiviert – Resolve nutzt jetzt System-glib."
