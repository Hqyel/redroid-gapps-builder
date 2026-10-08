FROM redroid/redroid:12.0.0_mindthegapps

# Each directory contains the base APK and all required splits from the same version.
COPY apks/chrome/ /system/etc/preload/chrome/
COPY apks/trichrome/ /system/etc/preload/trichrome/

COPY --chmod=0755 preload/install-chrome.sh /system/bin/install-chrome.sh
COPY --chmod=0644 preload/install-chrome.rc /system/etc/init/install-chrome.rc
