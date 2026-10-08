#!/system/bin/sh
# Install signed Chrome + Trichrome APKs into /data once Android is booted.
LOG=/data/local/tmp/chrome-install.log
mkdir -p /data/local/tmp
exec >> "$LOG" 2>&1

echo "=== Chrome preload: $(date) ==="

# Android is reported as booted, but give the package manager time to respond.
count=0
until pm list packages >/dev/null 2>&1; do
    count=$((count + 1))
    if [ "$count" -ge 30 ]; then
        echo "ERROR: package manager unavailable"
        exit 1
    fi
    sleep 2
done

if pm path com.android.chrome 2>/dev/null | grep -q '^package:'; then
    echo "Chrome is already installed; skipping."
    exit 0
fi

install_bundle() {
    apk_dir="$1"
    set -- "$apk_dir"/*.apk
    if [ ! -f "$1" ]; then
        echo "ERROR: missing APKs in $apk_dir"
        return 1
    fi
    if [ "$#" -eq 1 ]; then
        pm install -r "$1"
    else
        pm install-multiple -r "$@"
    fi
}

echo "Installing matching Trichrome Library..."
if ! install_bundle /system/etc/preload/trichrome; then
    echo "ERROR: Trichrome Library installation failed"
    exit 1
fi

echo "Installing Chrome..."
if ! install_bundle /system/etc/preload/chrome; then
    echo "ERROR: Chrome installation failed (check split APKs, versions and signatures)"
    exit 1
fi

if pm path com.android.chrome | grep -q '^package:'; then
    echo "SUCCESS: Chrome installed"
else
    echo "ERROR: Chrome package not registered"
    exit 1
fi
