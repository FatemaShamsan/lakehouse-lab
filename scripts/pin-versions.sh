#!/usr/bin/env bash
# After everything works: writes the chart versions that Argo CD actually installed into apps/*.yaml,
# replacing "*" (latest). Then commit and push. This stops a surprise upgrade from breaking you later.
set -euo pipefail
cd "$(dirname "$0")/.."
for pair in kyverno:00-kyverno trino:20-trino prometheus:30-prometheus grafana:30-grafana argo-workflows:01-argo-workflows; do
  name=${pair%%:*}; file="apps/${pair##*:}.yaml"
  rev=$(kubectl -n argocd get application "$name" -o jsonpath='{.status.sync.revision}')
  if [ -n "$rev" ]; then sed -i "s|targetRevision: \"\*\".*|targetRevision: \"$rev\"|" "$file"; echo "$name -> $rev"; fi
done
echo "Now: git add -A && git commit -m 'pin chart versions' && git push"
