# State 1: compile unrealircd from source
FROM alpine AS builder
MAINTAINER Travis Thompson <travis@dev-random.me>

# unrealircd version
ENV VERSION=5.0.9.1
# unrealircd compile options
ENV NICK_HISTORY=2000
ENV PERMISSIONS=0600

WORKDIR /build

# Fetch and prepare source
ADD allow-root.patch .
ADD https://www.unrealircd.org/downloads/unrealircd-${VERSION}.tar.gz /tmp/unrealircd.tgz
ADD https://www.unrealircd.org/downloads/unrealircd-${VERSION}.tar.gz.asc /tmp/unrealircd.tgz.asc
RUN apk add build-base gnupg make openssl openssl-dev argon2-dev c-ares-dev curl-dev libnsl-dev pcre2-dev
RUN gpg --keyserver keys.gnupg.net --recv-keys 0xA7A21B0A108FF4A9 &&\
    gpg --verify /tmp/unrealircd.tgz.asc /tmp/unrealircd.tgz
RUN tar -xzf /tmp/unrealircd.tgz --strip-components 1
RUN patch -p0 < allow-root.patch

# Build
RUN ./configure \
        --with-showlistmodes \
        --enable-ssl \
        --with-bindir=/usr/bin \
        --with-datadir=/data \
        --with-pidfile=/var/run/unrealircd.pid \
        --with-confdir=/conf \
        --with-modulesdir=/usr/lib/unrealircd/modules \
        --with-logdir=/var/logs \
        --with-cachedir=/data/cache \
        --with-docdir=/usr/share/man/unrealircd \
        --with-tmpdir=/data/tmp \
        --with-privatelibdir=/data/private_lib \
        --with-scriptdir=/scripts \
        --with-nick-history=${NICK_HISTORY} \
        --with-permissions=${PERMISSIONS} \
        --enable-dynamic-linking
RUN make
RUN mkdir -p /build/install/scripts &&\
    mkdir -p /build/install/data/private_lib &&\
    mkdir -p /build/install/data/tmp &&\
    mkdir -p /data/tmp
RUN make install DESTDIR=/build/install
RUN mv /build/install/scripts/unrealircd /build/install/usr/bin/unrealircdctl &&\
    rm -v /build/install/scripts/source &&\
    rm -f /build/install/scripts/*

# Stage 2: construct runtime container
FROM alpine
MAINTAINER Travis Thompson <travis@dev-random.me>

# Copy build artifacts and entrypoint
COPY --from=builder /build/install /
COPY entrypoint.sh /usr/bin/entrypoint

# Install runtime dependencies
RUN apk add --no-cache argon2 argon2-libs c-ares openssl musl pcre2 && \
    chmod +x /usr/bin/entrypoint

ENTRYPOINT /usr/bin/entrypoint