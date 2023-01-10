#!/usr/bin/env bash
set -e

for i in {1..10}
do
    echo "Running batch $i"
    ./generate-pods.sh
    sleep 10
done
