# Buildstage
FROM ghcr.io/linuxserver/baseimage-alpine:3.17 as buildstage

# set NZBGET version
#ARG NZBGET_RELEASE

RUN \
  echo "**** install build packages ****" && \
  apk add \
    g++ \
    gcc \
    git \
    libxml2-dev \
    libxslt-dev \
    make \
    automake \
    autoconf \
    ncurses-dev \
    openssl-dev && \
  echo "**** build nzbget ****" && \
  #  NOT CURRENTLY WORKING - NZBGET-NG NO RELEASES
  #if [ -z ${NZBGET_RELEASE+x} ]; then \
  #  NZBGET_RELEASE=$(curl -sX GET "https://api.github.com/repos/nzbget/nzbget/releases/latest" \
  #    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  #fi && \
  mkdir -p /app/nzbget && \
  git clone https://github.com/nzbget-ng/nzbget.git nzbget && \
  cd nzbget/ && \
  autoreconf --install && \
  #git checkout ${NZBGET_RELEASE} && \
  #git cherry-pick -n fa57474d && \
  ./configure \
    bindir='${exec_prefix}' && \
  make && \
  make prefix=/app/nzbget install && \
  sed -i \
    -e "s#^MainDir=.*#MainDir=/downloads#g" \
    -e "s#^ScriptDir=.*#ScriptDir=$\{MainDir\}/scripts#g" \
    -e "s#^WebDir=.*#WebDir=$\{AppDir\}/webui#g" \
    -e "s#^ConfigTemplate=.*#ConfigTemplate=$\{AppDir\}/webui/nzbget.conf.template#g" \
    -e "s#^UnrarCmd=.*#UnrarCmd=$\{AppDir\}/unrar#g" \
    -e "s#^SevenZipCmd=.*#SevenZipCmd=$\{AppDir\}/7za#g" \
    -e "s#^CertStore=.*#CertStore=$\{AppDir\}/cacert.pem#g" \
    -e "s#^CertCheck=.*#CertCheck=yes#g" \
    -e "s#^DestDir=.*#DestDir=$\{MainDir\}/completed#g" \
    -e "s#^InterDir=.*#InterDir=$\{MainDir\}/intermediate#g" \
    -e "s#^LogFile=.*#LogFile=$\{MainDir\}/nzbget.log#g" \
    -e "s#^AuthorizedIP=.*#AuthorizedIP=127.0.0.1#g" \
  /app/nzbget/share/nzbget/nzbget.conf && \
  mv /app/nzbget/share/nzbget/webui /app/nzbget/ && \
  cp /app/nzbget/share/nzbget/nzbget.conf /app/nzbget/webui/nzbget.conf.template && \
  ln -s /usr/bin/7za /app/nzbget/7za && \
  ln -s /usr/bin/unrar /app/nzbget/unrar && \
  cp /nzbget/pubkey.pem /app/nzbget/pubkey.pem && \
  curl -o \
    /app/nzbget/cacert.pem -L \
    "https://curl.haxx.se/ca/cacert.pem"

# Runtime Stage
FROM ghcr.io/linuxserver/baseimage-alpine:3.17

ARG UNRAR_VERSION=6.1.7
# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Riddlecp version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="riddlecp"

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --upgrade --virtual=build-dependencies \
    cargo \
    g++ \
    gcc \
    libc-dev \
    libffi-dev \
    libxml2-dev \
    libxslt-dev \
    make \
    openssl-dev \
    python3-dev && \
  echo "**** install packages ****" && \
  apk add --no-cache \
    libxml2 \
    libxslt \
    openssl \
    p7zip \
    py3-pip \
    python3 && \
  echo "**** install unrar from source ****" && \
  mkdir /tmp/unrar && \
  curl -o \
    /tmp/unrar.tar.gz -L \
    "https://www.rarlab.com/rar/unrarsrc-${UNRAR_VERSION}.tar.gz" && \  
  tar xf \
    /tmp/unrar.tar.gz -C \
    /tmp/unrar --strip-components=1 && \
  cd /tmp/unrar && \
  make && \
  install -v -m755 unrar /usr/bin && \
  echo "**** install python packages ****" && \
  pip3 install --no-cache-dir -U \
    pip \
    wheel && \
  pip install --no-cache-dir --find-links https://wheel-index.linuxserver.io/alpine-3.16/ \
    apprise \
    chardet \
    lxml \
    py7zr \
    pynzbget \
    rarfile \
    six && \
  #ln -s /usr/bin/python3 /usr/bin/python && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /root/.cache \
    /root/.cargo \
    /tmp/*

# add local files and files from buildstage
COPY --from=buildstage /app/nzbget /app/nzbget
COPY root/ /

# ports and volumes
VOLUME /config
EXPOSE 6789
