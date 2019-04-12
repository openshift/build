#!/usr/bin/env bash

readonly IGNORES="${IGNORES:-"^[ \t]*$"}" # By default no ignores

function resolve_resources(){
  local dir=$1
  local resolved_file_name=$2
  local image_prefix=$3
  local image_tag=$4

  [[ -n $image_tag ]] && image_tag=":$image_tag"

  echo "Writing resolved yaml to $resolved_file_name"

  > $resolved_file_name

  for yaml in $(find $dir -name "*.yaml" | grep -vE "$IGNORES"); do
    echo "---" >> $resolved_file_name
    # 1. Prefix test image references with test-
    # 2. Rewrite image references
    # 3/4/5. Rewrite image references that are passed as arguments to other containers 
    # 6. Remove comment lines
    # 7. Remove empty lines
    sed -e "s+\(.* image: \)\(github.com\)\(.*/\)\(test/\)\(.*\)+\1\2 \3\4test-\5+g" \
        -e "s+\(.* image: \)\(github.com\)\(.*/\)\(.*\)+\1${image_prefix}\4${image_tag}+g" \
        -e "s+github.com/knative/build/cmd/creds-init+${image_prefix}creds-init${image_tag}+g" \
        -e "s+github.com/knative/build/cmd/git-init+${image_prefix}git-init${image_tag}+g" \
        -e "s+github.com/knative/build/cmd/nop+${image_prefix}nop${image_tag}+g" \
        -e '/^[ \t]*#/d' \
        -e '/^[ \t]*$/d' \
        "$yaml" >> $resolved_file_name
  done
}
