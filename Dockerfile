FROM ghcr.io/jonohill/docker-s6-package:3.1.2.1 AS s6
FROM rclone/rclone:1.61.1 AS rclone

FROM curlimages/curl AS download

WORKDIR /home/curl_user

RUN mkdir nextpvr && \
    curl -fL -o nextpvr.zip https://nextpvr.com/stable/linux/NPVR.zip && \
    unzip nextpvr.zip -d nextpvr
    

FROM mcr.microsoft.com/dotnet/aspnet:6.0.14

RUN apt-get update && apt-get install -y \
        dtv-scan-tables \
        dvb-tools \
        ffmpeg \
        fuse \
        libc6  \
        libc6-dev \
        libdvbv5-0 \
        libgdiplus \
        libmediainfo-dev \
        mediainfo \
        python3 \
        python3-magic \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r nextpvr && useradd --no-log-init -r -g nextpvr nextpvr

COPY --from=s6 / /
COPY root/ /
COPY --from=download --chown=nextpvr:nextpvr /home/curl_user/nextpvr /nextpvr
COPY scripts /nextpvr/custom_scripts

WORKDIR /nextpvr
RUN find . -name DeviceHostLinux -exec chmod 755 {} \;

ENV NEXTPVR_DATADIR_USERDATA=/config/
ENV RCLONE_CONFIG=/config/rclone.conf

EXPOSE 8866

ENTRYPOINT ["/init"]
