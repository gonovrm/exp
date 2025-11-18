#!/bin/bash
set -euo pipefail

# --- CONFIGURATION ---
OFFLINE_CONTAINERS=("PCA" "PCB")
DEB_DIR_HOST="./python-debs"
DOWNLOADER_CONTAINER="py-downloader"

echo "[1/8] Removing previous temporary downloader container if it existed..."
docker rm -f "$DOWNLOADER_CONTAINER" >/dev/null 2>&1 || true

echo "[2/8] Creating temporary container with network access to download packages..."
docker run -d --name "$DOWNLOADER_CONTAINER" ubuntu:22.04 sleep infinity

echo "[3/8] Downloading Python .deb packages inside the temporary container..."
docker exec "$DOWNLOADER_CONTAINER" bash -c "
    apt-get update &&
    apt-get install -y apt-utils &&
    apt-get install -y --download-only python3
"

echo "[4/8] Copying .deb packages from the downloader container to the host..."
rm -rf "$DEB_DIR_HOST"
mkdir -p "$DEB_DIR_HOST"

# Copy only the content under /var/cache/apt/archives
docker cp "$DOWNLOADER_CONTAINER:/var/cache/apt/archives/." "$DEB_DIR_HOST"

echo "[5/8] Installing packages in offline containers: ${OFFLINE_CONTAINERS[*]}"

for CONTAINER_OFFLINE in "${OFFLINE_CONTAINERS[@]}"; do
    echo "  -> Processing container: $CONTAINER_OFFLINE"

    echo "     [5.1] Copying .deb files to $CONTAINER_OFFLINE..."
    docker cp "$DEB_DIR_HOST/." "$CONTAINER_OFFLINE:/tmp/python-debs"

    echo "     [5.2] Installing packages inside $CONTAINER_OFFLINE and creating symlinks..."
    docker exec "$CONTAINER_OFFLINE" bash -c '
        set -e
        cd /tmp/python-debs

        # Install all .deb files; if dependencies are missing, fix with apt-get -f install
        dpkg -i *.deb || apt-get -f install -y

        # Create symlinks if needed
        if [ ! -x /usr/bin/python3 ] && [ -x /usr/bin/python3.10 ]; then
            ln -s /usr/bin/python3.10 /usr/bin/python3
        fi

        if [ ! -x /usr/bin/python ] && [ -x /usr/bin/python3 ]; then
            ln -s /usr/bin/python3 /usr/bin/python
        fi
    '

    echo "  -> Container $CONTAINER_OFFLINE: installation completed."
done

echo "[6/8] Removing temporary downloader container..."
docker rm -f "$DOWNLOADER_CONTAINER" >/dev/null 2>&1 || true

echo "[7/8] (Optional) .deb packages remain in $DEB_DIR_HOST for reuse if needed."
echo "[8/8] All done."

for C in "${OFFLINE_CONTAINERS[@]}"; do
    echo
    echo "Check Python in $C with:"
    echo "    docker exec -it $C python3 --version"
    echo "    docker exec -it $C python --version"
done

