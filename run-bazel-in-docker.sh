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