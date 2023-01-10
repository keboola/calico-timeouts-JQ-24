#!/usr/bin/env bash
set -e

kubectl delete pods -l app=job-queue-jobs-k8s-native-test-job
