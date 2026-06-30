#!/bin/sh
set -e

mkdir -p "$DOCKER_CONFIG"
printf '{"auths":{"whiteregistry.cuyows.tcloud.ar":{"auth":"%s"}}}' "$(printf '%s:%s' "${HARBOR_USER}" "${HARBOR_PASSWORD}" | base64)" > "$DOCKER_CONFIG/config.json"

/kaniko/executor \
  --context "${CI_PROJECT_DIR}/${APP_CONTEXT}" \
  --dockerfile "${CI_PROJECT_DIR}/${APP_CONTEXT}/Dockerfile" \
  --skip-tls-verify-registry "$HARBOR_REGISTRY" \
  --destination "$HARBOR_REGISTRY/$DESTINATION_PROJECT/$IMAGE_NAME:$CI_COMMIT_SHORT_SHA" \
  --destination "$HARBOR_REGISTRY/$DESTINATION_PROJECT/$IMAGE_NAME:latest"
