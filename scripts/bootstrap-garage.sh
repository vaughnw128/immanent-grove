#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-applications}"
garage_pod="${GARAGE_POD:-garage-0}"
expected_nodes="${EXPECTED_NODES:-3}"
garage_zone="${GARAGE_ZONE:-grove}"
garage_capacity="${GARAGE_CAPACITY:-250G}"
apply_version="${APPLY_VERSION:-1}"
default_secret="${DEFAULT_SECRET:-garage-default-s3}"

garage() {
  kubectl -n "$namespace" exec "$garage_pod" -- /garage "$@"
}

secret_value() {
  kubectl -n "$namespace" get secret "$default_secret" -o "jsonpath={.data.$1}" | base64 -d
}

echo "Checking Garage layout in namespace '$namespace' via pod '$garage_pod'..."

until kubectl -n "$namespace" get pod "$garage_pod" >/dev/null 2>&1; do
  echo "Waiting for $garage_pod..."
  sleep 5
done

layout="$(garage layout show)"
current_version="$(printf '%s\n' "$layout" | awk -F': ' '/Current cluster layout version/ { print $2 }')"

if [[ -z "$current_version" ]]; then
  echo "Could not determine current Garage layout version."
  printf '%s\n' "$layout"
  exit 1
fi

if [[ "$current_version" == "0" ]]; then
  for _ in $(seq 1 60); do
    status="$(garage status)"
    node_ids="$(printf '%s\n' "$status" | awk '/^[0-9a-f]{16}[[:space:]]+garage-/ { print $1 }' | sort -u)"
    node_count="$(printf '%s\n' "$node_ids" | sed '/^$/d' | wc -l | tr -d ' ')"

    if [[ "$node_count" == "$expected_nodes" ]]; then
      break
    fi

    echo "Waiting for $expected_nodes Garage nodes, saw $node_count..."
    sleep 5
  done

  if [[ "$node_count" != "$expected_nodes" ]]; then
    echo "Expected $expected_nodes Garage nodes, saw $node_count."
    printf '%s\n' "$status"
    exit 1
  fi

  echo "Assigning $node_count Garage nodes to zone '$garage_zone' with capacity '$garage_capacity'..."
  for node_id in $node_ids; do
    garage layout assign -z "$garage_zone" -c "$garage_capacity" "$node_id"
  done

  echo "Applying Garage layout version $apply_version..."
  garage layout apply --version "$apply_version"
else
  echo "Garage layout already initialized at version $current_version."
fi

echo "Ensuring default S3 key and bucket exist..."
access_key_id="$(secret_value access-key-id)"
secret_access_key="$(secret_value secret-access-key)"
bucket="$(secret_value bucket)"

if ! garage key info "$access_key_id" >/dev/null 2>&1; then
  garage key import --yes "$access_key_id" "$secret_access_key"
fi

if ! garage bucket info "$bucket" >/dev/null 2>&1; then
  garage bucket create "$bucket"
fi

garage bucket allow --read --write --owner "$bucket" --key "$access_key_id"

echo "Garage layout and default S3 bucket initialized."
