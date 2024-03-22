#!/bin/bash
source input.env

SCRIPT_DIR=$(pwd)
TMP_DIR=$(mktemp -d)

set -ex

# clone source code
cd $TMP_DIR
git clone "$GIT_REPO" sources

cd sources
git checkout "$REF"
cd ..

mkdir output

# prefetch dependencies
podman run --rm \
	-v $(realpath ./sources):/tmp/sources:z \
	-v $(realpath ./output):/tmp/output:z \
	"$CACHI2_IMAGE" \
	--log-level "DEBUG" \
	fetch-deps "$PREFETCH_INPUT" \
	--source "/tmp/sources" \
	--output "/tmp/output" \
	--dev-package-managers

# generate environmnent variables
podman run --rm \
	-v $(realpath ./sources):/tmp/sources:z \
        -v $(realpath ./output):/tmp/output:z \
	"$CACHI2_IMAGE" \
	generate-env /tmp/output \
	--format env \
	--output /tmp/output/cachi2.env

mv ./output/cachi2.env .

# inject project files
podman run --rm \
        -v $(realpath ./sources):/tmp/sources:z \
        -v $(realpath ./output):/tmp/output:z \
        "$CACHI2_IMAGE" \
        inject-files /tmp/output

# copy containerfile
if [ -n "$DOCKERFILE" ]; then
  cp "$SCRIPT_DIR/$DOCKERFILE" ./sources/Dockerfile
fi;

# build hermetically
podman build -t "$OUTPUT_IMAGE" \
        -v $(realpath ./output):/tmp/output:Z \
	-v $(realpath ./cachi2.env):/tmp/cachi2.env \
	-v $(realpath ./output/deps/rpm/x86_64):/etc/yum.repos.d \
	--no-cache \
	--network=none \
	sources

