#!/usr/bin/env bash
# Starts minikube and installs Argo CD. Needs Docker Desktop running first.
set -euo pipefail
minikube start --driver=docker --cpus="${CPUS:-4}" --memory="${MEMORY:-12288}" --disk-size=40g
minikube addons enable metrics-server
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
echo "Argo CD is ready. Next: ./scripts/set-repo.sh <your repo url>, push, then ./scripts/02-deploy.sh"
