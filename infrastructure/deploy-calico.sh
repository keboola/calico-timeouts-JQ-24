#!/usr/bin/env bash
set -Eeuo pipefail

kubectl delete ds aws-node -n kube-system || true

# Calico
kubectl create -f ./calico-operator.yaml
kubectl apply -f ./calico-cni.yaml