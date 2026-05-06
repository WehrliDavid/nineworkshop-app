# NKE Workshop - Hands-On Materials

Workshop materials for new Kubernetes and NKE (Nine Kubernetes Engine) users.

## Prerequisites

- NKE cluster running with `kubectl` access configured
- ArgoCD deployed
- Container registry available
- ingress-nginx controller deployed
- Loki + Grafana for observability

## Repository Structure

```
.
├── kubectl-demo.sh          # kubectl commands to run during the demo
├── demo-app/                # Example Python app
│   ├── app.py               # Flask app (reads ConfigMap, writes to PVC)
│   ├── Dockerfile
│   └── requirements.txt
├── helm/workshop-app/       # Helm chart for the demo app
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── configmap.yaml   # App config mounted as /config/app.json
│       ├── pvc.yaml         # Persistent storage for notes
│       ├── deployment.yaml  # App deployment with probes & env vars
│       ├── service.yaml     # ClusterIP service
│       ├── ingress.yaml     # nginx Ingress
│       └── serviceaccount.yaml
└── argocd/
    └── workshop-app.yaml    # ArgoCD Application CR
```

## Workshop Flow

### Part 1: kubectl Basics

Walk through `kubectl-demo.sh` section by section. Covers:

1. Cluster info and node inspection
2. Namespaces
3. Pods — run, inspect, logs, exec
4. Deployments — create, scale, rolling update, rollback
5. Services — ClusterIP, LoadBalancer
6. ConfigMaps and Secrets
7. PersistentVolumeClaims
8. Ingress
9. Labels and selectors
10. Debugging and troubleshooting
11. Working with YAML manifests
12. Observability with Loki/Grafana

### Part 2: Deploy the Demo App via ArgoCD

#### Build and push the image

```bash
cd demo-app
docker build -t registry.example.com/workshop/demo-app:latest .
docker push registry.example.com/workshop/demo-app:latest
```

#### Deploy with ArgoCD

Option A — apply the ArgoCD Application directly:

```bash
kubectl apply -f argocd/workshop-app.yaml
```

Option B — install with Helm manually (for demonstration):

```bash
helm install workshop-app helm/workshop-app \
  --namespace workshop \
  --create-namespace \
  --set image.repository=registry.example.com/workshop/demo-app \
  --set ingress.host=workshop.example.com
```

#### Verify

```bash
kubectl get pods -n workshop
kubectl get ingress -n workshop
curl http://workshop.example.com
```

### Part 3: Live Demos

Things to show with the running app:

- **ConfigMap change**: edit `values.yaml` config, push, watch ArgoCD sync
- **Scaling**: change `replicaCount`, observe pod info changing per request
- **PVC persistence**: add notes, delete the pod, see notes survive
- **Logs**: view in Grafana/Loki with `{namespace="workshop"}`
- **Rolling update**: change the image tag, watch zero-downtime rollout

## Customization

Edit `helm/workshop-app/values.yaml` to change:

| Value | Description | Default |
|-------|-------------|---------|
| `image.repository` | Container image | `registry.example.com/workshop/demo-app` |
| `ingress.host` | Hostname for the app | `workshop.example.com` |
| `config.title` | Page title | `NKE Workshop` |
| `config.theme_color` | UI accent color | `#1a73e8` |
| `config.message` | Welcome message | `Welcome to the NKE Kubernetes Workshop!` |
| `persistence.size` | PVC size | `1Gi` |
