#!/usr/bin/env sh
set -eu

DEFAULT_DELAY_SEC="${RADIO_PAIR_DELAY_SEC:-10}"
HEALTH_TIMEOUT_SEC="${RADIO_HEALTH_TIMEOUT_SEC:-120}"
EVENT_RECONNECT_SEC="${RADIO_EVENTS_RECONNECT_SEC:-2}"
ENFORCE_INTERVAL_SEC="${RADIO_ENFORCE_INTERVAL_SEC:-2}"

log() {
  echo "$*"
}

inspect_label() {
  container="$1"
  key="$2"
  docker inspect -f "{{ index .Config.Labels \"$key\" }}" "$container" 2>/dev/null || true
}

normalize_label() {
  value="$1"
  case "$value" in
    ""|"<no value>"|"null"|"NULL")
      echo ""
      ;;
    *)
      echo "$value"
      ;;
  esac
}

inspect_running() {
  container="$1"
  docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true
}

inspect_health() {
  container="$1"
  docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null || true
}

stop_container() {
  name="$1"
  if [ "$(inspect_running "$name")" = "true" ]; then
    log "force killing dependent ${name}"
    docker kill --signal KILL "$name" >/dev/null 2>&1 || true
    docker stop -t 0 "$name" >/dev/null 2>&1 || true
  fi
}

start_container() {
  name="$1"
  if [ "$(inspect_running "$name")" = "true" ]; then
    return 0
  fi
  log "starting dependent ${name}"
  docker start "$name" >/dev/null 2>&1 || true
}

wait_primary_ready() {
  primary="$1"
  i=0
  while [ "$i" -lt "$HEALTH_TIMEOUT_SEC" ]; do
    running="$(inspect_running "$primary")"
    health="$(inspect_health "$primary")"
    if [ "$running" = "true" ] && { [ "$health" = "healthy" ] || [ "$health" = "none" ]; }; then
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  log "timeout waiting primary ${primary} readiness (running=$(inspect_running "$primary"), health=$(inspect_health "$primary"))"
  return 1
}

is_primary_ready() {
  primary="$1"
  running="$(inspect_running "$primary")"
  health="$(inspect_health "$primary")"
  [ "$running" = "true" ] && { [ "$health" = "healthy" ] || [ "$health" = "none" ]; }
}

is_primary_starting() {
  primary="$1"
  running="$(inspect_running "$primary")"
  health="$(inspect_health "$primary")"
  [ "$running" = "true" ] && [ "$health" = "starting" ]
}

list_primaries() {
  for name in $(docker ps -a --format '{{.Names}}'); do
    [ -n "$name" ] || continue
    role="$(normalize_label "$(inspect_label "$name" "radio.supervisor.role")")"
    enabled="$(normalize_label "$(inspect_label "$name" "radio.supervisor.enabled")")"
    dependents="$(normalize_label "$(inspect_label "$name" "radio.supervisor.dependents")")"
    if [ "$role" = "primary" ] && [ "$enabled" = "true" ] && [ -n "$dependents" ]; then
      echo "$name"
    fi
  done
}

for_each_dependent() {
  list="$1"
  action="$2"
  oldifs="$IFS"
  IFS=','
  for raw in $list; do
    dep="$(echo "$raw" | tr -d '[:space:]')"
    [ -n "$dep" ] || continue
    "$action" "$dep"
  done
  IFS="$oldifs"
}

enforce_primary_dependent_policy() {
  for primary in $(list_primaries); do
    [ -n "$primary" ] || continue
    dependents="$(normalize_label "$(inspect_label "$primary" "radio.supervisor.dependents")")"
    [ -n "$dependents" ] || continue
    if is_primary_ready "$primary"; then
      for_each_dependent "$dependents" start_container
      continue
    fi
    if ! is_primary_starting "$primary"; then
      for_each_dependent "$dependents" stop_container
    fi
  done
}

handle_event() {
  status="$1"
  name="$2"
  role="$(normalize_label "$(inspect_label "$name" "radio.supervisor.role")")"
  [ "$role" = "primary" ] || return 0

  enabled="$(normalize_label "$(inspect_label "$name" "radio.supervisor.enabled")")"
  [ "$enabled" = "true" ] || return 0

  dependents="$(normalize_label "$(inspect_label "$name" "radio.supervisor.dependents")")"
  [ -n "$dependents" ] || return 0

  delay="$(normalize_label "$(inspect_label "$name" "radio.supervisor.start_delay_sec")")"
  [ -n "$delay" ] || delay="$DEFAULT_DELAY_SEC"

  case "$status" in
    die|stop|kill)
      for_each_dependent "$dependents" stop_container
      ;;
    restart)
      for_each_dependent "$dependents" stop_container
      ;;
    start)
      for_each_dependent "$dependents" stop_container
      if wait_primary_ready "$name"; then
        log "primary ${name} ready, delaying ${delay}s before dependents start"
        sleep "$delay"
      fi
      for_each_dependent "$dependents" start_container
      ;;
  esac
}

reconcile_existing_primaries() {
  for primary in $(list_primaries); do
    [ -n "$primary" ] || continue
    if is_primary_ready "$primary"; then
      handle_event "start" "$primary"
    else
      running="$(inspect_running "$primary")"
      health="$(inspect_health "$primary")"
      log "primary ${primary} not ready at startup (running=${running}, health=${health}); defer decision to policy loop"
    fi
  done
}

log "initial reconcile for labeled primary containers"
reconcile_existing_primaries

log "watching labeled primary container events"
(
  while true; do
    enforce_primary_dependent_policy
    sleep "${ENFORCE_INTERVAL_SEC}"
  done
) &

while true; do
  docker events \
    --filter type=container \
    --filter label=radio.supervisor.role=primary \
    --filter label=radio.supervisor.enabled=true \
    --filter event=start \
    --filter event=restart \
    --filter event=die \
    --filter event=stop \
    --filter event=kill \
    --format '{{.Status}} {{.Actor.Attributes.name}}' |
  while IFS=' ' read -r status name; do
    [ -n "${status}" ] || continue
    [ -n "${name}" ] || continue
    log "event: ${name} ${status}"
    handle_event "$status" "$name"
  done
  log "docker events stream ended; reconnecting in ${EVENT_RECONNECT_SEC}s"
  sleep "${EVENT_RECONNECT_SEC}"
done
