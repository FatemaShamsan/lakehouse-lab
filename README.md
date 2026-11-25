# lakehouse-lab

A lakehouse on minikube, built the way your company builds on EKS: everything is deployed from Git by Argo CD.

```
PostgreSQL (orders)  ->  Spark (ingest + clean)  ->  Iceberg tables on S3 (LocalStack)  ->  Trino  ->  you
   ^ event generator        Bronze -> Silver (+Quarantine)         Gold built by dbt
   all three steps run as one Argo Workflows pipeline.   Grafana + Prometheus watch the cluster.
```

**Status: checked offline, not yet run on a cluster.** The YAML, kustomize build, Kubernetes schemas, dbt project
and generator logic were validated. Starting the cluster was not possible where this was built, so expect to fix a
thing or two on the first run. Send the error and it will be fixed.

## You need (Windows 11, no admin rights needed for these if already installed)
Docker Desktop (running, 12 to 14 GB memory in Settings > Resources), minikube, kubectl, git, OpenTofu (`tofu`).
**Run every script in Git Bash** (or the VS Code bash terminal), not PowerShell.

## Steps
0. **Start clean.** If you have the old cluster: `minikube delete`. (Its data is disposable.)
1. **New GitHub repo.** Create an empty **public** repo (Argo CD then needs no password). Example: `lakehouse-lab`.
2. **Push this folder to it.** In Git Bash, inside this folder:
   ```
   ./scripts/set-repo.sh https://github.com/<you>/lakehouse-lab.git
   git init -b main
   git add -A
   git commit -m "lakehouse lab"
   git remote add origin https://github.com/<you>/lakehouse-lab.git
   git push -u origin main
   ```
3. `./scripts/01-start-cluster.sh`   (minikube + Argo CD, about 5 minutes)
4. `./scripts/02-deploy.sh`          (starts the app of apps; prints the Argo CD password)
5. `./scripts/check.sh`             Repeat until every application is **Synced** and **Healthy** (10 to 15 minutes; Trino and Argo Workflows are the slow ones).
6. `./scripts/03-create-aws.sh`     Creates the `warehouse` bucket, KMS key, secret and IAM role in LocalStack with OpenTofu.
7. `./scripts/04-run-pipeline.sh`   Runs generate -> ingest -> dbt through Argo Workflows. **First run: 5 to 10 minutes** (downloads Spark packages and dbt).
8. `./scripts/05-query.sh`          Expected after the first run:
   - bronze_rows = **10**, silver_rows = **7**
   - quarantine = **3** rows: order 5 and 10 "customer is null", order 7 "amount is not a number"
   - gold.daily_revenue = **2 rows**: yesterday 3 orders / 62.5, today 4 orders / 90.0
   Each further run adds 10 raw rows (counts roughly double).
9. Look around: `./scripts/open.sh argocd | grafana | workflows | trino`
10. When it all works: `./scripts/pin-versions.sh`, then commit and push. This replaces `"*"` chart versions with the ones that worked.

## After a restart (minikube stop/start, or Docker restart)
LocalStack and the Iceberg catalog keep their data in memory, so the lake is empty after a restart.
Run `./scripts/03-create-aws.sh` and `./scripts/04-run-pipeline.sh` again. PostgreSQL keeps its data.

## What each folder is
| Folder | Contents |
| --- | --- |
| `argocd/`, `apps/` | Argo CD app of apps. One file per thing it deploys (Envoy Gateway, Kyverno, Argo Workflows, Trino, Prometheus, Grafana, plus two apps that deploy the folders below). |
| `platform/` | Plain manifests: namespace, LocalStack, Iceberg REST catalog, PostgreSQL, Gateway, Kyverno policy, workflow permissions. |
| `workloads/` | The pipeline: generator, Spark job, dbt project, the Argo Workflows DAG and its (suspended) nightly schedule. |
| `tofu/` | OpenTofu code that creates the AWS-style resources in LocalStack. |
| `scripts/` | The numbered steps above, plus `check.sh`, `open.sh`, `pin-versions.sh`. |

## Demo: self-healing (safe)
`kubectl -n monitoring scale deploy/grafana --replicas=0` then watch Argo CD bring it back.
(Do not do this to PostgreSQL, LocalStack or the catalog: the pipeline needs them.)

## If something fails
| Symptom | Do this |
| --- | --- |
| An app is not Synced | Click it in Argo CD, read the red error, send it to me. |
| Pod Pending or OOMKilled | `./scripts/check.sh` shows memory. Set `server.workers: 0` in `apps/20-trino.yaml` (coordinator only), push. |
| Workflow Failed | `./scripts/04-run-pipeline.sh` prints the last log lines of each step. Send them. |
| `kubectl` connection refused | Docker Desktop is not running, or minikube is stopped: `minikube start`. |

## Not included on purpose (next phases)
Superset, External Secrets, Polaris. Add them after this works, one at a time.

## Licence note
LocalStack is pinned to 4.14, the last version I know of that needs no account. Newer images need a free token.
Demo passwords in this folder are fake. Never commit real ones.
