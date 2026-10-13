#!/bin/sh
# Turns the "No valid subscription" check in the web UI into a no-op.
# Runs after every dpkg run (apt hook), since a proxmox-widget-toolkit
# upgrade restores the original file. Prints only when it patches.
set -eu

WEB_JS=/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

if [ -s "$WEB_JS" ] && ! grep -q NoMoreNagging "$WEB_JS"; then
    sed -i -e '/data\.status/ s/!//' -e '/data\.status/ s/active/NoMoreNagging/' "$WEB_JS"
    echo "patched $WEB_JS"
fi
