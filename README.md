# Bazel Container Image Rules

Travis CI | Bazel CI
:---: | :---:
[![Build Status](https://travis-ci.org/bazelbuild/rules_docker.svg?branch=master)](https://travis-ci.org/bazelbuild/rules_docker) | [![Build Status](https://ci.bazel.build/buildStatus/icon?job=rules_docker)](https://ci.bazel.build/job/rules_docker)

## Basic Rules

* [container_image](#container_image-1) ([example](#container_image))
* [container_bundle](#container_bundle-1) ([example](#container_bundle))
* [container_import](#container_import)
* [container_load](#container_load)
* [container_pull](#container_pull-1) ([example](#container_pull))
* [container_push](#container_push-1) ([example](#container_push))

These rules used to be `docker_build`, `docker_push`, etc. and the aliases for
these (mostly) legacy names still exist largely for backwards-compatibility.  We
also have **early-stage** `oci_image`, `oci_push`, etc. aliases for folks that
enjoy the consistency of a consistent rule prefix.  The only place the
format-specific names currently do any more than alias things is in `foo_push`,
where they also specify the appropriate format as which to publish the image.

### Overview

This repository contains a set of rules for pulling down base images, augmenting
them with build artifacts and assets, and publishing those images.
**These rules do not require / use Docker for pulling, building, or pushing
images.**  This means:
* They can be used to develop Docker containers on Windows / OSX without
`boot2docker` or `docker-machine` installed.
* They do not require root access on your workstation.

Also, unlike traditional container builds (e.g. Dockerfile), the Docker images
produced by `container_image` are deterministic / reproducible.

__NOTE:__ `container_push` and `container_pull` make use of
[google/containerregistry](https://github.com/google/containerregistry) for
registry interactions.

## Language Rules

* [py_image](#py_image) ([signature](
https://docs.bazel.build/versions/master/be/python.html#py_binary))
* [py3_image](#py3_image) ([signature](
https://docs.bazel.build/versions/master/be/python.html#py_binary))
* [nodejs_image](#nodejs_image) ([usage](
https://github.com/bazelbuild/rules_nodejs#usage))
* [java_image](#java_image) ([signature](
https://docs.bazel.build/versions/master/be/java.html#java_binary))
* [war_image](#war_image) ([signature](
https://docs.bazel.build/versions/master/be/java.html#java_library))
* [scala_image](#scala_image) ([signature](
https://github.com/bazelbuild/rules_scala#scala_binary))
* [groovy_image](#groovy_image) ([signature](
https://github.com/bazelbuild/rules_groovy#groovy_binary))
* [cc_image](#cc_image) ([signature](
https://docs.bazel.build/versions/master/be/c-cpp.html#cc_binary))
* [go_image](#go_image) ([signature](
https://github.com/bazelbuild/rules_go#go_binary))
* [rust_image](#rust_image) ([signature](
https://github.com/bazelbuild/rules_rust#rust_binary))
* [d_image](#d_image) ([signature](
https://github.com/bazelbuild/rules_d#d_binary))

It is notable that: `cc_image`, `go_image`, `rust_image`, and `d_image`
also allow you to specify an external binary target.

### Overview

In addition to low-level rules for building containers, this repository
provides a set of higher-level rules for containerizing applications.  The idea
behind these rules is to make containerizing an application built via a
`lang_binary` rule as simple as changing it to `lang_image`.

By default these higher level rules make use of the [`distroless`](
https://github.com/googlecloudplatform/distroless) language runtimes, but these
can be overridden via the `base="..."` attribute (e.g. with a `container_pull`
or `container_image` target).

## Setup

Add the following to your `WORKSPACE` file to add the external repositories:

```python
git_repository(
    name = "io_bazel_rules_docker",
    remote = "https://github.com/bazelbuild/rules_docker.git",
    tag = "v0.3.0",
)

load(
    "@io_bazel_rules_docker//container:container.bzl",
    "container_pull",
    container_repositories = "repositories",
)

# This is NOT needed when going through the language lang_image
# "repositories" function(s).
container_repositories()

container_pull(
  name = "java_base",
  registry = "gcr.io",
  repository = "distroless/java",
  # 'tag' is also supported, but digest is encouraged for reproducibility.
  digest = "sha256:deadbeef",
)
```

## Using with Docker locally.

Suppose you have a `container_image` target `//my/image:helloworld`:

```python
container_image(
    name = "helloworld",
    ...
)
```

You can load this into your local Docker client by running:
`bazel run my/image:helloworld`.

For the `lang_image` targets, this will also **run** the
container to maximize compatibility with `lang_binary` rules.  You can suppress
this behavior by passing the single flag: `bazel run :foo -- --norun`

Alternatively, you can build a `docker load` compatible bundle with:
`bazel build my/image:helloworld.tar`.  This will produce the file:
`bazel-genfiles/my/image/helloworld.tar`, which you can load into
your local Docker client by running:
`docker load -i bazel-genfiles/my/image/helloworld.tar`.  Building
this target can be expensive for large images.

These work with both `container_image`, `container_bundle`, and the
`lang_image` rules.  For everything except
`container_bundle`, the image name will be `bazel/my/image:helloworld`.
For `container_bundle`, it will apply the tags you have specified.

## Authentication

You can use these rules to access private images using standard Docker
authentication methods.  e.g. to utilize the [Google Container Registry](
https://gcr.io) [credential helper](
https://github.com/GoogleCloudPlatform/docker-credential-gcr):

```shell
$ gcloud components install docker-credential-gcr

$ docker-credential-gcr configure-docker
```

See also:
 * [Amazon ECR Docker Credential Helper](
 https://github.com/awslabs/amazon-ecr-credential-helper)
 * [Azure Docker Credential Helper](
 https://github.com/Azure/acr-docker-credential-helper)

## Varying image names

A common request from folks using `container_push` or `container_bundle` is to
be able to vary the tag that is pushed or embedded.  There are two options
at present for doing this.

### Stamping

The first option is to use `stamp = True`.

```python
# A common pattern when users want to avoid trampling
# on each other's images during development.
container_push(
  name = "publish",

  format = "Docker",

  # Any of these components may have variables.
  registry = "gcr.io",
  repository = "my-project/my-image",
  tag = "{BUILD_USER}",

  # Trigger stamping.
  stamp = True,
)
```

The next natural question is: "Well what variables can I use?"  This
option consumes the workspace-status variables Bazel defines in
`stable-status.txt` and `volatile-status.txt`.  These files will appear
in the target's runfiles:

```shell
$ bazel build //docker/testdata:push_stamp
...

$ cat bazel-bin/docker/testdata/push_stamp.runfiles/io_bazel_rules_docker/stable-status.txt
BUILD_EMBED_LABEL
BUILD_HOST bazel
BUILD_USER mattmoor

$ cat bazel-bin/docker/testdata/push_stamp.runfiles/io_bazel_rules_docker/volatile-status.txt
BUILD_TIMESTAMP 1498740967769

```

You can augment these variables via `--workspace_status_command`,
including through the use of [`.bazelrc`](https://github.com/kubernetes/kubernetes/blob/81ce94ae1d8f5d04058eeb214e9af498afe78ff2/build/root/.bazelrc#L6).


### Make variables

The second option is to employ `Makefile`-style variables:

```python
container_bundle(
  name = "bundle",

  images = {
    "gcr.io/$(project)/frontend:latest": "//frontend:image",
    "gcr.io/$(project)/backend:latest": "//backend:image",
  }
)
```

These variables are specified on the CLI using:

```shell
   bazel build --define project=blah //path/to:bundle
```

## Debugging `lang_image` rules

By default the `lang_image` rules use the `distroless` base runtime images,
which are optimized to be the minimal set of things your application needs
at runtime.  That can make debugging these containers difficult because they
lack even a basic shell for exploring the filesystem.

To address this, we publish variants of the `distroless` runtime images tagged
`:debug`, which are the exact-same images, but with additions such as `busybox`
to make debugging easier.

For example (in this repo):
```shell
$ bazel run -c dbg testdata:go_image
...
INFO: Build completed successfully, 5 total actions

INFO: Running command line: bazel-bin/testdata/go_image
Loaded image ID: sha256:9c5c2167a1db080a64b5b401b43b3c5cdabb265b26cf7a60aabe04a20da79e24
Tagging 9c5c2167a1db080a64b5b401b43b3c5cdabb265b26cf7a60aabe04a20da79e24 as bazel/testdata:go_image
Hello, world!

$ docker run -ti --rm --entrypoint=sh bazel/testdata:go_image -c "echo Hello, busybox."
Hello, busybox.
```


## Examples

### container_image

```python
container_image(
    name = "app",
    # References container_pull from WORKSPACE (above)
    base = "@java_base//image",
    files = ["//java/com/example/app:Hello_deploy.jar"],
    cmd = ["Hello_deploy.jar"]
)
```

### cc_image

To use `cc_image`, add the following to `WORKSPACE`:

```python
load(
    "@io_bazel_rules_docker//cc:image.bzl",
    _cc_image_repos = "repositories",
)

_cc_image_repos()
```

Then in your `BUILD` file, simply rewrite `cc_binary` to `cc_image` with the
following import:
```python
load("@io_bazel_rules_docker//cc:image.bzl", "cc_image")

cc_image(
    name = "cc_image",
    srcs = ["cc_image.cc"],
    deps = [":cc_image_library"],
)
```

### cc_image (external binary)

To use `cc_image` (or `go_image`, `d_image`, `rust_image) with an external
`cc_binary` (or the like) target, then your `BUILD` file should instead look
like:
```python
load("@io_bazel_rules_docker//cc:image.bzl", "cc_image")

cc_binary(
    name = "cc_binary",
    srcs = ["cc_binary.cc"],
    deps = [":cc_library"],
)

cc_image(
    name = "cc_image",
    binary = ":cc_binary",
)
```

### py_image

To use `py_image`, add the following to `WORKSPACE`:

```python
# You may use "@io_bazel_rules_docker//python3:image.bzl" here if using 
# the py3 rules. (see below)
load(
    "@io_bazel_rules_docker//python:image.bzl",
    _py_image_repos = "repositories",
)

_py_image_repos()
```

Then in your `BUILD` file, simply rewrite `py_binary` to `py_image` with the
following import:
```python
load("@io_bazel_rules_docker//python:image.bzl", "py_image")

py_image(
    name = "py_image",
    srcs = ["py_image.py"],
    deps = [":py_image_library"],
    main = "py_image.py",
)
```

### py_image (fine layering)

For Python and Java's `lang_image` rules, you can factor
dependencies that don't change into their own layers by overriding the
`layers=[]` attribute.  Consider this sample from the `rules_k8s` repository:
```python
py_image(
    name = "server",
    srcs = ["server.py"],
    # "layers" is just like "deps", but it also moves the dependencies each into
    # their own layer, which can dramatically improve developer cycle time.  For
    # example here, the grpcio layer is ~40MB, but the rest of the app is only
    # ~400KB.  By partitioning things this way, the large grpcio layer remains
    # unchanging and we can reduce the amount of image data we repush by ~99%!
    layers = [
        requirement("grpcio"),
        "//examples/hellogrpc/proto:py",
    ],
    main = "server.py",
)
```

### py3_image

To use a Python 3 runtime instead of the default of Python 2, use `py3_image`,
instead of `py_image`.  The other semantics are identical.

### nodejs_image

**It is notable that unlike the other image rules, `nodejs_image` is not
currently using the `gcr.io/distroless/nodejs` image for a handful of reasons.**
This is a switch we plan to make, when we can manage it.  We are currently
utilizing the `gcr.io/google-appengine/debian9` image as our base.

To use `nodejs_image`, add the following to `WORKSPACE`:

```python
git_repository(
    name = "build_bazel_rules_nodejs",
    # Replace with a real commit SHA
    commit = "{HEAD}",
    remote = "https://github.com/bazelbuild/rules_nodejs.git",
)

load("@build_bazel_rules_nodejs//:defs.bzl", "node_repositories", "npm_install")

# Download Node toolchain, etc.
node_repositories(package_json = ["//:package.json"])

# Install your declared Node.js dependencies
npm_install(
    name = "npm_deps",
    package_json = "//:package.json",
)

# Download base images, etc.
load(
    "@io_bazel_rules_docker//nodejs:image.bzl",
    _nodejs_image_repos = "repositories",
)

_nodejs_image_repos()
```

Then in your `BUILD` file, simply rewrite `nodejs_binary` to `nodejs_image` with
the following import:
```python
load("@io_bazel_rules_docker//nodejs:image.bzl", "nodejs_image")

nodejs_image(
    name = "nodejs_image",
    entry_point = "your_workspace/path/to/file.js",
    # This will be put into its own layer.
    node_modules = "@npm_deps//:node_modules",
    data = [":file.js"],
    ...
)
```

### go_image

To use `go_image`, add the following to `WORKSPACE`:

```python
# You *must* import the Go rules before setting up the go_image rules.
git_repository(
    name = "io_bazel_rules_go",
    commit = "{HEAD}",
    remote = "https://github.com/bazelbuild/rules_go.git",
)

load("@io_bazel_rules_go//go:def.bzl", "go_repositories")

go_repositories()

load(
    "@io_bazel_rules_docker//go:image.bzl",
    _go_image_repos = "repositories",
)

_go_image_repos()
```

Then in your `BUILD` file, simply rewrite `go_binary` to `go_image` with the
following import:
```python
load("@io_bazel_rules_docker//go:image.bzl", "go_image")

go_image(
    name = "go_image",
    srcs = ["main.go"],
    importpath = "github.com/your/path/here",
)
```

### go_image (custom base)

To use a custom base image, with any of the `lang_image`
rules, you can override the default `base="..."` attribute.  Consider this
modified sample from the `distroless` repository:
```python
load("@bazel_tools//tools/build_defs/pkg:pkg.bzl", "pkg_tar")

# Create a passwd file with a root and nonroot user and uid.
passwd_entry(
    username = "root",
    uid = 0,
    gid = 0,
    name = "root_user",
)

passwd_entry(
    username = "nonroot",
    info = "nonroot",
    uid = 1002,
    name = "nonroot_user",
)

passwd_file(
    name = "passwd",
    entries = [
        ":root_user",
        ":nonroot_user",
    ],
)

# Create a tar file containing the created passwd file
pkg_tar(
    name = "passwd_tar",
    srcs = [":passwd"],
    mode = "0644",
    package_dir = "etc",
)

# Include it in our base image as a tar.
container_image(
    name = "passwd_image",
    base = "@go_image_base//image",
    tars = [":passwd_tar"],
    user = "nonroot",
)

# Simple go program to print out the username and uid.
go_image(
    name = "user",
    srcs = ["user.go"],
    # Override the base image.
    base = ":passwd_image",
)
```


### java_image

To use `java_image`, add the following to `WORKSPACE`:

```python
load(
    "@io_bazel_rules_docker//java:image.bzl",
    _java_image_repos = "repositories",
)

_java_image_repos()
```

Then in your `BUILD` file, simply rewrite `java_binary` to `java_image` with the
following import:
```python
load("@io_bazel_rules_docker//java:image.bzl", "java_image")

java_image(
    name = "java_image",
    srcs = ["Binary.java"],
    # Put these runfiles into their own layer.
    layers = [":java_image_library"],
    main_class = "examples.images.Binary",
)
```

### war_image

To use `war_image`, add the following to `WORKSPACE`:

```python
load(
    "@io_bazel_rules_docker//java:image.bzl",
    _java_image_repos = "repositories",
)

_java_image_repos()
```

Then in your `BUILD` file, simply rewrite `java_war` to `war_image` with the
following import:
```python
load("@io_bazel_rules_docker//java:image.bzl", "war_image")

war_image(
    name = "war_image",
    srcs = ["Servlet.java"],
    # Put these JARs into their own layers.
    layers = [
        ":java_image_library",
        "@javax_servlet_api//jar:jar",
    ],
)
```

### scala_image

To use `scala_image`, add the following to `WORKSPACE`:

```python
# You *must* import the Scala rules before setting up the scala_image rules.
git_repository(
    name = "io_bazel_rules_scala",
    commit = "{HEAD}",
    remote = "https://github.com/bazelbuild/rules_scala.git",
)

load("@io_bazel_rules_scala//scala:scala.bzl", "scala_repositories")

scala_repositories()

load(
    "@io_bazel_rules_docker//scala:image.bzl",
    _scala_image_repos = "repositories",
)

_scala_image_repos()
```

Then in your `BUILD` file, simply rewrite `scala_binary` to `scala_image` with the
following import:
```python
load("@io_bazel_rules_docker//scala:image.bzl", "scala_image")

scala_image(
    name = "scala_image",
    srcs = ["Binary.scala"],
    main_class = "examples.images.Binary",
)
```

### groovy_image

To use `groovy_image`, add the following to `WORKSPACE`:

```python
# You *must* import the Groovy rules before setting up the groovy_image rules.
git_repository(
    name = "io_bazel_rules_groovy",
    commit = "{HEAD}",
    remote = "https://github.com/bazelbuild/rules_groovy.git",
)

load("@io_bazel_rules_groovy//groovy:groovy.bzl", "groovy_repositories")

groovy_repositories()

load(
    "@io_bazel_rules_docker//groovy:image.bzl",
    _groovy_image_repos = "repositories",
)

_groovy_image_repos()
```

Then in your `BUILD` file, simply rewrite `groovy_binary` to `groovy_image` with the
following import:
```python
load("@io_bazel_rules_docker//groovy:image.bzl", "groovy_image")

groovy_image(
    name = "groovy_image",
    srcs = ["Binary.groovy"],
    main_class = "examples.images.Binary",
)
```

### rust_image

To use `rust_image`, add the following to `WORKSPACE`:

```python
# You *must* import the Rust rules before setting up the rust_image rules.
git_repository(
    name = "io_bazel_rules_rust",
    commit = "{HEAD}",
    remote = "https://github.com/bazelbuild/rules_rust.git",
)

load("@io_bazel_rules_rust//rust:repositories.bzl", "rust_repositories")

rust_repositories()

load(
    "@io_bazel_rules_docker//rust:image.bzl",
    _rust_image_repos = "repositories",
)

_rust_image_repos()
```

Then in your `BUILD` file, simply rewrite `rust_binary` to `rust_image` with the
following import:
```python
load("@io_bazel_rules_docker//rust:image.bzl", "rust_image")

rust_image(
    name = "rust_image",
    srcs = ["main.rs"],
)
```

### d_image

To use `d_image`, add the following to `WORKSPACE`:

```python
# You *must* import the D rules before setting up the d_image rules.
git_repository(
    name = "io_bazel_rules_d",
    commit = "{HEAD}",
    remote = "https://github.com/bazelbuild/rules_d.git",
)

load("@io_bazel_rules_d//d:d.bzl", "d_repositories")

d_repositories()

load(
    "@io_bazel_rules_docker//d:image.bzl",
    _d_image_repos = "repositories",
)

_d_image_repos()
```

Then in your `BUILD` file, simply rewrite `d_binary` to `d_image` with the
following import:
```python
load("@io_bazel_rules_docker//d:image.bzl", "d_image")

d_image(
    name = "d_image",
    srcs = ["main.d"],
)
```

### container_bundle

```python
container_bundle(
    name = "bundle",
    images = {
        # A set of images to bundle up into a single tarball.
        "gcr.io/foo/bar:bazz": ":app",
        "gcr.io/foo/bar:blah": "//my:sidecar",
        "gcr.io/foo/bar:booo": "@your//random:image",
    }
)
```

### container_pull

In `WORKSPACE`:

```python
container_pull(
    name = "base",
    registry = "gcr.io",
    repository = "my-project/my-base",
    # 'tag' is also supported, but digest is encouraged for reproducibility.
    digest = "sha256:deadbeef",
)
```

This can then be referenced in `BUILD` files as `@base//image`.

### container_push

This target pushes on `bazel run :push_foo`:

``` python
container_push(
   name = "push_foo",
   image = ":foo",
   format = "Docker",
   registry = "gcr.io",
   repository = "my-project/my-image",
   tag = "dev",
)
```

We also support the `docker_push` (from `docker/docker.bzl`) and `oci_push`
(from `oci/oci.bzl`) aliases, which bake in the `format = "..."` attribute.

### container_pull (DockerHub)

In `WORKSPACE`:

```python
container_pull(
    name = "official_ubuntu",
    registry = "index.docker.io",
    repository = "library/ubuntu",
    tag = "14.04",
)
```

This can then be referenced in `BUILD` files as `@official_ubuntu//image`.

### container_pull (Quay.io)

In `WORKSPACE`:

```python
container_pull(
    name = "etcd",
    registry = "quay.io",
    repository = "coreos/etcd",
    tag = "latest",
)
```

This can then be referenced in `BUILD` files as `@etcd//image`.

### container_pull (Bintray.io)

In `WORKSPACE`:

```python
container_pull(
    name = "artifactory",
    registry = "docker.bintray.io",
    repository = "jfrog/artifactory-pro",
)
```

This can then be referenced in `BUILD` files as `@artifactory//image`.

### container_pull (Gitlab)

In `WORKSPACE`:

```python
container_pull(
    name = "gitlab",
    registry = "registry.gitlab.com",
    repository = "username/project/image",
    tag = "tag",
)
```

This can then be referenced in `BUILD` files as `@gitlab//image`.

**NOTE:** This will only work on systems with Python >2.7.6

## Updating the `distroless` base images.

The digest references to the `distroless` base images must be updated over time
to pick up bug fixes and security patches.  To facilitate this, the files
containing the digest references are generated by `tools/update_deps.py`.  To
update all of the dependencies, please run (from the root of the repository):
```shell
./update_deps.sh
```

Image references should not be update individually because these images have
shared layers and letting them diverge could result in sub-optimal push and pull
 performance.

<a name="container_pull"></a>
## container_pull

```python
container_pull(name, registry, repository, digest, tag)
```

A repository rule that pulls down a Docker base image in a manner suitable for
use with `container_image`'s `base` attribute.

**NOTE:** Set `PULLER_TIMEOUT` env variable to change the default 600s timeout.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p><code>Name, required</code></p>
        <p>Unique name for this repository rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>registry</code></td>
      <td>
        <p><code>Registry Domain; required</code></p>
        <p>The registry from which to pull the base image.</p>
      </td>
    </tr>
    <tr>
      <td><code>repository</code></td>
      <td>
        <p><code>Repository; required</code></p>
        <p>The `repository` of images to pull from.</p>
      </td>
    </tr>
    <tr>
      <td><code>digest</code></td>
      <td>
        <p><code>string; optional</code></p>
        <p>The `digest` of the Docker image to pull from the specified
           `repository`.</p>
        <p>
          <strong>Note:</strong> For reproducible builds, use of `digest`
          is recommended.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>tag</code></td>
      <td>
        <p><code>string; optional</code></p>
        <p>The `tag` of the Docker image to pull from the specified `repository`.
           If neither this nor `digest` is specified, this attribute defaults
           to `latest`.  If both are specified, then `tag` is ignored.</p>
        <p>
          <strong>Note:</strong> For reproducible builds, use of `digest`
          is recommended.
        </p>
      </td>
    </tr>
  </tbody>
</table>

<a name="container_push"></a>
## container_push

```python
container_push(name, image, registry, repository, tag)
```

An executable rule that pushes a Docker image to a Docker registry on `bazel run`.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p><code>Name, required</code></p>
        <p>Unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>format</code></td>
      <td>
        <p><code>Kind, required</code></p>
        <p>The desired format of the published image.  Currently, this supports
	   <code>Docker</code> and <code>OCI</code></p>
      </td>
    </tr>
    <tr>
      <td><code>image</code></td>
      <td>
        <p><code>Label; required</code></p>
        <p>The label containing a Docker image to publish.</p>
      </td>
    </tr>
    <tr>
      <td><code>registry</code></td>
      <td>
        <p><code>Registry Domain; required</code></p>
        <p>The registry to which to publish the image.</p>
	<p>This field supports stamp variables.</p>
      </td>
    </tr>
    <tr>
      <td><code>repository</code></td>
      <td>
        <p><code>Repository; required</code></p>
        <p>The `repository` of images to which to push.</p>
	<p>This field supports stamp variables.</p>
      </td>
    </tr>
    <tr>
      <td><code>tag</code></td>
      <td>
        <p><code>string; optional</code></p>
        <p>The `tag` of the Docker image to push to the specified `repository`.
           This attribute defaults to `latest`.</p>
	<p>This field supports stamp variables.</p>
      </td>
    </tr>
    <tr>
      <td><code>stamp</code></td>
      <td>
        <p><code>Bool; optional</code></p>
        <p>If true, enable use of workspace status variables
        (e.g. <code>BUILD_USER</code>, <code>BUILD_EMBED_LABEL</code>,
        and custom values set using <code>--workspace_status_command</code>)
        in tags.</p>
        <p>These fields are specified in the tag using using Python format
        syntax, e.g.
        <code>example.org/{BUILD_USER}/image:{BUILD_EMBED_LABEL}</code>.</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="container_image"></a>
## container_image

```python
container_image(name, base, data_path, directory, files, legacy_repository_naming, mode, tars, debs, symlinks, entrypoint, cmd, env, labels, ports, volumes, workdir, repository)
```

<table class="table table-condensed table-bordered table-implicit">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Implicit output targets</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code><i>name</i>.tar</code></td>
      <td>
        <code>The full Docker image</code>
        <p>
            A full Docker image containing all the layers, identical to
            what <code>docker save</code> would return. This is
            only generated on demand.
        </p>
      </td>
    </tr>
    <tr>
      <td><code><i>name</i>-layer.tar</code></td>
      <td>
        <code>An image of the current layer</code>
        <p>
            A Docker image containing only the layer corresponding to
            that target. It is used for incremental loading of the layer.
        </p>
        <p>
            <b>Note:</b> this target is not suitable for direct consumption.
            It is used for incremental loading and non-docker rules should
            depends on the Docker image (<i>name</i>.tar) instead.
        </p>
      </td>
    </tr>
    <tr>
      <td><code><i>name</i></code></td>
      <td>
        <code>Incremental image loader</code>
        <p>
            The incremental image loader. It will load only changed
            layers inside the Docker registry.
        </p>
      </td>
    </tr>
  </tbody>
</table>

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>Name, required</code>
        <p>A unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>base</code></td>
      <td>
        <code>File, optional</code>
        <p>
            The base layers on top of which to overlay this layer, equivalent to
            FROM.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>data_path</code></td>
      <td>
        <code>String, optional</code>
        <p>Root path of the files.</p>
        <p>
          The directory structure from the files is preserved inside the
          Docker image, but a prefix path determined by `data_path`
          is removed from the directory structure. This path can
          be absolute from the workspace root if starting with a `/` or
          relative to the rule's directory. A relative path may starts with "./"
          (or be ".") but cannot use go up with "..". By default, the
          `data_path` attribute is unused, and all files should have no prefix.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>directory</code></td>
      <td>
        <code>String, optional</code>
        <p>Target directory.</p>
        <p>
          The directory in which to expand the specified files, defaulting to '/'.
          Only makes sense accompanying one of files/tars/debs.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>files</code></td>
      <td>
        <code>List of files, optional</code>
        <p>File to add to the layer.</p>
        <p>
          A list of files that should be included in the Docker image.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>legacy_repository_naming</code></td>
      <td>
        <code>Bool, default to False</code>
        <p>
          Whether to use the legacy strategy for setting the repository name
          embedded in the resulting tarball.
          e.g. <code>bazel/{target.replace('/', '_')}</code>
          vs. <code>bazel/{target}</code>
        </p>
      </td>
    </tr>
    <tr>
      <td><code>mode</code></td>
      <td>
        <code>String, default to 0555</code>
        <p>
          Set the mode of files added by the <code>files</code> attribute.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>tars</code></td>
      <td>
        <code>List of files, optional</code>
        <p>Tar file to extract in the layer.</p>
        <p>
          A list of tar files whose content should be in the Docker image.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>debs</code></td>
      <td>
        <code>List of files, optional</code>
        <p>Debian package to install.</p>
        <p>
          A list of debian packages that will be installed in the Docker image.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>symlinks</code></td>
      <td>
        <code>Dictionary, optional</code>
        <p>Symlinks to create in the Docker image.</p>
        <p>
          <code>
          symlinks = {
           "/path/to/link": "/path/to/target",
           ...
          },
          </code>
        </p>
      </td>
    </tr>
    <tr>
      <td><code>user</code></td>
      <td>
        <code>String, optional</code>
        <p><a href="https://docs.docker.com/engine/reference/builder/#user">The user
               that the image should run as.</a></p>
        <p>Because building the image never happens inside a Docker container,
               this user does not affect the other actions (e.g.,
               adding files).</p>
	<p>This field supports stamp variables.</p>
      </td>
    </tr>
    <tr>
      <td><code>entrypoint</code></td>
      <td>
        <code>String or string list, optional</code>
        <p><a href="https://docs.docker.com/engine/reference/builder/#entrypoint">List
               of entrypoints to add in the image.</a></p>
	<p>This field supports stamp variables.</p>
      </td>
    </tr>
    <tr>
      <td><code>cmd</code></td>
      <td>
        <code>String or string list, optional</code>
        <p><a href="https://docs.docker.com/engine/reference/builder/#cmd">List
               of commands to execute in the image.</a></p>
	<p>This field supports stamp variables.</p>
      </td>
    </tr>
    <tr>
      <td><code>env</code></td>
      <td>
        <code>Dictionary from strings to strings, optional</code>
        <p><a href="https://docs.docker.com/engine/reference/builder/#env">Dictionary
               from environment variable names to their values when running the
               Docker image.</a></p>
        <p>
          <code>
          env = {
            "FOO": "bar",
            ...
          },
          </code>
        </p>
	<p>The values of this field support stamp variables.</p>
      </td>
    </tr>
    <tr>
      <td><code>labels</code></td>
      <td>
        <code>Dictionary from strings to strings, optional</code>
        <p><a href="https://docs.docker.com/engine/reference/builder/#label">Dictionary
               from custom metadata names to their values. You can also put a
               file name prefixed by '@' as a value. Then the value is replaced
               with the contents of the file.</a></p>
        <p>
          <code>
          labels = {
            "com.example.foo": "bar",
            "com.example.baz": "@metadata.json",
            ...
          },
          </code>
        </p>
	<p>The values of this field support stamp variables.</p>
      </td>
    </tr>
    <tr>
      <td><code>ports</code></td>
      <td>
        <code>String list, optional</code>
        <p><a href="https://docs.docker.com/engine/reference/builder/#expose">List
               of ports to expose.</a></p>
      </td>
    </tr>
    <tr>
      <td><code>volumes</code></td>
      <td>
        <code>String list, optional</code>
        <p><a href="https://docs.docker.com/engine/reference/builder/#volumes">List
               of volumes to mount.</a></p>
      </td>
    </tr>
    <tr>
      <td><code>workdir</code></td>
      <td>
        <code>String, optional</code>
        <p><a href="https://docs.docker.com/engine/reference/builder/#workdir">Initial
               working directory when running the Docker image.</a></p>
        <p>Because building the image never happens inside a Docker container,
               this working directory does not affect the other actions (e.g.,
               adding files).</p>
	<p>This field supports stamp variables.</p>
      </td>
    </tr>
    <tr>
      <td><code>repository</code></td>
      <td>
        <code>String, default to `bazel`</code>
        <p>The repository for the default tag for the image.</a></p>
        <p>Images generated by `container_image` are tagged by default to
           `bazel/package_name:target` for a `container_image` target at
           `//package/name:target`. Setting this attribute to
           `gcr.io/dummy` would set the default tag to
           `gcr.io/dummy/package_name:target`.</p>
      </td>
    </tr>
    <tr>
      <td><code>stamp</code></td>
      <td>
        <p><code>Bool; optional</code></p>
        <p>If true, enable use of workspace status variables
        (e.g. <code>BUILD_USER</code>, <code>BUILD_EMBED_LABEL</code>,
        and custom values set using <code>--workspace_status_command</code>)
        in tags.</p>
        <p>These fields are specified in attributes using using Python format
        syntax, e.g. <code>foo{BUILD_USER}bar</code>.</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="container_bundle"></a>
## container_bundle

```python
container_bundle(name, images)
```

A rule that aliases and saves N images into a single `docker save` tarball.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p><code>Name, required</code></p>
        <p>Unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>images</code></td>
      <td>
        <p><code>Map of Tag to image Label; required</code></p>
        <p>A collection of the images to save into the tarball.</p>
        <p>The keys are the tags with which to alias the image specified by the
           value. These tags may contain make variables (<code>$FOO</code>),
           and if <code>stamp</code> is set to true, may also contain workspace
           status variables (<code>{BAR}</code>).</p>
        <p>The values may be the output of <code>container_pull</code>,
           <code>container_image</code>, or a <code>docker save</code> tarball.</p>
      </td>
    </tr>
    <tr>
      <td><code>stamp</code></td>
      <td>
        <p><code>Bool; optional</code></p>
        <p>If true, enable use of workspace status variables
        (e.g. <code>BUILD_USER</code>, <code>BUILD_EMBED_LABEL</code>,
        and custom values set using <code>--workspace_status_command</code>)
        in tags.</p>
        <p>These fields are specified in the tag using using Python format
        syntax, e.g.
        <code>example.org/{BUILD_USER}/image:{BUILD_EMBED_LABEL}</code>.</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="container_import"></a>
## container_import

```python
container_import(name, config, layers)
```

A rule that imports a docker image into our intermediate form.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p><code>Name, required</code></p>
        <p>Unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>config</code></td>
      <td>
        <p><code>The v2.2 image's json configuration; required</code></p>
        <p>A json configuration file containing the image's metadata.</p>
        <p>This appears in `docker save` tarballs as `<hex>.json` and is
           referenced by `manifest.json` in the config field.</p>
      </td>
    </tr>
    <tr>
      <td><code>layers</code></td>
      <td>
        <p><code>The list of layer `.tar`s or `.tar.gz`s; required</code></p>
        <p>The list of layer <code>.tar.gz</code> files in the order they
           appear in the <code>config.json</code>'s layer section, or in the
           order that they appear in <code>docker save</code> tarballs'
           <code>manifest.json</code> <code>Layers</code> field (these may or
           may not be gzipped). Note that the layers should each have a
           different basename.</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="container_load"></a>
## container_load

```python
container_load(name, file)
```

A repository rule that examines the contents of a `docker save` tarball and
creates a `container_import` target. The created target can be referenced as
`@label_name//image`.

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <p><code>Name, required</code></p>
        <p>Unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>file</code></td>
      <td>
        <p><code>The `docker save` tarball file; required</code></p>
        <p>A label targetting a single file which is a compressed or
           uncompressed tar, as obtained through `docker save IMAGE`.</p>
      </td>
    </tr>
  </tbody>
</table>
