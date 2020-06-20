#!/usr/bin/env bash

set -eux

REVISION=master

docker build \
	--build-arg REVISION=${REVISION} \
	--tag anwinged/hfmt:${REVISION} \
	.

docker push anwinged/hfmt:${REVISION}