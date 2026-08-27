#!/bin/sh
# finalize the standalone busyagent-image repo
set -e
cd /Users/lloyd/moox/busyagent-image
rm -f /Users/lloyd/moox/busyagent/.dockerignore
printf '.git\n' > .dockerignore
git add -A
git commit -q -m "initial packaging repo for the busyagent image" || true
git log --oneline | head -2
ls -la | grep -vE "\.\.?$" | head -8
