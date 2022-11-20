#!/usr/bin/env bash

set -e

docker build -t nextpvr .
docker run -it --rm \
    --name nextpvr \
    -p 8866:8866 \
    --device /dev/fuse \
    --cap-add SYS_ADMIN \
    -e RCLONE_CONFIG=/rclone/rclone.conf \
    -v "$HOME/.config/rclone:/rclone" \
    -e RCLONE_MOUNT_CACHE_DIR=/tmp/cache \
    -v /tmp/cache:/tmp/cache \
    -e MOUNT_SOURCE=file:/source \
    -v "$(pwd)/recordings:/source" \
    -v "$(pwd)/config:/config" \
    nextpvr
