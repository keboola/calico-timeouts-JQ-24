#!/usr/bin/env bash
arr=(a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9)
seed=""
for i in {1..5}
do
    seed="$seed${arr[$RANDOM % ${#arr[@]}]}"
done

cat > pods.yaml <<\EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: job-queue-jobs-k8s-native-test-script
data:
  test.sh: |
    #!/bin/bash
    set -e

    for i in {1..20}
    do
      echo "Request $i"
      curl --show-error --silent --fail --connect-timeout 10 --max-time 20 -o /dev/null https://queue.keboola.com/
      sleep 1
    done
EOF

for i in {1..50}
do
    cat >> pods.yaml <<EOF
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: job-queue-jobs-k8s-native-test-job
  name: job-queue-jobs-k8s-native-test-job-$seed-$i
spec:
  restartPolicy: Never
  containers:
  - name: job-runner
    image: php:8
    imagePullPolicy: IfNotPresent
    resources:
      limits:
        cpu: "1"
        memory: 500Mi
      requests:
        cpu: 200m
        memory: 200Mi
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
    command: ["sh", "-c", "/code/public/test/test.sh"]
    volumeMounts:
    - name: test-scripts-volume
      mountPath: /code/public/test/
  tolerations:
  - effect: NoSchedule
    key: app
    operator: Equal
    value: job-queue-jobs-short-run-time
  - effect: NoExecute
    key: node.kubernetes.io/not-ready
    operator: Exists
    tolerationSeconds: 300
  - effect: NoExecute
    key: node.kubernetes.io/unreachable
    operator: Exists
    tolerationSeconds: 300
  volumes:
  - name: test-scripts-volume
    configMap:
      name: job-queue-jobs-k8s-native-test-script
      defaultMode: 0777

EOF
done

kubectl apply -f pods.yaml
