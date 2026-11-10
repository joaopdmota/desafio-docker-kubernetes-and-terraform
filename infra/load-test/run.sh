#!/bin/sh
set -eu

KUBECONFIG_PATH="${KUBECONFIG_PATH:-infra/terraform/.kubeconfig}"
NAMESPACE="${NAMESPACE:-mural}"
HPA_NAME="${HPA_NAME:-mural-mural-api}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-mural-mural-api}"
LOAD_POD="${LOAD_POD:-mural-hpa-load}"

kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" \
  wait --for=condition=Available "deployment/$DEPLOYMENT_NAME" --timeout=180s

echo "Waiting for Metrics Server to publish API metrics..."
attempt=0
until kubectl --kubeconfig "$KUBECONFIG_PATH" top pods -n "$NAMESPACE" >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 36 ]; then
    echo "Metrics API did not become ready." >&2
    kubectl --kubeconfig "$KUBECONFIG_PATH" -n kube-system logs deployment/metrics-server --tail=100 >&2 || true
    exit 1
  fi
  sleep 5
done

kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" \
  delete pod "$LOAD_POD" --ignore-not-found >/dev/null

echo "Starting concurrent load against the internal API Service..."
kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" run "$LOAD_POD" \
  --image=busybox:1.36 --restart=Never --command -- sh -ec '
    end=$(($(date +%s) + 180))
    worker() {
      while [ "$(date +%s)" -lt "$end" ]; do
        wget -q -O /dev/null http://mural-mural-api:8080/api/messages || true
      done
    }
    i=0
    while [ "$i" -lt 50 ]; do worker & i=$((i + 1)); done
    wait
  ' >/dev/null

echo "Waiting for the HPA to request more than one replica..."
attempt=0
scaled=false
while [ "$attempt" -lt 36 ]; do
  desired=$(kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" \
    get hpa "$HPA_NAME" -o jsonpath='{.status.desiredReplicas}' 2>/dev/null || true)
  current_cpu=$(kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" \
    get hpa "$HPA_NAME" -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null || true)
  printf 'desired replicas=%s, average CPU=%s%%\n' "${desired:-unknown}" "${current_cpu:-unknown}"
  if [ "${desired:-0}" -gt 1 ] 2>/dev/null; then scaled=true; break; fi
  attempt=$((attempt + 1))
  sleep 5
done

kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" get hpa "$HPA_NAME"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" get pods \
  -l app.kubernetes.io/component=api

kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" \
  delete pod "$LOAD_POD" --ignore-not-found >/dev/null

if [ "$scaled" != true ]; then
  echo "HPA did not scale within 180 seconds." >&2
  exit 1
fi

echo "HPA scale-out proven. It will return toward minReplicas after the stabilization window."

