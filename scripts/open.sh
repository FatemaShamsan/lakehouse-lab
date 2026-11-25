#!/usr/bin/env bash
# Opens a web UI through port-forward. Usage: ./scripts/open.sh argocd|grafana|workflows|trino
set -euo pipefail
case "${1:-}" in
  argocd)    echo "https://localhost:8080   user: admin"; kubectl -n argocd port-forward svc/argocd-server 8080:443 ;;
  grafana)   echo "http://localhost:3000   user: admin  password: lakehouse-demo"; kubectl -n monitoring port-forward svc/grafana 3000:80 ;;
  workflows) echo "http://localhost:2746"; kubectl -n argo port-forward svc/argo-workflows-server 2746:2746 ;;
  trino)     echo "http://localhost:8082   user: any name"; kubectl -n lakehouse port-forward svc/trino 8082:8080 ;;
  *) echo "usage: ./scripts/open.sh argocd|grafana|workflows|trino"; exit 1 ;;
esac
