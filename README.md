# redroid Android 12 + GApps + Chrome (ARM64)

Build a personal ARM64 redroid image with MindTheGapps, Chrome and matching
Trichrome Library using GitHub Actions, then publish it to GitHub Container Registry.

**Base image:** `redroid/redroid:12.0.0-latest` (NOT `_64only-latest`).
The non-`64only` variant was chosen because it exposed a working
`OMX.google.h264.encoder` for scrcpy on the target Oracle ARM instance.

## Before running the workflow

This public repository deliberately contains **no Google/Chrome APKs**.
Obtain original, appropriately licensed, mutually compatible signed Chrome and
Trichrome Library APKs for **Android 12, ARM64**. If Chrome is distributed as
split APKs, retain every required split, not just `base.apk`.
Use files from a source you trust; do not use modified/re-signed packages.

Make a ZIP archive with this exact layout:

```text
chrome-bundle.zip
  chrome/
    base.apk
    split_config.arm64_v8a.apk     # example; use actual split names
    ...                           # any other required Chrome splits
  trichrome/
    base.apk
    ...                           # any required Trichrome splits
```

Use a matching Chrome and Trichrome Library version. The build validates the
archive structure, SHA-256 and basic ZIP/APK file format. **It cannot verify
APK publisher signatures or guarantee runtime compatibility.**

Host this ZIP at a direct-download HTTPS URL accessible from a GitHub Actions
runner. If the URL is signed or temporary, refresh it before each build.

Get its SHA-256 locally (Windows PowerShell):

```powershell
(Get-FileHash .\chrome-bundle.zip -Algorithm SHA256).Hash.ToLower()
```

In **Settings → Secrets and variables → Actions**, create repository secrets:

- `CHROME_BUNDLE_URL` — direct HTTPS URL for the ZIP.
- `CHROME_BUNDLE_SHA256` — its 64-character SHA-256 hex digest.

The URL is kept in a secret because it may grant access to private files.
Never commit the ZIP/APKs or share them in a public GitHub release.

## Build and publish

Visit **Actions → Build redroid Android 12 + GApps + Chrome → Run workflow**.
The workflow uses GitHub's native `ubuntu-24.04-arm` runner to:

1. Download the user-supplied Chrome bundle and check SHA-256.
2. Use [ayasa520/redroid-script](https://github.com/ayasa520/redroid-script)
   to integrate MindTheGapps into the **non-64only** Android 12 image.
3. Add the Chrome APKs and an Android init service that installs them to
   `/data` the first time Android boots.
4. Push `ghcr.io/hqyel/redroid12-gapps-chrome:arm64` to GHCR.

The upstream script currently uses **MindTheGapps 12.1** for Android 12;
actual Play Store functionality needs testing on the target image. Google Play
Protect certification and Play Integrity are **not** guaranteed.

**Important:** Your repository is public. Review GHCR package visibility and
Google software redistribution terms; keep the package private and do not
publicly redistribute proprietary APKs without rights to do so.

## Oracle ARM64 Docker Compose

Keep the binder devices and your existing `custom_bridge` network. Use a
**new data directory** for first-boot testing; do not overwrite working data.

```yaml
services:
  redroid:
    image: ghcr.io/hqyel/redroid12-gapps-chrome:arm64
    container_name: redroid12
    privileged: true
    restart: unless-stopped
    ports:
      - "127.0.0.1:42968:5555"
    volumes:
      - ./data-gapps-chrome:/data
      - /dev/binder:/dev/binder
      - /dev/hwbinder:/dev/hwbinder
      - /dev/vndbinder:/dev/vndbinder
    command:
      - androidboot.redroid_gpu_mode=guest
      - androidboot.use_memfd=1
      - androidboot.redroid_width=720
      - androidboot.redroid_height=1280
      - androidboot.redroid_dpi=320
    networks:
      custom_bridge:
        ipv4_address: 10.10.10.21

networks:
  custom_bridge:
    external: true
```

For private GHCR packages, authenticate with a PAT (classic) with
`read:packages` before `docker compose pull`.

After boot, inspect:

```bash
docker exec redroid12 pm path com.android.chrome
docker exec redroid12 pm path com.android.vending
docker exec redroid12 cat /data/local/tmp/chrome-install.log
```

Connect by SSH tunnel and scrcpy as before:

```powershell
ssh -i .\private.key -N -L 42968:127.0.0.1:42968 root@YOUR_ORACLE_IP
adb connect 127.0.0.1:42968
scrcpy -s 127.0.0.1:42968 --no-audio -m 720
```

If Chrome fails to install, inspect `chrome-install.log` first: common causes
are incomplete split APK sets, Chrome/Trichrome version mismatch, wrong ABI or
an APK requiring a newer Android API. Do not modify your previous `./data`.
