group "default" {
	targets = ["latest", "latest"]
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
	args = {"GOCRONVER" = "v0.0.10"}
	dockerfile = "debian.Dockerfile"
}

target "alpine" {
	args = {"GOCRONVER" = "v0.0.10"}
	dockerfile = "alpine.Dockerfile"
}

target "debian-latest" {
	inherits = ["debian"]
	platforms = ["linux/amd64", "linux/arm64", "linux/arm/v7", "linux/s390x", "linux/ppc64le"]
	args = {"BASETAG" = "16"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:latest",
		"${REGISTRY_PREFIX}${IMAGE_NAME}:16",
		notequal("", BUILD_REVISION) ? "${REGISTRY_PREFIX}${IMAGE_NAME}:16-debian-${BUILD_REVISION}" : ""
	]
}

target "alpine-latest" {
	inherits = ["alpine"]
	platforms = ["linux/amd64", "linux/arm64", "linux/arm/v7", "linux/s390x", "linux/ppc64le"]
	args = {"BASETAG" = "16-alpine"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:alpine",
		"${REGISTRY_PREFIX}${IMAGE_NAME}:16-alpine",
		notequal("", BUILD_REVISION) ? "${REGISTRY_PREFIX}${IMAGE_NAME}:16-alpine-${BUILD_REVISION}" : ""
	]
}
