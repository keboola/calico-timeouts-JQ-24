#!/usr/bin/env bash
set -Eeuo pipefail

kubectl delete ds aws-node -n kube-system || true

# Calico
kubectl apply -f ./calico-cni.yaml
kubectl rollout status daemonset/calico-node --timeout=600s -n kube-system