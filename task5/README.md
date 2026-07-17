# Production Cloud Infrastructure — E-Commerce Platform

A production-grade, multi-container deployment built with Docker Compose,
featuring load-balanced backend replicas, a monitoring stack (Prometheus +
Grafana), centralized logging, automated backups, and a zero-downtime
CI/CD pipeline via GitHub Actions.

## Architecture

```
                        GitHub
                          │
                    GitHub Actions
                          │
                    SSH Deployment
                          │
                   Ubuntu Cloud VM
                          │
                 Docker Compose Stack
                          │
                 Nginx Reverse Proxy
                    │           │
               Frontend     Backend (x2 replicas)
                                │
                        ┌───────┴───────┐
                      Redis          PostgreSQL
                                │
                          Docker Network
                                │
                     Prometheus + Grafana
                                │
                       Monitoring Dashboard
```

## Repository Structure

```
project/
├── frontend/            Static site (Dockerfile + nginx:alpine)
├── backend/              Node.js/Express API (Dockerfile, health + metrics endpoints)
├── nginx/                 Reverse proxy config (load balancing, gzip, caching)
├── monitoring/
│   ├── prometheus/        Scrape configuration
│   └── grafana/            Provisioned datasource + starter dashboard
├── database/               PostgreSQL init script (schema + seed data)
├── docker-compose.yml
├── .env.example
├── backup.sh
├── restore.sh
├── deploy.sh
├── healthcheck.sh
├── README.md
└── .github/workflows/deploy.yml
```

## Getting Started

1. Copy the environment template and set real secrets:
   ```bash
   cp .env.example .env
   ```
2. One-command deployment:
   ```bash
   docker compose up -d --build
   ```
3. Access the stack:
   - App: `http://localhost:8080`
   - Grafana: `http://localhost:3000` (default admin/admin — change in `.env`)
   - Prometheus: `http://localhost:9090` internal to the backend network (expose a port in compose if external access is needed)

## Services

| Service      | Role                                             |
|--------------|--------------------------------------------------|
| nginx        | Reverse proxy, load balancer, gzip, caching       |
| frontend     | Static UI                                         |
| backend_1/2  | Express API, `/health` and `/metrics` endpoints   |
| postgres     | Primary datastore                                 |
| redis        | Cache layer for API responses                     |
| prometheus   | Metrics collection                                |
| grafana      | Dashboards                                        |
| node-exporter| Host CPU/RAM/disk/network metrics                 |
| cadvisor     | Per-container resource metrics                    |

## Monitoring

Prometheus scrapes: application metrics from both backend replicas,
host metrics via `node-exporter`, and per-container metrics via
`cadvisor`. Grafana is pre-provisioned with the Prometheus datasource
and a starter "Infrastructure Overview" dashboard (CPU, memory, request
latency, load average).

## Logging

All containers use Docker's default `json-file` log driver. View logs
centrally with:
```bash
docker compose logs -f              # all services
docker compose logs -f backend_1    # single service
docker compose logs -f nginx
```
For production, consider forwarding these to a centralized log
aggregator (e.g. Loki, ELK) — the `json-file` driver keeps everything
locally discoverable in the meantime via `docker inspect --format
'{{.LogPath}}' <container>`.

## Backup & Recovery

```bash
./backup.sh [retention_days]   # default retention: 7 days
./restore.sh ./backups/postgres_<timestamp>.sql.gz
```
`backup.sh` dumps PostgreSQL with `pg_dumpall`, snapshots Redis via
`SAVE` + RDB copy, compresses both, timestamps them, and deletes
backups older than the retention window.

## Zero-Downtime Deployment

`deploy.sh` implements a rolling update:
1. Pulls latest code and rebuilds images.
2. Updates supporting services (db, cache, monitoring, frontend).
3. Updates `backend_1`, waits for Docker's healthcheck to report
   `healthy` — traffic keeps flowing to `backend_2` via Nginx in the
   meantime.
4. Repeats for `backend_2`.
5. Updates Nginx last, then runs `healthcheck.sh` as a final
   full-stack verification.
6. If any replica fails its health check, the script attempts an
   automatic rollback to the previous image tag and exits non-zero.

This is a rolling-update pattern; the same health-gated approach can be
extended into blue-green (spin up a full parallel stack, switch Nginx
upstream, tear down the old stack) or canary (route a small percentage
of traffic to the new version before a full rollout) as traffic and
risk tolerance grow.

## CI/CD (GitHub Actions)

`.github/workflows/deploy.yml` builds and smoke-tests all three
images on every push to `main`, then SSHes into the target VM and runs
`deploy.sh`, followed by `healthcheck.sh` to verify the rollout.

Required repository secrets:
- `DEPLOY_HOST` — VM IP or hostname
- `DEPLOY_USER` — SSH user
- `DEPLOY_SSH_KEY` — private key with access to the VM
- `DEPLOY_PATH` — path to this repo on the VM

## Security Checklist

- [x] Backend container runs as a non-root user
- [x] Secrets isolated in `.env` (not committed; `.env.example` only)
- [x] Only Nginx (80) and Grafana (3000) ports are exposed to the host; all
      other services communicate over internal Docker networks
- [x] Two isolated networks: `frontend-network` (public-facing) and
      `backend-network` (data layer), limiting blast radius
- [x] Healthchecks defined for every custom-built service
- [ ] TODO before internet-facing production use: TLS termination
      (Let's Encrypt/Certbot or a managed load balancer), image
      vulnerability scanning (e.g. `docker scout` or Trivy) in CI,
      and firewall rules (ufw/security groups) restricting SSH to
      known IPs

## Performance Optimization

- Multi-stage Docker build for the backend keeps the production image
  small (only `node_modules` and source are copied into the final
  layer, dev dependencies never included).
- `docker-compose.yml` sets CPU and memory limits per service to
  prevent noisy-neighbor resource contention.
- Nginx gzip compression and short-lived proxy caching (`api_cache`)
  reduce backend load and payload size.
- Redis caches `/api/products` responses for 30 seconds to reduce
  PostgreSQL read load.

## Next Step

This Docker Compose stack is a deliberate bridge toward Kubernetes.
The natural next task is migrating this same application into a
managed Kubernetes cluster (EKS/GKE/Minikube) using Deployments,
Services, Ingress, ConfigMaps, Secrets, Helm, and Horizontal Pod
Autoscaling.
