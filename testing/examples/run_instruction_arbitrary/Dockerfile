# Ubuntu with bazel, gcloud and its dependencies preinstalled.

FROM launcher.gcr.io/google/bazel:latest

# Ensure new repos aren't compromised.
COPY image_data/gcloud.pub.gpg /
RUN apt-key add /gcloud.pub.gpg \
    && rm /gcloud.pub.gpg

# Add new repos to install bazel and google-cloud-sdk (including kubectl)
COPY image_data/sources.list /etc/apt/sources.list.d/gcloud.list

# Install necessary dependencies:
# * gcloud: needed by rules_go and test-e2e.sh
# * kubectl: needed by rules_k8s
# * pip setuptools wheel: needed by python rules
# * python-pip: needed by python rules
RUN apt-get update && apt-get install -y --no-install-recommends \
    google-cloud-sdk \
    kubectl \
    python-pip \
    && apt-get clean \
    && python -m pip install --upgrade pip setuptools wheel
