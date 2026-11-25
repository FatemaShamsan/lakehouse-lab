#!/usr/bin/env bash
# Runs the whole pipeline once through Argo Workflows: generate orders -> Spark ingest/clean -> dbt Gold.
set -euo pipefail
WF=$(kubectl -n lakehouse create -o name -f - <<'YAML'
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata: {generateName: lakehouse-pipeline-, namespace: lakehouse}
spec: {workflowTemplateRef: {name: lakehouse-pipeline}}
YAML
)
NAME=${WF#*/}
echo "Started $NAME (the first run downloads Spark packages and dbt, so allow 5 to 10 minutes)"
for i in $(seq 1 180); do
  PHASE=$(kubectl -n lakehouse get workflow "$NAME" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  echo "  $(date +%H:%M:%S) ${PHASE:-Pending}"
  case "$PHASE" in
    Succeeded) break ;;
    Failed|Error) echo "FAILED. Last log lines of each step:"
      kubectl -n lakehouse logs -l "workflows.argoproj.io/workflow=$NAME" -c main --tail=30 --prefix; exit 1 ;;
  esac
  sleep 10
done
[ "$PHASE" = "Succeeded" ] || { echo "Timed out. Check: kubectl -n lakehouse get pods"; exit 1; }
echo "Pipeline finished. Now run ./scripts/05-query.sh"
