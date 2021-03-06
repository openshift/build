#!/usr/bin/env bash

source $(dirname $0)/resolve.sh

release=$1

quay_image_prefix="quay.io/openshift-knative/knative-build-"
output_file="openshift/release/knative-build-${release}.yaml"

resolve_resources config/ $output_file $quay_image_prefix $release
