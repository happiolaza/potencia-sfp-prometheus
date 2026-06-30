#!/bin/sh
set -e

sed -i "s|^  tag: .*|  tag: ${CI_COMMIT_SHORT_SHA}|" deploy/values.yaml

git config user.name "GitLab CI"
git config user.email "ci@whitecicd"
git add deploy/values.yaml
git diff --cached --quiet || git commit -m "chore: update image tag to ${CI_COMMIT_SHORT_SHA} [skip ci]"
git push origin HEAD:"${CI_COMMIT_BRANCH}"
