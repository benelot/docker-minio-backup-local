group "default" {
	targets = ["alpine-latest", "debian-latest"]
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
	args = {"BASETAG" = "latest"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:latest"
	]
}

target "alpine-latest" {
	inherits = ["alpine"]
	platforms = ["linux/amd64", "linux/arm64", "linux/arm/v7", "linux/s390x", "linux/ppc64le"]
	args = {"BASETAG" = "latest"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:latest"
	]
}
