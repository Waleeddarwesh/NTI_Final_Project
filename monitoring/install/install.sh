#!/usr/bin/env bash
# monitoring/install/install.sh
# Installs the complete monitoring stack in the correct order:
#   1. kube-prometheus-stack (Prometheus, Alertmanager, Grafana, Node Exporter,
#      kube-state-metrics, Prometheus Operator)
#   2. Custom PrometheusRule alert rules
#   3. ServiceMonitor for the Django app
#   4. Grafana dashboards via ConfigMap
#
# Usage:
#   cd monitoring/
#   ./install/install.sh
#
# Prerequisites:
#   - kubectl configured against the target EKS cluster
#   - helm 3.x installed
#   - EBS CSI driver installed on the cluster (for PVC storage)
#     Install: aws eks create-addon --cluster-name nti-devops-dev-eks \
#                --addon-name aws-ebs-csi-driver

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="$(dirname "$SCRIPT_DIR")"

STACK_VERSION="87.10.1"
NAMESPACE="monitoring"
RELEASE_NAME="kube-prometheus-stack"

log() { echo "$(date -u +%FT%TZ) [install] $*"; }

# ── Prerequisites check ───────────────────────────────────────────────────────
log "Checking prerequisites..."
for cmd in kubectl helm aws; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd not found. Install it before running this script."
        exit 1
    fi
done

CLUSTER=$(kubectl config current-context 2>/dev/null || true)
log "Cluster context: ${CLUSTER}"
read -rp "Deploy monitoring to this cluster? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ── Helm repo ─────────────────────────────────────────────────────────────────
log "Adding prometheus-community Helm repo..."
helm repo add prometheus-community \
    https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update prometheus-community

# ── Namespace ─────────────────────────────────────────────────────────────────
log "Creating monitoring namespace..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ── kube-prometheus-stack ─────────────────────────────────────────────────────
log "Installing kube-prometheus-stack v${STACK_VERSION}..."
helm upgrade "$RELEASE_NAME" prometheus-community/kube-prometheus-stack \
    --namespace "$NAMESPACE" \
    --version "$STACK_VERSION" \
    --install \
    --atomic \
    --timeout 10m \
    --values "${MONITORING_DIR}/kube-prometheus-stack-values.yaml"

log "kube-prometheus-stack installed."

# ── Wait for Prometheus Operator to be ready ──────────────────────────────────
log "Waiting for Prometheus Operator to be ready..."
kubectl rollout status deployment/kube-prometheus-stack-operator \
    --namespace "$NAMESPACE" \
    --timeout=120s

# ── Custom alert rules ────────────────────────────────────────────────────────
log "Applying custom PrometheusRule..."
kubectl apply -f "${MONITORING_DIR}/alerts/nti-devops-rules.yaml"

# ── ServiceMonitor ────────────────────────────────────────────────────────────
log "Applying ServiceMonitor..."
kubectl apply -f "${MONITORING_DIR}/alerts/servicemonitor.yaml"

# ── Grafana dashboards ────────────────────────────────────────────────────────
log "Creating Grafana dashboard ConfigMap..."

# Inline the dashboard JSON into the ConfigMap at apply time
DASHBOARD_JSON=$(cat "${MONITORING_DIR}/dashboards/nti-devops-application.json")

kubectl create configmap nti-devops-dashboards \
    --namespace "$NAMESPACE" \
    --from-literal="nti-devops-application.json=${DASHBOARD_JSON}" \
    --dry-run=client -o yaml \
| kubectl label --local -f - grafana_dashboard=1 -o yaml \
| kubectl apply -f -

log "Dashboard ConfigMap applied. Grafana sidecar will load it within ~30s."

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Monitoring stack installed                                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"

GRAFANA_SVC=$(kubectl get svc kube-prometheus-stack-grafana \
    -n "$NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")

echo "║  Grafana URL  : http://${GRAFANA_SVC}                       ║"
echo "║  Grafana user : admin                                        ║"
echo "║  Grafana pass : (set in kube-prometheus-stack-values.yaml)  ║"
echo "║                                                              ║"
echo "║  Port-forward (if LoadBalancer is pending):                  ║"
echo "║    kubectl port-forward svc/kube-prometheus-stack-grafana \  ║"
echo "║      3000:80 -n monitoring                                   ║"
echo "║  Then open: http://localhost:3000                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
