#!/usr/bin/env bash

# Copyright 2024 The Knative Authors
# SPDX-License-Identifier: Apache-2.0

set -e
set -o pipefail

source ./lib.sh

create_kind_cluster
install_istio
install_serving_crds

go run ./cmd/restore/main.go -backup-file backup.yaml

install_serving

sleep 5

knative_curl hello.default.example.com
knative_curl meow.default.example.com
