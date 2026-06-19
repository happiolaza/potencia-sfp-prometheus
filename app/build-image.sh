#!/bin/sh
set -e

IMAGE_NAME="happiolaza/potencia-sfp-prometehus-cm:1.4"

if command -v podman >/dev/null 2>&1; then
  builder=podman
else
  builder=docker
fi

$builder build -t "$IMAGE_NAME" .

echo "Built image: $IMAGE_NAME"
