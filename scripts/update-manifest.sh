#!/bin/sh
set -e

sed -i "s|^  tag: .*|  tag: ${CI_COMMIT_SHORT_SHA}|" deploy/values.yaml

git config user.name "GitLab CI"
git config user.email "ci@whitecicd"
git add deploy/values.yaml
git commit -m "chore: update image tag to ${CI_COMMIT_SHORT_SHA} [skip ci]"
git remote set-url origin https://gitlab-ci-token:${CI_JOB_TOKEN}@whitecicd-tt.cuyows.tcloud.ar/operaciones-red-cloud/potencia-sfp-prometheus.git
git push origin HEAD:main
