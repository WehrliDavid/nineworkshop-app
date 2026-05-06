#!/usr/bin/env bash
# =============================================================================
# NKE Workshop - Build, Push & Helm Deploy Commands
# =============================================================================
# This file contains the commands to build the demo-app container image,
# push it to the Nine container registry, and deploy it via Helm.
# Run them one by one — they are grouped by topic.
#
# Prerequisites:
#   - Docker (or Podman) installed locally
#   - A running NKE cluster with kubeconfig configured
#   - Helm 3 installed
#   - Access to the Nine container registry
# =============================================================================

# ---------------------------------------------------------------------------
# 1. REGISTRY LOGIN
# ---------------------------------------------------------------------------

# Registry URL
REGISTRY="registry-lbeivein.d2bfc80.registry.nineapis.ch"

# Log in to the Nine container registry
docker login "$REGISTRY"

# ---------------------------------------------------------------------------
# 2. BUILD THE CONTAINER IMAGE
# ---------------------------------------------------------------------------

# Build the demo-app image from the Dockerfile (amd64 for NKE cluster nodes)
docker build --platform linux/amd64 -t "$REGISTRY/workshop/demo-app:latest" ./demo-app/

# Verify the image was built
docker images | grep demo-app

# (Optional) Run the image locally to test before pushing
docker run --rm -p 8080:8080 "$REGISTRY/workshop/demo-app:latest"
# Open http://localhost:8080 in your browser, then Ctrl+C to stop

# ---------------------------------------------------------------------------
# 3. PUSH THE IMAGE TO THE REGISTRY
# ---------------------------------------------------------------------------

# Push the image
docker push "$REGISTRY/workshop/demo-app:latest"

# (Optional) Tag and push a versioned image as well
docker tag "$REGISTRY/workshop/demo-app:latest" "$REGISTRY/workshop/demo-app:v1.0.0"
docker push "$REGISTRY/workshop/demo-app:v1.0.0"

# ---------------------------------------------------------------------------
# 4. HELM — INSPECT THE CHART
# ---------------------------------------------------------------------------

# Lint the chart to catch errors before deploying
helm lint ./helm/workshop-app/

# Render the templates locally to see what would be applied
helm template workshop-app ./helm/workshop-app/ --namespace workshop

# Render with custom values to preview overrides
helm template workshop-app ./helm/workshop-app/ \
  --namespace workshop \
  --set ingress.host=workshop.my-cluster.example.com

# ---------------------------------------------------------------------------
# 5. HELM — DEPLOY TO THE CLUSTER
# ---------------------------------------------------------------------------

# Create the namespace (if it doesn't exist yet)
kubectl create namespace workshop --dry-run=client -o yaml | kubectl apply -f -

# Install the chart for the first time
helm install workshop-app ./helm/workshop-app/ \
  --namespace workshop

# Check the release status
helm status workshop-app --namespace workshop

# List all Helm releases in the namespace
helm list --namespace workshop

# Watch pods come up
kubectl get pods -n workshop -w

# ---------------------------------------------------------------------------
# 6. HELM — UPDATE & UPGRADE
# ---------------------------------------------------------------------------

# Upgrade with changed values (e.g. new image tag or config)
helm upgrade workshop-app ./helm/workshop-app/ \
  --namespace workshop \
  --set image.tag=v1.0.0

# Upgrade with a custom values file
helm upgrade workshop-app ./helm/workshop-app/ \
  --namespace workshop \
  --values my-values.yaml

# Change the welcome message and theme color
helm upgrade workshop-app ./helm/workshop-app/ \
  --namespace workshop \
  --set config.message="Hello from Helm!" \
  --set config.theme_color="#e91e63"

# Check rollout status after upgrade
kubectl rollout status deployment/workshop-app -n workshop

# ---------------------------------------------------------------------------
# 7. HELM — ROLLBACK & HISTORY
# ---------------------------------------------------------------------------

# View release history
helm history workshop-app --namespace workshop

# Rollback to a previous revision
helm rollback workshop-app 1 --namespace workshop

# ---------------------------------------------------------------------------
# 8. VERIFY THE DEPLOYMENT
# ---------------------------------------------------------------------------

# Check all resources created by the chart
kubectl get all -n workshop
kubectl get configmap -n workshop
kubectl get pvc -n workshop
kubectl get ingress -n workshop

# Describe the deployment for details
kubectl describe deployment workshop-app -n workshop

# Check the app logs
kubectl logs -l app.kubernetes.io/name=workshop-app -n workshop --all-containers

# Test via port-forward (if ingress is not yet available)
kubectl port-forward svc/workshop-app 8080:80 -n workshop
# Open http://localhost:8080 in your browser

# ---------------------------------------------------------------------------
# 9. CLEANUP
# ---------------------------------------------------------------------------

# Uninstall the Helm release (removes all chart resources)
helm uninstall workshop-app --namespace workshop

# Delete the namespace entirely
kubectl delete namespace workshop
