# Steam-Launch-Options-Vorlage für gamescope-Spiele (pro Spiel einfügen).
# Die Env-Defaults (HDR, DLSS, MangoHud, ntsync, …) kommen global aus
# ~/.config/steam-env.conf über den steam-Wrapper — hier bleibt nur noch
# gamescope + gamemoderun (CPU-Governor, X3D-Cache-CCD).
# --mangoapp ist raus: MANGOHUD=1 (global) rendert den HUD bereits im Spiel.
SteamDeck=1 gamescope -f -W 3840 -H 2160 --hdr-enabled --force-grab-cursor --adaptive-sync -- gamemoderun %command%
