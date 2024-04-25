#!/usr/bin/env bash

# Copyright 2024 The Knative Authors
# SPDX-License-Identifier: Apache-2.0

set -e
set -o pipefail

source ./lib.sh

./1-setup-first-cluster.sh
./2-create-knative-workloads.sh
./3-backup-knative-resources.sh
./4-restore-to-second-cluster.sh
