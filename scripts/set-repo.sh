#!/usr/bin/env bash
# Writes your Git repo URL into the Argo CD files. Usage: ./scripts/set-repo.sh https://github.com/<you>/<repo>.git
set -euo pipefail
URL="${1:?usage: ./scripts/set-repo.sh https://github.com/<you>/<repo>.git}"
cd "$(dirname "$0")/.."
if ! grep -rq "REPO_URL_HERE" apps argocd; then echo "No REPO_URL_HERE found: already set. Check apps/*.yaml and argocd/root-app.yaml."; exit 0; fi
sed -i "s|REPO_URL_HERE|${URL}|g" apps/*.yaml argocd/root-app.yaml
echo "Done. Now: git add -A && git commit -m 'set repo url' && git push"
