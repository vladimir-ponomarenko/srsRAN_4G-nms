# --- Stage 1: Build ---
FROM golang:1.22-alpine AS builder

WORKDIR /src
COPY externals/lte-element-manager/ /src/

ENV CGO_ENABLED=0
RUN go build -o /out/ems-agent ./test.go

# --- Stage 2: Runtime ---
FROM alpine:3.19

WORKDIR /app

RUN mkdir -p /var/run/enb-metrics \
    && chmod 0777 /var/run/enb-metrics

COPY --from=builder /out/ems-agent /app/ems-agent

ENV SOCKET_PATH=/tmp/enb_metrics.uds
ENTRYPOINT ["/app/ems-agent"]
