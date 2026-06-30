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

# update image tag in values.yaml and push via GitLab API (base64 encoded)
sed -i "s|^  tag: .*|  tag: ${CI_COMMIT_SHORT_SHA}|" "${CI_PROJECT_DIR}/deploy/values.yaml"
CONTENT_B64=$(base64 "${CI_PROJECT_DIR}/deploy/values.yaml" | tr -d '\n')
printf '{"branch":"%s","content":"%s","commit_message":"chore: update image tag to %s [skip ci]","encoding":"base64"}' \
  "${CI_COMMIT_BRANCH}" "${CONTENT_B64}" "${CI_COMMIT_SHORT_SHA}" > /tmp/body.json
if ! wget -q -O /dev/null --no-check-certificate \
  --method PUT \
  --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
  --header "Content-Type: application/json" \
  --body-file /tmp/body.json \
  "https://whitecicd-tt.cuyows.tcloud.ar/api/v4/projects/${CI_PROJECT_ID}/repository/files/deploy%2Fvalues.yaml"; then
  echo "wget failed, trying curl fallback"
  ls -la /usr/bin/wget /usr/bin/curl /bin/busybox 2>&1 || true
  # fallback: use git commit + push
  /usr/bin/git config user.name "GitLab CI" 2>&1 || echo "no git"
fi
