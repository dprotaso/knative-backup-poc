#!/usr/bin/env bash

# Copyright 2024 The Knative Authors
# SPDX-License-Identifier: Apache-2.0

set -e
set -o pipefail

source ./lib.sh

alias kn="go run knative.devv/client/cmd/kn"

kn service create hello \
--image ghcr.io/knative/helloworld-go:latest \
--port 8080 \
--env TARGET=World


knative_curl hello.default.example.com

kn service create meow \
--image ghcr.io/knative/helloworld-go:latest \
--port 8080 \
--env TARGET=Meow

knative_curl meow.default.example.com

kn service update hello \
--env TARGET=Earth

kn service update meow \
--env TARGET=Cat

kn service update hello \
--traffic hello-00001=50 \
--traffic @latest=50

kn service update meow \
--traffic meow-00001=50 \
--traffic @latest=50

knative_curl hello.default.example.com
knative_curl meow.default.example.com
