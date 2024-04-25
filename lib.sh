#!/usr/bin/env bash

# Copyright 2024 The Knative Authors
# SPDX-License-Identifier: Apache-2.0

function create_kind_cluster() {
version=${1:-1.29.2}

  config=$(mktemp)
cat <<EOF >"$config"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: kindest/node:v${version}
- role: worker
  image: kindest/node:v${version}
- role: worker
  image: kindest/node:v${version}
EOF

  kind delete cluster
  kind create cluster --config "$config"

  kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
  kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s
cat <<EOF | kubectl apply -f -
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.200-172.18.255.250
---
EOF
}

function install_istio() {
  # Setup Istio
  kubectl apply -f https://raw.githubusercontent.com/knative-sandbox/net-istio/main/third_party/istio-latest/istio-kind-no-mesh/istio.yaml
}

function install_serving_crds() {
  kubectl apply -f https://github.com/knative/serving/releases/latest/download/serving-crds.yaml
}

function install_serving() {
  kubectl apply -f https://github.com/knative/serving/releases/latest/download/serving-crds.yaml
  kubectl wait --for condition=established --timeout=60s --all crd
  kubectl apply -f https://github.com/knative/serving/releases/latest/download/serving-core.yaml

  kubectl wait --namespace knative-serving \
               --all \
               --for=condition=ready pod \
               --timeout=90s

  kubectl apply -f https://github.com/knative-extensions/net-istio/releases/latest/download/net-istio.yaml

  kubectl wait --namespace knative-serving \
               --all \
               --for=condition=ready pod \
               --timeout=90s

  kubectl wait --namespace knative-serving \
               --all \
               --for=condition=ready pod \
               --timeout=90s
}

function configure_serving() {
  kubectl patch configmap/config-network \
    --namespace knative-serving \
    --type merge \
    --patch '{"data":{
      "ingress.class":"istio.ingress.networking.knative.dev",
      "autocreate-cluster-domain-claims":"true"
    }}'

  kubectl patch configmap/config-domain \
    --namespace knative-serving \
    --type merge \
    --patch '{"data":{
      "example.com":""
    }}'
}

function knative_curl() {
  LB_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  docker run --network kind -it --rm cgr.dev/chainguard/curl -H "Host: $1" $LB_IP
}
