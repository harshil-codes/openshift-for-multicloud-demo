#!/usr/bin/env bash
DATA_VOLUME_NAME=ansible-data-vol
CONTAINER_BIN="${CONTAINER_BIN:-podman}"
COMPOSE_FILE="${COMPOSE_FILE:-compose.yaml}"
COMPOSE_BIN="${COMPOSE_BIN:-podman-compose}"
CONTAINER_SOCK="${CONTAINER_SOCK:-/var/run/podman/podman.sock}"

usage() {
  cat <<-EOF
[ENV_VARS] $(basename "$0")
Simulates a failover into a backup cloud provider.

ENVIRONMENT VARIABLES

  REBUILD                     Rebuilds data volumes.
  COMPOSE_BIN                 The binary to use for starting Compose services.
                              (You can also create a file called '$PWD/.compose_bin' to set this option.)
  CONTAINER_BIN               The binary to use for doing stuff in containers.
                              (You can also create a file called '$PWD/.container_bin' to set this option.)
  CONTAINER_SOCK              The socket to use for communicating with the container engine.
                              (You can also create a file called '$PWD/.container.sock' to set this option.)
EOF
}

_compose_bin() {
  if test -f "$PWD/.compose_bin"
  then
    cat "$PWD/.compose_bin"
    return 0
  fi
  echo "$COMPOSE_BIN"
}

_container_bin() {
  if test -f "$PWD/.container_bin"
  then
    cat "$PWD/.container_bin"
    return 0
  fi
  echo "$CONTAINER_BIN"
}

_container_sock() {
  if test -f "$PWD/.container_sock"
  then
    cat "$PWD/.container_sock"
    return 0
  fi
  echo "$CONTAINER_SOCK"
}
_container() {
  "$(_container_bin)" "$@"
}

create_data_volume() {
  export CONTAINER_SOCK="$(_container_sock)"
  export CONTAINER_BIN="$(_container_bin)"
  if test -n "$REBUILD"
  then
    >/dev/null _compose_bin down
    >/dev/null _container volume rm -f "$DATA_VOLUME_NAME" || true
  fi
  _container volume ls | grep -q "$DATA_VOLUME_NAME" && return 0
  _container volume create "$DATA_VOLUME_NAME" >/dev/null
}

upload_config_into_data_volume() {
  sops --decrypt "$PWD/config.yaml" |
    _container run --rm \
      -v "$DATA_VOLUME_NAME:/data" \
      -i \
      bash:5 \
      -c 'cat - > /data/config.yaml'
}

do_failover() {
  cmd="$(_compose_bin) run --rm"
  test -n "$REBUILD" && cmd="$cmd --build"
  export CONTAINER_SOCK="$(_container_sock)"
  export CONTAINER_BIN="$(_container_bin)"
  export ANSIBLE_PLAYBOOK=failover.yaml
  $cmd -e CLUSTER_KEY_FP=$(_cluster_pgp_key_fp) ansible |
    grep --color=always -Ev '(^[a-z0-9]{64}$|openshift-for-multicloud)'
}
set -e
create_data_volume
upload_config_into_data_volume
do_failover
