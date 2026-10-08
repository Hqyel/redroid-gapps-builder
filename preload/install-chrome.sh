
#!/system/bin/sh

LOG=/data/local/tmp/chrome-install.log
mkdir -p /data/local/tmp

install_apks() {
    DIR="$1"
    set -- "$DIR"/*.apk

    if [ ! -f "$1" ]; then
        echo "No APK files in $DIR"
        return 1
    fi

    if [ "$#" -eq 1 ]; then
        pm install -r "$1"
    else
        pm install-multiple -r "$@"
    fi
}

{
    echo "Starting Chrome preload..."

    if pm path com.android.chrome | grep -q 'package:'; then
        echo "Chrome already installed"
        exit 0
    fi

    echo "Installing Trichrome Library..."
    install_apks /system/etc/preload/trichrome || exit 1

    echo "Installing Chrome..."
    install_apks /system/etc/preload/chrome || exit 1

    echo "Checking Chrome..."
    pm path com.android.chrome

    echo "Chrome preload completed"
} >> "$LOG" 2>&1
