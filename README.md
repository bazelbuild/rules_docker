# Bazel Container Image Rules

| Bazel CI |
| :------: |
[![Build status](https://badge.buildkite.com/693d7892250cfd44beea3cd95573388200935906a28cd3146d.svg?branch=master)](https://buildkite.com/bazel/docker-rules-docker-postsubmit)

Generated API documentation is in the docs folder, or you can browse it online at
<https://docs.aspect.dev/rules_docker>

## Basic Rules

* [container_image](/docs/container.md#container_image) ([example](#container_image))
* [container_bundle](/docs/container.md#container_bundle) ([example](#container_bundle))
* [container_import](/docs/container.md#container_import)
* [container_load](/docs/container.md#container_load)
* [container_pull](/docs/container.md#container_pull) ([example](#container_pull))
* [container_push](/docs/container.md#container_push) ([example](#container_push))

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
  # OPTIONAL: Bazel target for the build_tar tool, must be compatible with build_tar.py
  build_tar_target="<enter absolute path (i.e., must start with repo name @...//:...) to an executable build_tar target>",
  # OPTIONAL: Path to a directory which has a custom docker client config.json.
  # See https://docs.docker.com/engine/reference/commandline/cli/#configuration-files
  # for more details.
  client_config="<enter Bazel label to your docker config.json here>",
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
  # OPTIONAL: Bazel target for the xz tool.
  # Either xz_path or xz_target should be set explicitly for remote execution.
  xz_target="<enter absolute path (i.e., must start with repo name @...//:...) to an executable xz target>",
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

* rules_docker uses transitions to build your containers using toolchains the correct
architecture and operating system. If you run into issues with toolchain resolutions,
you can disable this behaviour, by adding this to your .bazelrc:
```
build --@io_bazel_rules_docker//transitions:enable=false
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
container using `docker run` to maximize compatibility with `lang_binary` rules.

Arguments to this command are forwarded to docker, meaning the command

```bash
bazel run my/image:helloworld -- -p 8080:80 -- arg0
```

performs the following steps:
* load the `my/image:helloworld` target into your local Docker client
* start a container using this image where `arg0` is passed to the image entrypoint
* port forward 8080 on the host to port 80 on the container, as per `docker run` documentation

You can suppress this behavior by passing the single flag: `bazel run :foo -- --norun`

Alternatively, you can build a `docker load` compatible bundle with:
`bazel build my/image:helloworld.tar`.  This will produce a tar file
in your `bazel-out` directory that can be loaded into your local Docker
client. Building this target can be expensive for large images. You will
first need to query the ouput file location.

```bash
TARBALL_LOCATION=$(bazel cquery my/image:helloworld.tar \
    --output starlark \
    --starlark:expr="target.files.to_list()[0].path")
docker load -i $TARBALL_LOCATION
```

These work with both `container_image`, `container_bundle`, and the
`lang_image` rules.  For everything except `container_bundle`, the image
name will be `bazel/my/image:helloworld`. The `container_bundle` rule will
apply the tags you have specified.

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

A common request from folks using
`container_push`, `container_bundle`, or `container_image` is to
be able to vary the tag that is pushed or embedded.  There are two options
at present for doing this.

### Stamping

The first option is to use stamping.
Stamping is enabled when bazel is run with `--stamp`.
This enables replacements in stamp-aware attributes.
A python format placeholder (e.g. `{BUILD_USER}`)
is replaced by the value of the corresponding workspace-status variable.

```python
# A common pattern when users want to avoid trampling
# on each other's images during development.
container_push(
  name = "publish",
  format = "Docker",

  # Any of these components may have variables.
  registry = "gcr.io",
  repository = "my-project/my-image",
  # This will be replaced with the current user when built with --stamp
  tag = "{BUILD_USER}",
)
```

> Rules that are sensitive to stamping can also be forced to stamp or non-stamp mode
> irrespective of the `--stamp` flag to Bazel. Use the `build_context_data` rule
> to make a target that provides `StampSettingInfo`, and pass this to the
> `build_context_data` attribute.

The next natural question is: "Well what variables can I use?"  This
option consumes the workspace-status variables Bazel defines in
`bazel-out/stable-status.txt` and `bazel-out/volatile-status.txt`.

> Note that changes to the stable-status file
> cause a rebuild of the action, while volatile-status does not.

You can add more stamp variables via `--workspace_status_command`,
see the [bazel docs](https://docs.bazel.build/versions/master/user-manual.html#workspace_status).
A common example is to provide the current git SHA, with
`--workspace_status_command="echo STABLE_GIT_SHA $(git rev-parse HEAD)"`

That flag is typically passed in the `.bazelrc` file, see for example [`.bazelrc` in kubernetes](https://github.com/kubernetes/kubernetes/blob/81ce94ae1d8f5d04058eeb214e9af498afe78ff2/build/root/.bazelrc#L6).


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
`py_layer` or `java_layer` rules and their `filter` attribute.  For example:

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

`nodejs_image` also supports the `launcher` and `launcher_args` attributes which are passed to `container_image` and used to prefix the image's `entry_point`.

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
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

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
  # Replace this with a Bazel label to the config.json file. Note absolute or relative
  # paths are not supported. Docker allows you to specify custom authentication credentials
  # in the client configuration JSON file.
  # See https://docs.docker.com/engine/reference/commandline/cli/#configuration-files
  # for more details.
  client_config="@//path/to/docker:config.json",
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
  # Bazel label to a custom docker client config.json with
  # authentication credentials for registry.gitlab.com (used in this example).
  client_config="@//path/to/docker/client:config.json",
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
default python toolchain (`//toolchains:container_py_toolchain`)
that defines the path to python tools inside the default container used
for these rules.

### Known issues

If you are using a custom base for `py_image` or `py3_image` builds that has
python tools installed in a different location to those defined in
`//toolchains:container_py_toolchain`, you will need to create a
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

**MOVED**: See [docs/container.md](/docs/container.md#container_pull)

<a name="container_push"></a>
## container_push

**MOVED**: See [docs/container.md](/docs/container.md#container_push)

<a name="container_layer"></a>
## container_layer

**MOVED**: See [docs/container.md](/docs/container.md#container_layer)

<a name="container_image"></a>
## container_image

**MOVED**: See [docs/container.md](/docs/container.md#container_image)

<a name="container_bundle"></a>
## container_bundle

**MOVED**: See [docs/container.md](/docs/container.md#container_bundle)

<a name="container_import"></a>
## container_import

**MOVED**: See [docs/container.md](/docs/container.md#container_import)

<a name="container_load"></a>
## container_load

**MOVED**: See [docs/container.md](/docs/container.md#container_load)


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
