# syntax=docker/dockerfile:1.6

# --- Stage 1: Build ---
FROM golang:1.22-alpine AS builder

WORKDIR /src

RUN apk add --no-cache \
    build-base \
    cmake \
    curl-dev \
    libssh-dev \
    openssl-dev \
    zlib-dev \
    pcre2-dev

RUN mkdir -p /out

COPY externals/lte-element-manager/go.mod externals/lte-element-manager/go.sum /src/
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download

COPY externals/lte-element-manager/third_party/libyang /src/third_party/libyang
COPY externals/lte-element-manager/third_party/libnetconf2 /src/third_party/libnetconf2

RUN --mount=type=cache,target=/tmp/libyang-build \
    --mount=type=cache,target=/root/.cache \
    cmake -S third_party/libyang -B /tmp/libyang-build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local
RUN --mount=type=cache,target=/tmp/libyang-build \
    cmake --build /tmp/libyang-build --parallel && cmake --install /tmp/libyang-build

RUN --mount=type=cache,target=/tmp/libnetconf2-build \
    --mount=type=cache,target=/root/.cache \
    cmake -S third_party/libnetconf2 -B /tmp/libnetconf2-build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_DISABLE_FIND_PACKAGE_MbedTLS=ON \
    -DLIBYANG_INCLUDE_DIR=/usr/local/include \
    -DLIBYANG_LIBRARY=/usr/local/lib/libyang.so
RUN --mount=type=cache,target=/tmp/libnetconf2-build \
    cmake --build /tmp/libnetconf2-build --parallel && cmake --install /tmp/libnetconf2-build

COPY externals/lte-element-manager/ /src/

RUN cc -O2 -o /out/netconf-server ./cmd/netconf-server/server.c \
    -I/usr/local/include -L/usr/local/lib -lnetconf2 -lyang -lssh -lssl -lcrypto -lpthread

ENV CGO_ENABLED=0
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o /out/ems-agent ./cmd/ems-agent

# --- Stage 2: Runtime ---
FROM alpine:3.19

WORKDIR /app

RUN apk add --no-cache \
    libssh \
    curl \
    pcre2 \
    openssl \
    libgcc \
    libstdc++

RUN mkdir -p /var/run/enb-metrics \
    && chmod 0777 /var/run/enb-metrics

COPY --from=builder /out/ems-agent /app/ems-agent
COPY --from=builder /out/netconf-server /app/netconf-server
COPY --from=builder /usr/local/lib/ /usr/local/lib/
COPY --from=builder /usr/local/share/yang /usr/local/share/yang
COPY --from=builder /src/yang /app/yang
COPY --from=builder /src/netconf/keys /app/netconf
RUN chmod 600 /app/netconf/hostkey /app/netconf/client_key 2>/dev/null || true

ENV LD_LIBRARY_PATH=/usr/local/lib

ENTRYPOINT ["/app/ems-agent"]
