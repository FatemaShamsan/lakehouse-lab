#!/usr/bin/env bash
# Creates the "AWS" resources (bucket, KMS key, secret, IAM role) in LocalStack with OpenTofu.
# Run after LocalStack is up, and again any time LocalStack restarts (its data is not kept).
set -euo pipefail
cd "$(dirname "$0")/../tofu"
kubectl -n lakehouse rollout status deploy/localstack --timeout=300s
rm -f terraform.tfstate terraform.tfstate.backup      # old state is wrong after a restart: LocalStack starts empty
kubectl -n lakehouse port-forward svc/localstack 4566:4566 >/dev/null 2>&1 &
PF=$!; trap 'kill $PF' EXIT; sleep 3
tofu init -input=false
tofu apply -auto-approve -input=false
