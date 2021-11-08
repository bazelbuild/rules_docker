# Runs bazel in a docker container, with this repository's workspace mounted in its file system.
# This is useful because rules_docker assumes the host environment is linux, and tests will fail on other environments.
# Running bazel in docker is slower, but allows for the build and tests to execute on non-linux environments.

mkdir -p /tmp/build_output/
# -e USER="$(id -u)" \
# -u="$(id -u)" \
docker run \
  -v "$PWD":/workspace \
  -v /tmp/build_output:/tmp/build_output \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -w /workspace \
  l.gcr.io/google/bazel:latest \
  --output_user_root=/tmp/build_output \
  "$@"