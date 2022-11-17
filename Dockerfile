FROM curlimages/curl AS download

WORKDIR /home/curl_user

COPY NPVR.zip nextpvr.zip

RUN mkdir nextpvr && \
    # curl -fL -o /tmp/nextpvr/nextpvr.zip https://nextpvr.com/stable/linux/NPVR.zip && \
    unzip nextpvr.zip -d nextpvr
    

FROM mcr.microsoft.com/dotnet/aspnet:6.0.11

RUN apt-get update && apt-get install -y \
        dtv-scan-tables \
        dvb-tools \
        ffmpeg \
        libc6  \
        libc6-dev \
        libdvbv5-0 \
        libgdiplus \
        libmediainfo-dev \
        mediainfo \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r nextpvr && useradd --no-log-init -r -g nextpvr nextpvr

COPY --from=download --chown=nextpvr:nextpvr /home/curl_user/nextpvr /nextpvr
WORKDIR /nextpvr
RUN find . -name DeviceHostLinux -exec chmod 755 {} \;

EXPOSE 8866
ENTRYPOINT ["dotnet", "NextPVRServer.dll"]
