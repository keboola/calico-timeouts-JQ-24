#!/usr/bin/env bash
set -Eeuo pipefail

# Installation - https://docs.aws.amazon.com/eks/latest/userguide/calico.html#calico-install
kubectl apply -f ./calico-operator.yaml
kubectl apply -f ./calico-crs.yaml


kubectl apply -f <(cat <(kubectl get clusterrole aws-node -o yaml) ./append.yaml)
kubectl set env daemonset aws-node -n kube-system ANNOTATE_POD_IP=true