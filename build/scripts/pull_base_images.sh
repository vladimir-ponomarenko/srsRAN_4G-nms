#!/usr/bin/env bash
set -euo pipefail

images=(
  "ubuntu:22.04"
  "alpine:3.19"
  "golang:1.22-alpine"
)

max_retries=${PULL_RETRIES:-5}
base_delay=${PULL_DELAY_SECONDS:-2}

pull_with_retry() {
  local image=$1
  local attempt=1
  while true; do
    echo "[pull] ${image} (attempt ${attempt}/${max_retries})"
    if docker pull "${image}"; then
      return 0
    fi
    if [[ ${attempt} -ge ${max_retries} ]]; then
      echo "[pull] failed: ${image} after ${max_retries} attempts" >&2
      return 1
    fi
    local sleep_for=$((base_delay * attempt))
    echo "[pull] retrying in ${sleep_for}s..." >&2
    sleep "${sleep_for}"
    attempt=$((attempt + 1))
  done
}

for img in "${images[@]}"; do
  pull_with_retry "${img}"
  echo
done
