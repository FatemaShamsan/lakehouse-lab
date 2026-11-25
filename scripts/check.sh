#!/usr/bin/env bash
# One-screen health report.
echo "== Argo CD applications (want Synced + Healthy)"; kubectl -n argocd get applications
echo; echo "== Pods that are NOT Running or Completed"
kubectl get pods -A --no-headers | awk '$4!="Running" && $4!="Completed" && $4!="Succeeded"' || true
echo; echo "== Memory use (top 12)"; kubectl top pods -A --no-headers 2>/dev/null | sort -k4 -n -r | head -12 || echo "metrics not ready yet"
echo; echo "== Node"; kubectl top node 2>/dev/null || true
