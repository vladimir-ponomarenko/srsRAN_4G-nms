FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3-pip python3-setuptools python3-wheel \
        ninja-build build-essential flex bison git cmake meson pkg-config \
        libsctp-dev libgnutls28-dev libgcrypt-dev libssl-dev \
        libmongoc-dev libbson-dev libyaml-dev libnghttp2-dev \
        libmicrohttpd-dev libcurl4-gnutls-dev libtins-dev libtalloc-dev \
        ca-certificates netbase \
    && if apt-cache show libidn-dev >/dev/null 2>&1; then \
        apt-get install -y --no-install-recommends libidn-dev; \
      else \
        apt-get install -y --no-install-recommends libidn11-dev; \
      fi \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src/open5gs
COPY externals/open5gs/ /src/open5gs/
RUN meson setup build --prefix=/usr/local \
    && ninja -C build \
    && ninja -C build install

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates iproute2 iptables iputils-ping iperf3 curl procps \
        netcat-openbsd tcpdump libsctp1 libgnutls30 libgcrypt20 libssl3 \
        libmongoc-1.0-0 libbson-1.0-0 libyaml-0-2 libnghttp2-14 \
        libmicrohttpd12 libcurl3-gnutls libtins4.0 libtalloc2 \
    && if apt-cache show libidn12 >/dev/null 2>&1; then \
        apt-get install -y --no-install-recommends libidn12; \
      else \
        apt-get install -y --no-install-recommends libidn11; \
      fi \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/ /usr/local/
COPY build/open5gs5g/entrypoint.sh /usr/local/bin/open5gs-5gc-entrypoint.sh

RUN mkdir -p /etc/open5gs /var/log/open5gs /var/lib/open5gs /etc/open5gs/hnet \
    && openssl genpkey -algorithm X25519 -out /etc/open5gs/hnet/curve25519-1.key \
    && openssl ecparam -name prime256v1 -genkey -conv_form compressed -out /etc/open5gs/hnet/secp256r1-2.key \
    && chmod +x /usr/local/bin/open5gs-5gc-entrypoint.sh \
    && ldconfig

ENTRYPOINT ["/usr/local/bin/open5gs-5gc-entrypoint.sh"]
