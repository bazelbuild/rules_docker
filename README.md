# Bazel Container Image Rules

Travis CI | Bazel CI
:---: | :---:
[![Build Status](https://travis-ci.org/bazelbuild/rules_docker.svg?branch=master)](https://travis-ci.org/bazelbuild/rules_docker) | [![Build status](https://badge.buildkite.com/693d7892250cfd44beea3cd95573388200935906a28cd3146d.svg)](https://buildkite.com/bazel/docker-rules-docker-postsubmit)

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

* They can be used to develop Docker containers on OSX without
`boot2docker` or `docker-machine` installed. Note use of these rules on Windows
is currently not supported.
* They do not require root access on your workstation.

Also, unlike traditional container builds (e.g. Dockerfile), the Docker images
produced by `container_image` are deterministic / reproducible.

To get started with building Docker images, check out the
[examples](https://github.com/bazelbuild/rules_docker/tree/master/testing/examples)
that build the same images using both rules_docker and a Dockerfile.

__NOTE:__ `container_push` and `container_pull` make use of
[google/go-containerregistry](https://github.com/google/go-containerregistry) for
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

## Docker Rules

This repo now includes rules that provide additional functionality
to install packages and run commands inside docker containers. These
rules, however, require a docker binary is present and properly
configured. These rules include:

* [Package manager rules](docker/package_managers/README.md): rules to install
  apt-get packages.
* [Docker run rules](docker/util/README.md): rules to run commands inside docker
  containers.

### Overview

In addition to low-level rules for building containers, this repository
provides a set of higher-level rules for containerizing applications.  The idea
behind these rules is to make containerizing an application built via a
`lang_binary` rule as simple as changing it to `lang_image`.

By default these higher level rules make use of the [`distroless`](
https://github.com/googlecloudplatform/distroless) language runtimes, but these
can be overridden via the `base="..."` attribute (e.g. with a `container_pull`
or `container_image` target).

Note also that these rules do not expose any docker related attributes. If you
need to add a custom `env` or `symlink` to a `lang_image`, you must use
`container_image` targets for this purpose. Specifically, you can use as base for your
`lang_image` target a `container_image` target that adds e.g., custom `env` or `symlink`.
Please see <a href=#go_image-custom-base>go_image (custom base)</a> for an example.

## Setup

Add the following to your `WORKSPACE` file to add the external repositories:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
  # Get copy paste instructions for the http_archive attributes from the
  # release notes at https://github.com/bazelbuild/rules_docker/releases
)

# OPTIONAL: Call this to override the default docker toolchain configuration.
# This call should be placed BEFORE the call to "container_repositories" below
# to actually override the default toolchain configuration.
# Note this is only required if you actually want to call
# docker_toolchain_configure with a custom attr; please read the toolchains
# docs in /toolchains/docker/ before blindly adding this to your WORKSPACE.
# BEGIN OPTIONAL segment:
load("@io_bazel_rules_docker//toolchains/docker:toolchain.bzl",
    docker_toolchain_configure="toolchain_configure"
)
docker_toolchain_configure(
  name = "docker_config",
  # OPTIONAL: Path to a directory which has a custom docker client config.json.
  # See https://docs.docker.com/engine/reference/commandline/cli/#configuration-files
  # for more details.
  client_config="<enter absolute path to your docker config directory here>",
  # OPTIONAL: Path to the docker binary.
  # Should be set explicitly for remote execution.
  docker_path="<enter absolute path to the docker binary (in the remote exec env) here>",
  # OPTIONAL: Path to the gzip binary.
  gzip_path="<enter absolute path to the gzip binary (in the remote exec env) here>",
  # OPTIONAL: Bazel target for the gzip tool.
  gzip_target="<enter absolute path (i.e., must start with repo name @...//:...) to an executable gzip target>",
  # OPTIONAL: Path to the xz binary.
  # Should be set explicitly for remote execution.
  xz_path="<enter absolute path to the xz binary (in the remote exec env) here>",
  # OPTIONAL: List of additional flags to pass to the docker command.
  docker_flags = [
    "--tls",
    "--log-level=info",
  ],

)
# End of OPTIONAL segment.

load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)
container_repositories()

load("@io_bazel_rules_docker//repositories:deps.bzl", container_deps = "deps")

container_deps()

load(
    "@io_bazel_rules_docker//container:container.bzl",
    "container_pull",
)

container_pull(
  name = "java_base",
  registry = "gcr.io",
  repository = "distroless/java",
  # 'tag' is also supported, but digest is encouraged for reproducibility.
  digest = "sha256:deadbeef",
)
```

### Known Issues

* Bazel does not deal well with diamond dependencies.


If the repositories that are imported by `container_repositories()` have already been
imported (at a different version) by other rules you called in your `WORKSPACE`, which
are placed above the call to `container_repositories()`, arbitrary errors might
occur. If you get errors related to external repositories, you will likely
not be able to use `container_repositories()` and will have to import
directly in your `WORKSPACE` all the required dependencies (see the most up
to date impl of `container_repositories()` for details).

* ImportError: No module named moves.urllib.parse

This is an example of an error due to a diamond dependency. If you get this
error, make sure to import rules_docker before other libraries, so that
_six_ can be patched properly.

  See https://github.com/bazelbuild/rules_docker/issues/1022 for more details.

* Ensure your project has a `BUILD` or `BUILD.bazel` file at the top level. This
can be a blank file if necessary. Otherwise you might see an error that looks
like:
```
Unable to load package for //:WORKSPACE: BUILD file not found in any of the following directories.
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
`bazel-bin/my/image/helloworld.tar`, which you can load into
your local Docker client by running:
`docker load -i bazel-bin/my/image/helloworld.tar`.  Building
this target can be expensive for large images.

These work with both `container_image`, `container_bundle`, and the
`lang_image` rules.  For everything except
`container_bundle`, the image name will be `bazel/my/image:helloworld`.
For `container_bundle`, it will apply the tags you have specified.

## Authentication

You can use these rules to access private images using standard Docker
authentication methods.  e.g. to utilize the [Google Container Registry](
https://gcr.io). See
[here](https://cloud.google.com/container-registry/docs/advanced-authentication) for authentication methods.

See also:
 * [Amazon ECR Docker Credential Helper](
 https://github.com/awslabs/amazon-ecr-credential-helper)
 * [Azure Docker Credential Helper](
 https://github.com/Azure/acr-docker-credential-helper)

Once you've setup your docker client configuration, see [here](#container_pull-custom-client-configuration)
for an example of how to use `container_pull` with custom docker authentication credentials
and [here](#container_push-custom-client-configuration) for an example of how
to use `container_push` with custom docker authentication credentials.

## Varying image names

A common request from folks using `container_push` or `container_bundle` is to
be able to vary the tag that is pushed or embedded.  There are two options
at present for doing this.

### Stamping

The first option is to use stamping. Stamping is enabled when a supported
attribute contains a python format placeholder (e.g. `{BUILD_USER}`).

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

Hint: if you want to put files in specific directories inside the image
use <a href="https://docs.bazel.build/versions/master/be/pkg.html">`pkg_tar` rule</a>
to create the desired directory structure and pass that to `container_image` via
`tars` attribute. Note you might need to set `strip_prefix = "."` or `strip_prefix = "{some directory}"`
in your rule for the files to not be flattened.
See <a href="https://github.com/bazelbuild/bazel/issues/2176">Bazel upstream issue 2176</a> and
 <a href="https://github.com/bazelbuild/rules_docker/issues/317">rules_docker issue 317</a>
for more details.


### cc_image

To use `cc_image`, add the following to `WORKSPACE`:

```python
load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

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

To use `cc_image` (or `go_image`, `d_image`, `rust_image`) with an external
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

If you need to modify somehow the container produced by
`cc_image` (e.g., `env`, `symlink`), see note above in
<a href=#overview-1>Language Rules Overview</a> about how to do this
and see <a href=#go_image-custom-base>go_image (custom base)</a> example below.

### py_image

To use `py_image`, add the following to `WORKSPACE`:

```python
load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

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

If you need to modify somehow the container produced by
`py_image` (e.g., `env`, `symlink`), see note above in
<a href=#overview-1>Language Rules Overview</a> about how to do this
and see <a href=#go_image-custom-base>go_image (custom base)</a> example below.

If you are using `py_image` with a custom base that has python tools installed
in a location different to the default base, please see
<a href=#python-tools>Python tools</a>.

### py_image (fine layering)

For Python and Java's `lang_image` rules, you can factor
dependencies that don't change into their own layers by overriding the
`layers=[]` attribute.  Consider this sample from the `rules_k8s` repository:

```python
py_image(
    name = "server",
    srcs = ["server.py"],
    # "layers" is just like "deps", but it also moves the dependencies each into
    # their own layer, which can dramatically improve developer cycle time. For
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

You can also implement more complex fine layering strategies by using the
`py_layer` rule and its `filter` attribute.  For example:

```python
# Suppose that we are synthesizing an image that depends on a complex set
# of libraries that we want to break into layers.
LIBS = [
    "//pkg/complex_library",
    # ...
]
# First, we extract all transitive dependencies of LIBS that are under //pkg/common.
py_layer(
    name = "common_deps",
    deps = LIBS,
    filter = "//pkg/common",
)
# Then, we further extract all external dependencies of the deps under //pkg/common.
py_layer(
    name = "common_external_deps",
    deps = [":common_deps"],
    filter = "@",
)
# We also extract all external dependencies of LIBS, which is a superset of
# ":common_external_deps".
py_layer(
    name = "external_deps",
    deps = LIBS,
    filter = "@",
)
# Finally, we create the image, stacking the above filtered layers on top of one
# another in the "layers" attribute.  The layers are applied in order, and any
# dependencies already added to the image will not be added again.  Therefore,
# ":external_deps" will only add the external dependencies not present in
# ":common_external_deps".
py_image(
    name = "image",
    deps = LIBS,
    layers = [
        ":common_external_deps",
        ":common_deps",
        ":external_deps",
    ],
    # ...
)
```

### py3_image

To use a Python 3 runtime instead of the default of Python 2, use `py3_image`,
instead of `py_image`.  The other semantics are identical.

If you need to modify somehow the container produced by
`py3_image` (e.g., `env`, `symlink`), see note above in
<a href=#overview-1>Language Rules Overview</a> about how to do this
and see <a href=#go_image-custom-base>go_image (custom base)</a> example below.

If you are using `py3_image` with a custom base that has python tools installed
in a location different to the default base, please see
<a href=#python-tools>Python tools</a>.

### nodejs_image

**It is notable that unlike the other image rules, `nodejs_image` is not
currently using the `gcr.io/distroless/nodejs` image for a handful of reasons.**
This is a switch we plan to make, when we can manage it.  We are currently
utilizing the `gcr.io/google-appengine/debian9` image as our base.

To use `nodejs_image`, add the following to `WORKSPACE`:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "build_bazel_rules_nodejs",
    # Replace with a real SHA256 checksum
    sha256 = "{SHA256}"
    # Replace with a real release version
    urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/{VERSION}/rules_nodejs-{VERSION}.tar.gz"],
)


load("@build_bazel_rules_nodejs//:index.bzl", "npm_install")

# Install your declared Node.js dependencies
npm_install(
    name = "npm",
    package_json = "//:package.json",
    yarn_lock = "//:yarn.lock",
)

load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

load(
    "@io_bazel_rules_docker//nodejs:image.bzl",
    _nodejs_image_repos = "repositories",
)

_nodejs_image_repos()
```

Note: See note about diamond dependencies in <a href=#setup>setup</a>
if you run into issues related to external repos after adding these
lines to your `WORKSPACE`.

Then in your `BUILD` file, simply rewrite `nodejs_binary` to `nodejs_image` with
the following import:

```python
load("@io_bazel_rules_docker//nodejs:image.bzl", "nodejs_image")

nodejs_image(
    name = "nodejs_image",
    entry_point = "@your_workspace//path/to:file.js",
    # npm deps will be put into their own layer
    data = [":file.js", "@npm//some-npm-dep"],
    ...
)
```

If you need to modify somehow the container produced by
`nodejs_image` (e.g., `env`, `symlink`), see note above in
<a href=#overview-1>Language Rules Overview</a> about how to do this
and see <a href=#go_image-custom-base>go_image (custom base)</a> example below.

### go_image

To use `go_image`, add the following to `WORKSPACE`:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

load(
    "@io_bazel_rules_docker//go:image.bzl",
    _go_image_repos = "repositories",
)

_go_image_repos()
```

Note: See note about diamond dependencies in <a href=#setup>setup</a>
if you run into issues related to external repos after adding these
lines to your `WORKSPACE`.

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
Notice that it is important to explicitly build this target with the
`--platforms=@io_bazel_rules_go//go/toolchain:linux_amd64` flag
as the binary should be built for Linux since it will run in a Linux container.

If you need to modify somehow the container produced by
`go_image` (e.g., `env`, `symlink`), see note above in
<a href=#overview-1>Language Rules Overview</a> about how to do this and
see example below.

### go_image (custom base)

To use a custom base image, with any of the `lang_image`
rules, you can override the default `base="..."` attribute.  Consider this
modified sample from the `distroless` repository:

```python
load("@rules_pkg//:pkg.bzl", "pkg_tar")

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
    mode = "0o644",
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
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

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

If you need to modify somehow the container produced by
`java_image` (e.g., `env`, `symlink`), see note above in
<a href=#overview-1>Language Rules Overview</a> about how to do this
and see <a href=#go_image-custom-base>go_image (custom base)</a> example.

### war_image

To use `war_image`, add the following to `WORKSPACE`:

```python
load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

load(
    "@io_bazel_rules_docker//java:image.bzl",
    _java_image_repos = "repositories",
)

_java_image_repos()
```

Note: See note about diamond dependencies in <a href=#setup>setup</a>
if you run into issues related to external repos after adding these
lines to your `WORKSPACE`.

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

The produced image uses Jetty 9.x to serve the web application. Servlets included in the web application need to follow the API specification 3.0. For best compatibility, use a [Servlet dependency provided by the Jetty project](https://search.maven.org/search?q=g:org.mortbay.jetty%20AND%20a:servlet-api&core=gav).

A Servlet implementation needs to declare the `@WebServlet` annotation to be auto-discovered. The use of a `web.xml` to declare the Servlet URL mapping is not supported.

If you need to modify somehow the container produced by
`war_image` (e.g., `env`, `symlink`), see note above in
<a href=#overview-1>Language Rules Overview</a> about how to do this
and see <a href=#go_image-custom-base>go_image (custom base)</a> example.

### scala_image

To use `scala_image`, add the following to `WORKSPACE`:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# You *must* import the Scala rules before setting up the scala_image rules.
http_archive(
    name = "io_bazel_rules_scala",
    # Replace with a real SHA256 checksum
    sha256 = "{SHA256}"
    # Replace with a real commit SHA
    strip_prefix = "rules_scala-{HEAD}",
    urls = ["https://github.com/bazelbuild/rules_scala/archive/{HEAD}.tar.gz"],
)

load("@io_bazel_rules_scala//scala:scala.bzl", "scala_repositories")

scala_repositories()

load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

load(
    "@io_bazel_rules_docker//scala:image.bzl",
    _scala_image_repos = "repositories",
)

_scala_image_repos()
```

Note: See note about diamond dependencies in <a href=#setup>setup</a>
if you run into issues related to external repos after adding these
lines to your `WORKSPACE`.

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

If you need to modify somehow the container produced by
`scala_image` (e.g., `env`, `symlink`), see note above in
<a href=#overview-1>Language Rules Overview</a> about how to do this
and see <a href=#go_image-custom-base>go_image (custom base)</a> example.

### groovy_image

To use `groovy_image`, add the following to `WORKSPACE`:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# You *must* import the Groovy rules before setting up the groovy_image rules.
http_archive(
    name = "io_bazel_rules_groovy",
    # Replace with a real SHA256 checksum
    sha256 = "{SHA256}"
    # Replace with a real commit SHA
    strip_prefix = "rules_groovy-{HEAD}",
    urls = ["https://github.com/bazelbuild/rules_groovy/archive/{HEAD}.tar.gz"],
)

load("@io_bazel_rules_groovy//groovy:groovy.bzl", "groovy_repositories")

groovy_repositories()

load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

load(
    "@io_bazel_rules_docker//groovy:image.bzl",
    _groovy_image_repos = "repositories",
)

_groovy_image_repos()
```

Note: See note about diamond dependencies in <a href=#setup>setup</a>
if you run into issues related to external repos after adding these
lines to your `WORKSPACE`.

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

If you need to modify somehow the container produced by
`groovy_image` (e.g., `env`, `symlink`), see note above in
<a href=#overview-1>Language Rules Overview</a> about how to do this
and see <a href=#go_image-custom-base>go_image (custom base)</a> example.

### rust_image

To use `rust_image`, add the following to `WORKSPACE`:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# You *must* import the Rust rules before setting up the rust_image rules.
http_archive(
    name = "rules_rust",
    # Replace with a real SHA256 checksum
    sha256 = "{SHA256}"
    # Replace with a real commit SHA
    strip_prefix = "rules_rust-{HEAD}",
    urls = ["https://github.com/bazelbuild/rules_rust/archive/{HEAD}.tar.gz"],
)

load("@rules_rust//rust:repositories.bzl", "rust_repositories")

rust_repositories()

load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

load(
    "@io_bazel_rules_docker//rust:image.bzl",
    _rust_image_repos = "repositories",
)

_rust_image_repos()
```

Note: See note about diamond dependencies in <a href=#setup>setup</a>
if you run into issues related to external repos after adding these
lines to your `WORKSPACE`.

Then in your `BUILD` file, simply rewrite `rust_binary` to `rust_image` with the
following import:

```python
load("@io_bazel_rules_docker//rust:image.bzl", "rust_image")

rust_image(
    name = "rust_image",
    srcs = ["main.rs"],
)
```

If you need to modify somehow the container produced by
`rust_image` (e.g., `env`, `symlink`), see note above in
<a href=#overview-1>Language Rules Overview</a> about how to do this
and see <a href=#go_image-custom-base>go_image (custom base)</a> example.

### d_image

To use `d_image`, add the following to `WORKSPACE`:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# You *must* import the D rules before setting up the d_image rules.
http_archive(
    name = "io_bazel_rules_d",
    # Replace with a real SHA256 checksum
    sha256 = "{SHA256}"
    # Replace with a real commit SHA
    strip_prefix = "rules_d-{HEAD}",
    urls = ["https://github.com/bazelbuild/rules_d/archive/{HEAD}.tar.gz"],
)

load("@io_bazel_rules_d//d:d.bzl", "d_repositories")

d_repositories()

load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

load(
    "@io_bazel_rules_docker//d:image.bzl",
    _d_image_repos = "repositories",
)

_d_image_repos()
```

Note: See note about diamond dependencies in <a href=#setup>setup</a>
if you run into issues related to external repos after adding these
lines to your `WORKSPACE`.

Then in your `BUILD` file, simply rewrite `d_binary` to `d_image` with the
following import:

```python
load("@io_bazel_rules_docker//d:image.bzl", "d_image")

d_image(
    name = "d_image",
    srcs = ["main.d"],
)
```

If you need to modify somehow the container produced by
`d_image` (e.g., `env`, `symlink`), see note above in
<a href=#overview-1>Language Rules Overview</a> about how to do this
and see <a href=#go_image-custom-base>go_image (custom base)</a> example.

> NOTE: all application image rules support the `args` string_list
> attribute.  If specified, they will be appended directly after the
> container ENTRYPOINT binary name.

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

To get the correct digest one can run `docker manifest inspect gcr.io/my-project/my-base:tag` once [experimental docker cli features are enabled](https://docs.docker.com/engine/reference/commandline/manifest_inspect).

See [here](#container_pull-custom-client-configuration) for an example of how
to use container_pull with custom docker authentication credentials.

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

See [here](#container_push-custom-client-configuration) for an example of how
to use container_push with custom docker authentication credentials.

### container_push (Custom client configuration)
If you wish to use container_push using custom docker authentication credentials,
in `WORKSPACE`:

```python
# Download the rules_docker repository
http_archive(
    name = "io_bazel_rules_docker",
    ...
)

# Load the macro that allows you to customize the docker toolchain configuration.
load("@io_bazel_rules_docker//toolchains/docker:toolchain.bzl",
    docker_toolchain_configure="toolchain_configure"
)

docker_toolchain_configure(
  name = "docker_config",
  # Replace this with an absolute path to a directory which has a custom docker
  # client config.json. Note relative paths are not supported.
  # Docker allows you to specify custom authentication credentials
  # in the client configuration JSON file.
  # See https://docs.docker.com/engine/reference/commandline/cli/#configuration-files
  # for more details.
  client_config="/path/to/docker/client/config-dir",
)
```
In `BUILD` file:

```python
load("@io_bazel_rules_docker//container:container.bzl", "container_push")

container_push(
   name = "push_foo",
   image = ":foo",
   format = "Docker",
   registry = "gcr.io",
   repository = "my-project/my-image",
   tag = "dev",
)
```

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

### container_pull (Custom client configuration)

If you specified a docker client directory using the `client_config` attribute
to the docker toolchain configuration described <a href="#setup">here</a>, you
can use a container_pull that uses the authentication credentials from the
specified docker client directory as follows:

In `WORKSPACE`:

```python
load("@io_bazel_rules_docker//toolchains/docker:toolchain.bzl",
    docker_toolchain_configure="toolchain_configure"
)

# Configure the docker toolchain.
docker_toolchain_configure(
  name = "docker_config",
  # Path to the directory which has a custom docker client config.json with
  # authentication credentials for registry.gitlab.com (used in this example).
  client_config="/path/to/docker/client/config",
)

# Load the custom version of container_pull created by the docker toolchain
# configuration.
load("@docker_config//:pull.bzl", authenticated_container_pull="container_pull")

authenticated_container_pull(
    name = "gitlab",
    registry = "registry.gitlab.com",
    repository = "username/project/image",
    tag = "tag",
)
```

This can then be referenced in `BUILD` files as `@gitlab//image`.

**NOTE:** This should only be used if a custom `client_config` was set. If you want
          to use the DOCKER_CONFIG env variable or the default home directory
	  use the standard `container_pull` rule.

**NOTE:** This will only work on systems with Python >2.7.6

## Python tools

Starting with Bazel 0.25.0 it's possible to configure python toolchains
for `rules_docker`.

To use these features you need to enable the flags in the `.bazelrc`
file at the root of this project.

Use of these features require a python toolchain to be registered.
`//py_images/image.bzl:deps` and `//py3_images/image.bzl:deps` register a
default python toolchain (`//toolchains/python:container_py_toolchain`)
that defines the path to python tools inside the default container used
for these rules.

### Known issues

If you are using a custom base for `py_image` or `py3_image` builds that has
python tools installed in a different location to those defined in
`//toolchains/python:container_py_toolchain`, you will need to create a
toolchain that points to these paths and register it _before_ the call to
`py*_images/image.bzl:deps` in your `WORKSPACE`.

Use of python toolchain features, currently, only supports picking one
version of python for execution of host tools. `rules_docker` heavily depends
on execution of python host tools that are only compatible with python 2.
Flags in the recommended `.bazelrc` file force all host tools to use python 2.
If your project requires using host tools that are only compatible with
python 3 you will not be able to use these features at the moment. We
expect this issue to be resolved before use of python toolchain features
becomes the default.

## Updating the `distroless` base images.

The digest references to the `distroless` base images must be updated over time
to pick up bug fixes and security patches.  To facilitate this, the files
containing the digest references are generated by `tools/update_deps.py`.  To
update all of the dependencies, please run (from the root of the repository):

```shell
./update_deps.sh
```

Image references should not be updated individually because these images have
shared layers and letting them diverge could result in sub-optimal push and pull
 performance.

<a name="container_pull"></a>
## container_pull

```python
container_pull(name, registry, repository, digest, tag)
```

A repository rule that pulls down a Docker base image in a manner suitable for
use with `container_image`'s `base` attribute.

**NOTE:** `container_pull` now supports authentication using custom docker client
configuration. See [here](#container_pull-custom-client-configuration) for details.

**NOTE:** Set `PULLER_TIMEOUT` env variable to change the default 600s timeout.

**NOTE:** Set `DOCKER_REPO_CACHE` env variable to make the container puller
cache downloaded layers at the directory specified as a value to this env
variable. The caching feature hasn't been thoroughly tested and may be thread
unsafe. If you notice flakiness after enabling it, see the warning below on how
to workaround it.

**NOTE:** `container_pull` is suspected to have thread safety issues. To
ensure multiple `container_pull`(s) don't execute concurrently, please use the
bazel startup flag `--loading_phase_threads=1` in your bazel invocation.

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
    <tr>
      <td><code>os</code></td>
      <td>
        <p><code>string; optional</code></p>
        <p>When the specified image refers to a multi-platform
           <a href="https://docs.docker.com/registry/spec/manifest-v2-2/#manifest-list">
           manifest list</a>, the desired operating system. For example,
           <code>linux</code> or
           <code>windows</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>os_version</code></td>
      <td>
        <p><code>string; optional</code></p>
        <p>When the specified image refers to a multi-platform
           <a href="https://docs.docker.com/registry/spec/manifest-v2-2/#manifest-list">
           manifest list</a>, the desired operating system version. For example,
           <code>10.0.10586</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>os_features</code></td>
      <td>
        <p><code>string list; optional</code></p>
        <p>When the specified image refers to a multi-platform
           <a href="https://docs.docker.com/registry/spec/manifest-v2-2/#manifest-list">
           manifest list</a>, the desired operating system features. For example,
           on Windows this might be <code>["win32k"]</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>architecture</code></td>
      <td>
        <p><code>string; optional</code></p>
        <p>When the specified image refers to a multi-platform
           <a href="https://docs.docker.com/registry/spec/manifest-v2-2/#manifest-list">
           manifest list</a>, the desired CPU architecture. For example,
           <code>amd64</code> or <code>arm</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>cpu_variant</code></td>
      <td>
        <p><code>string; optional</code></p>
        <p>When the specified image refers to a multi-platform
           <a href="https://docs.docker.com/registry/spec/manifest-v2-2/#manifest-list">
           manifest list</a>, the desired CPU variant. For example, for ARM you
           may need to use <code>v6</code> or <code>v7</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>platform_features</code></td>
      <td>
        <p><code>string list; optional</code></p>
        <p>When the specified image refers to a multi-platform
           <a href="https://docs.docker.com/registry/spec/manifest-v2-2/#manifest-list">
           manifest list</a>, the desired features. For example, this may
           include CPU features such as <code>["sse4", "aes"]</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>puller_darwin</code></td>
      <td>
        <p><code>label; optional</code></p>
        <p>A Mac 64-bit binary that implements the functionality provided by
           <code>//container/go/cmd/puller</code>. Visible for testing purposes
           only.</p>
      </td>
    </tr>
    <tr>
      <td><code>puller_linux</code></td>
      <td>
        <p><code>label; optional</code></p>
        <p>A Linux 64-bit binary that implements the functionality provided by
           <code>//container/go/cmd/puller</code>. Visible for testing purposes
           only.</p>
      </td>
    </tr>
    <tr>
      <td><code>docker_client_config</code></td>
      <td>
        <p><code>string; optional</code></p>
        <p>Specifies the directory to look for the docker client configuration. Don't use this directly.
           Specify the docker configuration directory using a custom docker toolchain configuration. Look
           for the <code>client_config</code> attribute in <code>docker_toolchain_configure</code> <a href="#setup">here</a> for
           details. See <a href="#container_pull-custom-client-configuration">here</a> for an example on
           how to use <code>container_pull</code> after configuring the docker toolchain</p>
        <p>When left unspecified (ie not set explicitly or set by the docker toolchain), docker will use
        the directory specified via the DOCKER_CONFIG environment variable. If DOCKER_CONFIG isn't set,
        docker falls back to $HOME/.docker.
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

**NOTE:** `container_push` now supports authentication using custom docker client
configuration. See [here](#container_push-custom-client-configuration) for details.

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
        <p>Deprecated: it is now automatically inferred.</p>
        <p>If true, enable use of workspace status variables
        (e.g. <code>BUILD_USER</code>, <code>BUILD_EMBED_LABEL</code>,
        and custom values set using <code>--workspace_status_command</code>)
        in tags.</p>
        <p>These fields are specified in the tag using Python format
        syntax, e.g.
        <code>example.org/{BUILD_USER}/image:{BUILD_EMBED_LABEL}</code>.</p>
      </td>
    </tr>
  </tbody>
</table>


<a name="container_layer"></a>
## container_layer

```python
container_layer(data_path, directory, empty_dirs, files, mode, tars, debs, symlinks, env)
```

A rule that assembles data into a tarball which can be use as in `layers` attr in `container_image` rule.

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
      <td><code><i>name</i>-layer.tar</code></td>
      <td>
        <code>A tarball of current layer</code>
        <p>
            A data tarball corresponding to the layer.
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
      <td><code>data_path</code></td>
      <td>
        <code>String, optional</code>
        <p>Root path of the files.</p>
        <p>
          The directory structure from the files is preserved inside the
          Docker image, but a prefix path determined by <code>data_path</code>
          is removed from the directory structure. This path can
          be absolute from the workspace root if starting with a `/` or
          relative to the rule's directory. A relative path may starts with "./"
          (or be ".") but cannot use go up with "..". By default, the
          <code>data_path</code> attribute is unused, and all files should have no prefix.
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
      <td><code>empty_dirs</code></td>
      <td>
        <code>List of directories, optional</code>
        <p>Directory to add to the layer.</p>
        <p>
          A list of empty directories that should be created in the Docker image.
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
      <td><code>mode</code></td>
      <td>
        <code>String, default to 0o555</code>
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
        <p>Debian packages to extract.</p>
        <p>
          Deprecated: A list of debian packages that will be extracted in the Docker image.
          Note that this doesn't actually install the packages. Installation needs apt
          or apt-get which need to be executed within a running container which
          <code>container_layer</code> can't do.
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
	<p>The values of this field support make variables (e.g., <code>$(FOO)</code>) and stamp variables; keys support make variables as well.</p>
      </td>
    </tr>
    <tr>
      <td><code>compression</code></td>
      <td>
        <code>String, optional</code>
        <p>Compression method for image layers. Currently only <code>gzip</code> is supported.</p>
        <p>This affects the compressed layer, which is by the `container_push` rule.</p>
        <p>
          <code>
          compression = "gzip",
          </code>
        </p>
      </td>
    </tr>
    <tr>
      <td><code>compression_options</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>Command-line options for the compression tool. Possible values depend on `compression` method.</p>
        <p>This affects the compressed layer, which is by the `container_push` rule.</p>
        <p>
          <code>
          compression_options = ["--fast"],
          </code>
        </p>
      </td>
    </tr>
  </tbody>
</table>

<a name="container_image"></a>
## container_image

```python
container_image(name, base, data_path, directory, files, legacy_repository_naming, mode, tars, debs, symlinks, entrypoint, cmd, creation_time, env, labels, ports, volumes, workdir, layers, repository)
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
      <td><code><i>name</i>.digest</code></td>
      <td>
        <code>The full Docker image's digest</code>
        <p>
            An image digest that can be used to refer to that image. Unlike tags,
            digest references are immutable i.e. always refer to the same content.
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
          Docker image, but a prefix path determined by <code>data_path</code>
          is removed from the directory structure. This path can
          be absolute from the workspace root if starting with a `/` or
          relative to the rule's directory. A relative path may starts with "./"
          (or be ".") but cannot use go up with "..". By default, the
          <code>data_path</code> attribute is unused, and all files should have no prefix.
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
        <code>String, default to 0o555</code>
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
        <p>Debian packages to extract.</p>
        <p>
          Deprecated: A list of debian packages that will be extracted in the Docker image.
          Note that this doesn't actually install the packages. Installation needs apt
          or apt-get which need to be executed within a running container which
          <code>container_image</code> can't do.
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
        <p>
          The behavior between using <code>""</code> and <code>[]</code> may differ.
          Please see [#1448](https://github.com/bazelbuild/rules_docker/issues/1448)
          for more details.
        </p>
        <p>
          Set <code>entrypoint</code> to <code>None</code>, <code>[]</code>
          or <code>""</code> will set the <code>Entrypoint</code> of the image
          to be <code>null</code>.
        </p>
	      <p>This field supports stamp variables.</p>
      </td>
    </tr>
    <tr>
      <td><code>cmd</code></td>
      <td>
        <code>String or string list, optional</code>
        <p><a href="https://docs.docker.com/engine/reference/builder/#cmd">List
               of commands to execute in the image.</a></p>
        <p>
          The behavior between using <code>""</code> and <code>[]</code> may differ.
          Please see [#1448](https://github.com/bazelbuild/rules_docker/issues/1448)
          for more details.
        </p>
        <p>
          Set <code>cmd</code> to <code>None</code>, <code>[]</code>
          or <code>""</code> will set the <code>Cmd</code> of the image to be
          <code>null</code>.
        </p>
	      <p>This field supports stamp variables.</p>
      </td>
    </tr>
    <tr>
      <td><code>creation_time</code></td>
      <td>
        <code>String, optional, default to {BUILD_TIMESTAMP} when stamp = True, otherwise 0</code>
        <p>The image's creation timestamp.</p>
        <p>Acceptable formats: Integer or floating point seconds since Unix
           Epoch, RFC 3339 date/time.</p>
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
	<p>The values of this field support make variables (e.g., <code>$(FOO)</code>) and stamp variables; keys support make variables as well.</p>
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
      <td><code>layers</code></td>
      <td>
        <code>Label list, optional</code>
        <p>List of <code>container_layer</code> targets. </p>
        <p>The data from each <code>container_layer</code> will be part of container image, and the environment variable will be available in the image as well.</p>
      </td>
    </tr>
    <tr>
      <td><code>repository</code></td>
      <td>
        <code>String, default to `bazel`</code>
        <p>The repository for the default tag for the image.</a></p>
        <p>Images generated by <code>container_image</code> are tagged by default to
           <code>bazel/package_name:target</code> for a <code>container_image</code> target at
           <code>//package/name:target</code>. Setting this attribute to
           <code>gcr.io/dummy</code> would set the default tag to
           <code>gcr.io/dummy/package_name:target</code>.</p>
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
        <p>These fields are specified in attributes using Python format
        syntax, e.g. <code>foo{BUILD_USER}bar</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>launcher</code></td>
      <td>
        <p><code>Label; optional</code></p>
        <p>If present, prefix the image's ENTRYPOINT with this file.
        Note that the launcher should be a container-compatible (OS & Arch)
        single executable file without any runtime dependencies (as none
        of its runfiles will be included in the image).
        </p>
      </td>
    </tr>
    <tr>
      <td><code>launcher_args</code></td>
      <td>
        <p><code>String list; optional</code></p>
        <p>Optional arguments for the <code>launcher</code> attribute.
        Only valid when <code>launcher</code> is specified.</p>
      </td>
    </tr>
    <tr>
      <td><code>legacy_run_behavior</code></td>
      <td>
        <p><code>Bool; optional, default to True</code></p>
        <p>If set to False, <code>bazel run</code> on the
        <code>container_image</code> target will directly invoke
        <code>docker run</code>.</p>
        <p>Note that it defaults to <code>False</code> when using
        <code>lang_image</code> rules.</p>
      </td>
    </tr>
    <tr>
      <td><code>docker_run_flags</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>Optional flags to use with <code>docker run</code> command.</p>
        <p>Only used when <code>legacy_run_behavior</code> is set to
        <code>False</code>.</p>
      </td>
    </tr>
    <tr>
      <td><code>architecture</code></td>
      <td>
        <p><code>String; optional, default to amd64</code></p>
        <p>The desired CPU architecture to be used as label in the container image.</p>
      </td>
    </tr>
    <tr>
      <td><code>os_version</code></td>
      <td>
        <p><code>String; optional</code></p>
        <p>The desired OS version to be used in the container image config.</p>
      </td>
    </tr>
    <tr>
      <td><code>compression</code></td>
      <td>
        <code>String, optional</code>
        <p>Compression method for image layer. Currently only <code>gzip</code> is supported.</p>
        <p>
          This affects the compressed layer, which is by the `container_push` rule.
          It doesn't affect the layers specified by the `layers` attribute.
        </p>
        <p>
          <code>
          compression = "gzip",
          </code>
        </p>
      </td>
    </tr>
    <tr>
      <td><code>compression_options</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>Command-line options for the compression tool. Possible values depend on `compression` method.</p>
        <p>
          This affects the compressed layer, which is used by the `container_push` rule.
          It doesn't affect the layers specified by the `layers` attribute.
        </p>
        <p>
          <code>
          compression_options = ["--fast"],
          </code>
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
      <th colspan="2">Toolchains</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>@io_bazel_rules_docker//toolchains/docker:toolchain_type</code></td>
      <td>
        See <a href="toolchains/docker/readme.md#how-to-use-the-docker-toolchain">How to use the Docker Toolchain</a> for details
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
    <tr>Toolchains
      <td><code>stamp</code></td>
      <td>
        <p><code>Bool; optional</code></p>
        <p>Deprecated: it is now automatically inferred.</p>
        <p>If true, enable use of workspace status variables
        (e.g. <code>BUILD_USER</code>, <code>BUILD_EMBED_LABEL</code>,
        and custom values set using <code>--workspace_status_command</code>)
        in tags.</p>
        <p>These fields are specified in the tag using Python format
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
        <p>A label targeting a single file which is a compressed or
           uncompressed tar, as obtained through `docker save IMAGE`.</p>
      </td>
    </tr>
  </tbody>
</table>

## Adopters
Here's a (non-exhaustive) list of companies that use `rules_docker` in production. Don't see yours? [You can add it in a PR!](https://github.com/bazelbuild/rules_docker/edit/master/README.md)
  * [Amaiz](https://github.com/amaizfinance)
  * [Aura Devices](https://auradevices.io/)
  * [Button](https://usebutton.com)
  * [Domino Data Lab](https://www.dominodatalab.com/)
  * [Canva](https://canva.com)
  * [Etsy](https://www.etsy.com)
  * [Evertz](https://evertz.com/)
  * [Jetstack](https://www.jetstack.io/)
  * [Kubernetes Container Image Promoter](https://github.com/kubernetes-sigs/k8s-container-image-promoter)
  * [Nordstrom](https://nordstrom.com)
  * [Prow](https://github.com/kubernetes/test-infra/tree/master/prow)
  * [Tink](https://www.tink.com)
  * [Wix](https://www.wix.com)
