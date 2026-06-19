#!/bin/sh
set -e

sed -i "s|^  tag: .*|  tag: ${CI_COMMIT_SHORT_SHA}|" deploy/values.yaml

git config user.name "GitLab CI"
git config user.email "ci@whitecicd"
git add deploy/values.yaml
git commit -m "chore: update image tag to ${CI_COMMIT_SHORT_SHA} [skip ci]"
git push https://gitlab+deploy-token-1:${GIT_DEPLOY_TOKEN}@whitecicd-tt.cuyows.tcloud.ar/operaciones-red-cloud/potencia-sfp-prometheus.git HEAD:main
