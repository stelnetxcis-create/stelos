# Auto start Hyprland on tty1
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
 clear
 mkdir -p ~/.cache

 # Start gnome-keyring fresh for this session. TTY autologin skips the
 # password prompt PAM normally uses to auto-unlock it, so this just
 # starts the daemon here; actual unlocking is handled separately below.
 eval $(gnome-keyring-daemon --start --components=secrets,pkcs11,ssh)
 export GNOME_KEYRING_CONTROL SSH_AUTH_SOCK

 exec start-hyprland > ~/.cache/hyprland.log 2>&1
fi
