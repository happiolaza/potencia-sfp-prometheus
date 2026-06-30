#!/bin/sh
set -e

sed -i "s|^  tag: .*|  tag: ${CI_COMMIT_SHORT_SHA}|" deploy/values.yaml

/usr/bin/git config user.name "GitLab CI"
/usr/bin/git config user.email "ci@whitecicd"
/usr/bin/git add deploy/values.yaml
/usr/bin/git diff --cached --quiet || /usr/bin/git commit -m "chore: update image tag to ${CI_COMMIT_SHORT_SHA} [skip ci]"
/usr/bin/git push origin HEAD:"${CI_COMMIT_BRANCH}"
