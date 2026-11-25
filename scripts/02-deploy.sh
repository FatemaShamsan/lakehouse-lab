#!/usr/bin/env bash
# Starts the app of apps. Run AFTER you pushed this folder to GitHub (Argo CD reads from Git, not from your disk).
set -euo pipefail
cd "$(dirname "$0")/.."
if grep -rq "REPO_URL_HERE" apps argocd; then echo "Run ./scripts/set-repo.sh <url> and push first."; exit 1; fi
kubectl apply -f argocd/root-app.yaml
echo "Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
echo "Watch it: ./scripts/check.sh   (or ./scripts/open.sh argocd)"
