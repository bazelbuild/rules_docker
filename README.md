# Bazel Docker Rules

Bazel ≥0.4.4 | linux-x86_64 | ubuntu_16.04-x86_64 | darwin-x86_64
:---: | :---: | :---: | :---:
[![Build Status](https://travis-ci.org/bazelbuild/rules_docker.svg?branch=master)](https://travis-ci.org/bazelbuild/rules_docker) | [![Build Status](http://ci.bazel.io/buildStatus/icon?job=rules_docker/BAZEL_VERSION=latest,PLATFORM_NAME=linux-x86_64)](http://ci.bazel.io/job/rules_docker/BAZEL_VERSION=latest,PLATFORM_NAME=linux-x86_64) | [![Build Status](http://ci.bazel.io/buildStatus/icon?job=rules_docker/BAZEL_VERSION=latest,PLATFORM_NAME=ubuntu_16.04-x86_64)](http://ci.bazel.io/job/rules_docker/BAZEL_VERSION=latest,PLATFORM_NAME=ubuntu_16.04-x86_64) | [![Build Status](http://ci.bazel.io/buildStatus/icon?job=rules_docker/BAZEL_VERSION=latest,PLATFORM_NAME=darwin-x86_64)](http://ci.bazel.io/job/rules_docker/BAZEL_VERSION=latest,PLATFORM_NAME=darwin-x86_64)



## Rules

* [docker_build](#docker_build)
* [docker_bundle](#docker_bundle)
* [docker_import](#docker_import)
* [docker_pull](#docker_pull)
* [docker_push](#docker_push)

## Overview

This repository contains a set of rules for pulling down base images, augmenting
them with build artifacts and assets, and publishing those images.
**These rules do not require / use Docker for pulling, building, or pushing
images.**  This means:
* They can be used to develop Docker containers on Windows / OSX without
`boot2docker` or `docker-machine` installed.
* They do not require root access on your workstation.

Also, unlike traditional Docker builds, the Docker images produced by
`docker_build` are deterministic / reproducible.

__NOTE:__ `docker_push` and `docker_pull` make use of
[google/containerregistry](https://github.com/google/containerregistry) for
registry interactions.

## Setup

Add the following to your `WORKSPACE` file to add the external repositories:

```python
git_repository(
    name = "io_bazel_rules_docker",
    remote = "https://github.com/bazelbuild/rules_docker.git",
    tag = "v0.0.2",
)

load(
  "@io_bazel_rules_docker//docker:docker.bzl",
  "docker_repositories", "docker_pull"
)
docker_repositories()

docker_pull(
  name = "java_base",
  registry = "gcr.io",
  repository = "distroless/java",
  # 'tag' is also supported, but digest is encouraged for reproducibility.
  digest = "sha256:deadbeef",
)
```

## Using with Docker locally.

Suppose you have a `docker_build` target `//my/image:helloworld`:

```python
docker_build(
    name = "helloworld",
    ...
)
```

You can load this into your local Docker client by running:
`bazel run my/image:helloworld`.

Alternately, you can build a `docker load` compatible bundle with:
`bazel build my/image:helloworld.tar`.  This will produce the file:
`bazel-genfiles/my/image/helloworld.tar`, which you can load into
your local Docker client by running:
`docker load -i bazel-genfiles/my/image/helloworld.tar`.  Building
this target can be expensive for large images.

These work with both `docker_build` and `docker_bundle`.  For
`docker_build` the image name will be `bazel/my/image:helloworld`.
For `docker_bundle`, it will apply the tags you have specified.

## Authorization

You can use these rules to access private images using standard Docker
authentication methods.  e.g. to utilize the [Google Container Registry](
https://gcr.io) [credential helper](
https://github.com/GoogleCloudPlatform/docker-credential-gcr):

```shell
$ gcloud components install docker-credential-gcr

$ docker-credential-gcr configure-docker
```

## Varying image names

A common request from folks using `docker_push` or `docker_bundle` is to
be able to vary the tag that is pushed or embedded.  There are two options
at present for doing this.

### Stamping

The first option is to use `stamp = True`.

```python
# A common pattern when users want to avoid trampling
# on each other's images during development.
docker_push(
  name = "publish",

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
docker_bundle(
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


## Examples

### docker_build

```python
docker_build(
    name = "app",
    # References docker_pull from WORKSPACE (above)
    base = "@java_base//image",
    files = ["//java/com/example/app:Hello_deploy.jar"],
    cmd = ["Hello_deploy.jar"]
)
```

### docker_bundle

```python
docker_bundle(
    name = "bundle",
    images = {
        # A set of images to bundle up into a single tarball.
        "gcr.io/foo/bar:bazz": ":app",
        "gcr.io/foo/bar:blah": "//my:sidecar",
        "gcr.io/foo/bar:booo": "@your//random:image",
    }
)
```

### docker_pull

In `WORKSPACE`:

```python
docker_pull(
    name = "base",
    registry = "gcr.io",
    repository = "my-project/my-base",
    # 'tag' is also supported, but digest is encouraged for reproducibility.
    digest = "sha256:deadbeef",
)
```

This can then be referenced in `BUILD` files as `@base//image`.

### docker_push

This target pushes on `bazel run :push_foo`:

``` python
docker_push(
   name = "push_foo",
   image = ":foo",
   registry = "gcr.io",
   repository = "my-project/my-image",
   tag = "dev",
)
```

### docker_pull (DockerHub)

In `WORKSPACE`:

```python
docker_pull(
    name = "official_ubuntu",
    registry = "index.docker.io",
    repository = "library/ubuntu",
    tag = "14.04",
)
```

This can then be referenced in `BUILD` files as `@official_ubuntu//image`.

### docker_pull (Quay.io)

In `WORKSPACE`:

```python
docker_pull(
    name = "etcd",
    registry = "quay.io",
    repository = "coreos/etcd",
    tag = "latest",
)
```

This can then be referenced in `BUILD` files as `@etcd//image`.

### docker_pull (Bintray.io)

In `WORKSPACE`:

```python
docker_pull(
    name = "artifactory",
    registry = "docker.bintray.io",
    repository = "jfrog/artifactory-pro",
)
```

This can then be referenced in `BUILD` files as `@artifactory//image`.

### docker_pull (Gitlab)

In `WORKSPACE`:

```python
docker_pull(
    name = "gitlab",
    registry = "registry.gitlab.com",
    repository = "username/project/image",
    tag = "tag",
)
```

This can then be referenced in `BUILD` files as `@gitlab//image`.

**NOTE:** This will only work on systems with Python >2.7.6

<a name="docker_pull"></a>
## docker_pull

```python
docker_pull(name, registry, repository, digest, tag)
```

A repository rule that pulls down a Docker base image in a manner suitable for
use with `docker_build`'s `base` attribute.

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

<a name="docker_push"></a>
## docker_push

```python
docker_push(name, image, registry, repository, tag)
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
      </td>
    </tr>
    <tr>
      <td><code>repository</code></td>
      <td>
        <p><code>Repository; required</code></p>
        <p>The `repository` of images to which to push.</p>
      </td>
    </tr>
    <tr>
      <td><code>tag</code></td>
      <td>
        <p><code>string; optional</code></p>
        <p>The `tag` of the Docker image to push to the specified `repository`.
           This attribute defaults to `latest`.</p>
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

<a name="docker_build"></a>
## docker_build

```python
docker_build(name, base, data_path, directory, files, legacy_repository_naming, mode, tars, debs, symlinks, entrypoint, cmd, env, labels, ports, volumes, workdir, repository)
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
      </td>
    </tr>
    <tr>
      <td><code>entrypoint</code></td>
      <td>
        <code>String or string list, optional</code>
        <p><a href="https://docs.docker.com/engine/reference/builder/#entrypoint">List
               of entrypoints to add in the image.</a></p>
      </td>
    </tr>
    <tr>
      <td><code>cmd</code></td>
      <td>
        <code>String or string list, optional</code>
        <p><a href="https://docs.docker.com/engine/reference/builder/#cmd">List
               of commands to execute in the image.</a></p>
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
      </td>
    </tr>
    <tr>
      <td><code>repository</code></td>
      <td>
        <code>String, default to `bazel`</code>
        <p>The repository for the default tag for the image.</a></p>
        <p>Images generated by `docker_build` are tagged by default to
           `bazel/package_name:target` for a `docker_build` target at
           `//package/name:target`. Setting this attribute to
           `gcr.io/dummy` would set the default tag to
           `gcr.io/dummy/package_name:target`.</p>
      </td>
    </tr>
  </tbody>
</table>

<a name="docker_bundle"></a>
## docker_bundle

```python
docker_bundle(name, images)
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
        <p>The values may be the output of <code>docker_pull</code>,
           <code>docker_build</code>, or a <code>docker save</code> tarball.</p>
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

<a name="docker_import"></a>
## docker_import

```python
docker_import(name, config, layers)
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
        <p><code>The list of layer `.tar.gz`s; required</code></p>
        <p>The list of layer `.tar.gz` files in the order they appear
           in the `config.json`'s layer section, or in the order that
           they appear in `docker save` tarballs' `manifest.json`
           `Layers` field (although these are gzipped).</p>
      </td>
    </tr>
  </tbody>
</table>
