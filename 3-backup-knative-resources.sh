#!/usr/bin/env bash

# Copyright 2024 The Knative Authors
# SPDX-License-Identifier: Apache-2.0

set -e
set -o pipefail

resources=(
  "service.serving.knative.dev"
  "route.serving.knative.dev"
  "configuration.serving.knative.dev"
  "revision.serving.knative.dev"
  "certificate.networking.internal.knative.dev"
  "ingress.networking.internal.knative.dev"
  "image.caching.internal.knative.dev"
  "podautoscaler.autoscaling.internal.knative.dev"
  "metric.autoscaling.internal.knative.dev"
  "serverlessservice.networking.internal.knative.dev"
)

> backup.yaml # Clear

# Backup other things the resources might reference/be created in
kubectl get namespace -l app.kubernetes.io/name=knative-serving -o yaml >> backup.yaml
echo "---" >> backup.yaml

# Back up the configmaps in the serving repo
kubectl get configmap -n knative-serving -l app.kubernetes.io/name=knative-serving -o yaml >> backup.yaml
echo "---" >> backup.yaml

for resource in ${resources[@]}; do
  echo "backing up $resource"
  kubectl get $resource -A -o yaml >> backup.yaml
  echo "---" >> backup.yaml
done
