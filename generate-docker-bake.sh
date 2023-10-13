#!/bin/sh

set -e

GOCRONVER="v0.0.10"
PLATFORMS="linux/amd64 linux/arm64 linux/arm/v7 linux/s390x linux/ppc64le"
DOCKER_BAKE_FILE="${1:-docker-bake.hcl}"

cd "$(dirname "$0")"

P="\"$(echo $PLATFORMS | sed 's/ /", "/g')\""

T="\"latest\""

cat > "$DOCKER_BAKE_FILE" << EOF
group "default" {
	targets = [$T]
}

variable "REGISTRY_PREFIX" {
	default = ""
}

variable "IMAGE_NAME" {
	default = "minio-backup-local"
}

variable "BUILD_REVISION" {
	default = ""
}

target "debian" {
	args = {"GOCRONVER" = "$GOCRONVER"}
	dockerfile = "debian.Dockerfile"
}

target "alpine" {
	args = {"GOCRONVER" = "$GOCRONVER"}
	dockerfile = "alpine.Dockerfile"
}

target "debian-latest" {
	inherits = ["debian"]
	platforms = [$P]
	args = {"BASETAG" = "debian"}
	tags = [
		"\${REGISTRY_PREFIX}\${IMAGE_NAME}:latest"
	]
}

target "alpine-latest" {
	inherits = ["alpine"]
	platforms = [$P]
	args = {"BASETAG" = "alpine"}
	tags = [
		"\${REGISTRY_PREFIX}\${IMAGE_NAME}:latest"
	]
}
EOF
