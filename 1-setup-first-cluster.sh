#!/usr/bin/env bash

# Copyright 2024 The Knative Authors
# SPDX-License-Identifier: Apache-2.0

set -e
set -o pipefail

source ./lib.sh

create_kind_cluster
install_istio
install_serving
configure_serving
