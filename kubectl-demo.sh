#!/usr/bin/env bash
# =============================================================================
# NKE Workshop - kubectl Demo Commands
# =============================================================================
# This file contains example kubectl commands to walk through during the
# workshop. Run them one by one — they are grouped by topic.
#
# Prerequisites:
#   - A running NKE cluster with kubeconfig configured
#   - ArgoCD, ingress-nginx, Loki, Grafana, and a container registry deployed
# =============================================================================

# ---------------------------------------------------------------------------
# 1. CLUSTER BASICS
# ---------------------------------------------------------------------------

# Check connectivity and cluster info
kubectl cluster-info
kubectl version

# List all nodes and their status
kubectl get nodes
kubectl get nodes -o wide

# Show detailed info about a node (resource capacity, conditions, pods)
kubectl describe node <node-name>

# See resource usage per node (requires metrics-server)
kubectl top nodes

# ---------------------------------------------------------------------------
# 2. NAMESPACES
# ---------------------------------------------------------------------------

# List all namespaces
kubectl get namespaces

# Create a workshop namespace
kubectl create namespace workshop

# Set the workshop namespace as default for this session
kubectl config set-context --current --namespace=workshop

# ---------------------------------------------------------------------------
# 3. PODS — the smallest deployable unit
# ---------------------------------------------------------------------------

# Run a one-off pod (great for debugging)
kubectl run debug --image=busybox --rm -it --restart=Never -- sh

# Run an nginx pod quickly
kubectl run nginx-demo --image=nginx:alpine --port=80

# List pods in the current namespace
kubectl get pods
kubectl get pods -o wide          # shows node placement and IP

# Describe a pod (events, conditions, container status)
kubectl describe pod nginx-demo

# View pod logs
kubectl logs nginx-demo
kubectl logs nginx-demo --follow  # stream logs

# Execute a command inside a running pod
kubectl exec -it nginx-demo -- sh
# inside the shell: curl localhost, cat /etc/nginx/nginx.conf, exit

# Delete the test pod
kubectl delete pod nginx-demo

# ---------------------------------------------------------------------------
# 4. DEPLOYMENTS — declarative desired state
# ---------------------------------------------------------------------------

# Create a deployment imperatively (for demo; in production use manifests)
kubectl create deployment hello-web \
  --image=nginx:alpine \
  --replicas=2 \
  --port=80

# Watch pods come up
kubectl get pods -w

# Show the deployment and its replicaset
kubectl get deployments
kubectl get replicasets

# Scale up
kubectl scale deployment hello-web --replicas=4
kubectl get pods

# Scale back down
kubectl scale deployment hello-web --replicas=2

# Rolling update — change the image
kubectl set image deployment/hello-web nginx=nginx:1.27-alpine
kubectl rollout status deployment/hello-web

# Check rollout history
kubectl rollout history deployment/hello-web

# Rollback to previous version
kubectl rollout undo deployment/hello-web

# ---------------------------------------------------------------------------
# 5. SERVICES — stable networking for pods
# ---------------------------------------------------------------------------

# Expose the deployment as a ClusterIP service
kubectl expose deployment hello-web --port=80 --target-port=80 --type=ClusterIP

# View services
kubectl get services
kubectl get endpoints hello-web

# Test from inside the cluster with a temporary pod
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s http://hello-web.workshop.svc.cluster.local

# Expose as LoadBalancer (MetalLB will assign an external IP on NKE)
kubectl expose deployment hello-web \
  --name=hello-web-lb \
  --port=80 \
  --target-port=80 \
  --type=LoadBalancer

kubectl get svc hello-web-lb -w   # watch until EXTERNAL-IP is assigned

# ---------------------------------------------------------------------------
# 6. CONFIGMAPS & SECRETS
# ---------------------------------------------------------------------------

# Create a ConfigMap from literal values
kubectl create configmap app-settings \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info

# Create a ConfigMap from a file
cat <<'CONF' > /tmp/app.conf
[server]
port = 8080
title = "NKE Workshop Demo"
CONF
kubectl create configmap app-config --from-file=/tmp/app.conf

# View ConfigMaps
kubectl get configmaps
kubectl describe configmap app-config

# Create a Secret
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password=supersecret

# View secrets (values are base64 encoded)
kubectl get secrets
kubectl get secret db-creds -o yaml

# ---------------------------------------------------------------------------
# 7. PERSISTENT VOLUMES
# ---------------------------------------------------------------------------

# List storage classes (NKE uses Nutanix CSI)
kubectl get storageclasses

# Create a PVC
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo-pvc
  namespace: workshop
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Check the PVC status (should become Bound)
kubectl get pvc
kubectl describe pvc demo-pvc

# Clean up
kubectl delete pvc demo-pvc

# ---------------------------------------------------------------------------
# 8. INGRESS (nginx ingress controller)
# ---------------------------------------------------------------------------

# List ingress resources
kubectl get ingress

# Create a simple ingress for the hello-web service
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-web-ingress
  namespace: workshop
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hello-web
                port:
                  number: 80
EOF

kubectl get ingress
kubectl describe ingress hello-web-ingress

# ---------------------------------------------------------------------------
# 9. LABELS, SELECTORS & FILTERING
# ---------------------------------------------------------------------------

# Add a label to a pod
kubectl label pod -l app=hello-web tier=frontend

# Filter pods by label
kubectl get pods -l app=hello-web
kubectl get pods -l tier=frontend

# Show labels on all pods
kubectl get pods --show-labels

# Get pods across all namespaces
kubectl get pods --all-namespaces
kubectl get pods -A              # shorthand

# ---------------------------------------------------------------------------
# 10. DEBUGGING & TROUBLESHOOTING
# ---------------------------------------------------------------------------

# Check events in the namespace (very useful for debugging)
kubectl get events --sort-by='.lastTimestamp'

# Describe is your best friend for debugging
kubectl describe pod <pod-name>
kubectl describe deployment <deployment-name>

# Check resource usage of pods
kubectl top pods

# Get a shell into a running container
kubectl exec -it <pod-name> -- /bin/sh

# Port-forward to access a pod/service locally
kubectl port-forward svc/hello-web 8080:80
# now open http://localhost:8080 in your browser

# Debug with an ephemeral container (K8s 1.25+)
kubectl debug -it <pod-name> --image=busybox --target=<container-name>

# Check RBAC — can I do X?
kubectl auth can-i create deployments
kubectl auth can-i delete pods --namespace kube-system

# ---------------------------------------------------------------------------
# 11. RESOURCE MANIFESTS — working with YAML
# ---------------------------------------------------------------------------

# Export a running resource as YAML (great for learning)
kubectl get deployment hello-web -o yaml

# Dry-run to generate YAML without applying
kubectl create deployment test-app --image=nginx --dry-run=client -o yaml

# Apply a manifest file
kubectl apply -f manifest.yaml

# Apply all manifests in a directory
kubectl apply -f ./manifests/

# Diff before applying (see what would change)
kubectl diff -f manifest.yaml

# ---------------------------------------------------------------------------
# 12. OBSERVABILITY — Logs with Loki & Grafana
# ---------------------------------------------------------------------------

# Pod logs (basic)
kubectl logs <pod-name>
kubectl logs <pod-name> -c <container>   # multi-container pods
kubectl logs <pod-name> --previous        # logs from crashed container
kubectl logs -l app=hello-web --all-containers

# Access Grafana (port-forward if not exposed via ingress)
kubectl port-forward -n monitoring svc/grafana 3000:80
# Open http://localhost:3000 — use Explore > Loki to query logs
# Example LogQL: {namespace="workshop", app="hello-web"}

# ---------------------------------------------------------------------------
# 13. CLEANUP
# ---------------------------------------------------------------------------

# Delete all resources we created
kubectl delete deployment hello-web
kubectl delete svc hello-web hello-web-lb
kubectl delete ingress hello-web-ingress
kubectl delete configmap app-settings app-config
kubectl delete secret db-creds

# Or delete the entire namespace (deletes everything inside it)
kubectl delete namespace workshop
