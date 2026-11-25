#!/usr/bin/env bash
# Shows what is in each layer. For an interactive shell instead:  ./scripts/05-query.sh shell
set -euo pipefail
POD=$(kubectl -n lakehouse get pod -l app.kubernetes.io/component=coordinator -o jsonpath='{.items[0].metadata.name}')
if [ "${1:-}" = "shell" ]; then exec kubectl -n lakehouse exec -it "$POD" -- trino --catalog lakehouse; fi
q() { echo; echo ">>> $1"; kubectl -n lakehouse exec "$POD" -- trino --catalog lakehouse --execute "$1"; }
q "SELECT count(*) AS bronze_rows FROM bronze.orders_raw"
q "SELECT count(*) AS silver_rows FROM silver.orders"
q "SELECT order_id, customer, amount, reason FROM silver.orders_quarantine ORDER BY order_id"
q "SELECT * FROM gold.daily_revenue ORDER BY order_date"
