#!/bin/sh
set -e

mkdir -p "$DOCKER_CONFIG"
printf '{"auths":{"whiteregistry.cuyows.tcloud.ar":{"auth":"YWRtaW46VGVmQXIxMjM="}}}' > "$DOCKER_CONFIG/config.json"

/kaniko/executor \
  --context "${CI_PROJECT_DIR}/app" \
  --dockerfile "${CI_PROJECT_DIR}/app/Dockerfile" \
  --skip-tls-verify-registry "$HARBOR_REGISTRY" \
  --destination "$HARBOR_REGISTRY/$DESTINATION_PROJECT/$IMAGE_NAME:$CI_COMMIT_SHORT_SHA" \
  --destination "$HARBOR_REGISTRY/$DESTINATION_PROJECT/$IMAGE_NAME:latest"
