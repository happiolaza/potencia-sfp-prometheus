#!/bin/sh
set -e

apk add --no-cache curl

sed -i "s|^  tag: .*|  tag: ${CI_COMMIT_SHORT_SHA}|" deploy/values.yaml

git config user.name "GitLab CI"
git config user.email "ci@whitecicd"
git add deploy/values.yaml
git commit -m "chore: update image tag to ${CI_COMMIT_SHORT_SHA} [skip ci]"

curl -s --fail -X PUT --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
  "https://whitecicd-tt.cuyows.tcloud.ar/api/v4/projects/${CI_PROJECT_ID}/repository/files/deploy%2Fvalues.yaml" \
  --data-urlencode "branch=${CI_COMMIT_BRANCH}" \
  --data-urlencode "content=$(cat deploy/values.yaml)" \
  --data-urlencode "commit_message=chore: update image tag to ${CI_COMMIT_SHORT_SHA} [skip ci]"
