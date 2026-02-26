# --- Stage 1: Build ---
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    cmake \
    git \
    build-essential \
    libfftw3-dev \
    libmbedtls-dev \
    libboost-program-options-dev \
    libconfig++-dev \
    libsctp-dev \
    libzmq3-dev \
    curl

WORKDIR /src
RUN git clone https://github.com/vladimir-ponomarenko/srsRAN_4G.git .

WORKDIR /src/build
RUN cmake ../ && make -j$(nproc) && make install

# --- Stage 2: Production Image ---
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    libfftw3-3 \
    libmbedtls14 \
    libboost-program-options1.74.0 \
    libconfig++9v5 \
    libsctp1 \
    libzmq5 \
    iproute2 \
    iptables \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/local/lib/ /usr/local/lib/
RUN ldconfig

COPY build/scripts/*.sh /opt/srsran/
RUN chmod +x /opt/srsran/*.sh

WORKDIR /etc/srsran
ENTRYPOINT ["stdbuf", "-o", "L"]