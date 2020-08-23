# Bazel Docker run Rules

Rules in this directory provide functionality to run commands inside
a docker container.
Note these rules require a docker binary to be present and configured
properly via
[docker toolchain rules](https://github.com/nlopezgi/rules_docker/blob/master/toolchains/docker/readme.md#how-to-use-the-docker-toolchain).


## Docker run Rules

* [container_run_and_commit](#container_run_and_commit)
* [container_run_and_extract](#container_run_and_extract)
* [container_run_and_commit_layer](#container_run_and_commit_layer)

## container_run_and_commit

<pre>
container_run_and_commit(<a href="#container_run_and_commit-name">name</a>, <a href="#container_run_and_commit-commands">commands</a>, <a href="#container_run_and_commit-docker_run_flags">docker_run_flags</a>, <a href="#container_run_and_commit-image">image</a>)
</pre>

This rule runs a set of commands in a given image, waits for the commands
to finish, and then commits the container to a new image.

### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="container_run_and_commit-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="container_run_and_commit-commands">
      <td><code>commands</code></td>
      <td>
        List of strings; required
        <p>
          A list of commands to run (sequentially) in the container.
        </p>
      </td>
    </tr>
    <tr id="container_run_and_commit-docker_run_flags">
      <td><code>docker_run_flags</code></td>
      <td>
        List of strings; optional
        <p>
          Extra flags to pass to the docker run command.
        </p>
      </td>
    </tr>
    <tr id="container_run_and_commit-image">
      <td><code>image</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          The image to run the commands in.
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#container_run_and_extract"></a>

## container_run_and_extract

<pre>
container_run_and_extract(<a href="#container_run_and_extract-name">name</a>, <a href="#container_run_and_extract-commands">commands</a>, <a href="#container_run_and_extract-docker_run_flags">docker_run_flags</a>, <a href="#container_run_and_extract-extract_file">extract_file</a>, <a href="#container_run_and_extract-image">image</a>)
</pre>

This rule runs a set of commands in a given image, waits for the commands
to finish, and then extracts a given file from the container to the
bazel-out directory.

### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="container_run_and_extract-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="container_run_and_extract-commands">
      <td><code>commands</code></td>
      <td>
        List of strings; required
        <p>
          A list of commands to run (sequentially) in the container.
        </p>
      </td>
    </tr>
    <tr id="container_run_and_extract-docker_run_flags">
      <td><code>docker_run_flags</code></td>
      <td>
        List of strings; optional
        <p>
          Extra flags to pass to the docker run command.
        </p>
      </td>
    </tr>
    <tr id="container_run_and_extract-extract_file">
      <td><code>extract_file</code></td>
      <td>
        String; required
        <p>
          Path to file to extract from container.
        </p>
      </td>
    </tr>
    <tr id="container_run_and_extract-image">
      <td><code>image</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          The image to run the commands in.
        </p>
      </td>
    </tr>
  </tbody>
</table>

<a name="#container_run_and_commit_layer"></a>

## container_run_and_commit_layer

<pre>
container_run_and_commit_layer(<a href="#container_run_and_commit_layer-name">name</a>, <a href="#container_run_and_commit_layer-commands">commands</a>, <a href="#container_run_and_commit_layer-docker_run_flags">docker_run_flags</a>, <a href="#container_run_and_commit_layer-image">image</a>, <a href="#container_run_and_commit_layer-env">env</a>)
</pre>

This rule runs a set of commands in a given image, waits for the commands
to finish, and then outputs the difference to a tarball, similar to <a href="/README.md#container_layer">`container_layer`</a>. The output can be used in the `layers` attribute of <a href="/README.md#container_image">`container_image`</a>.

### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="container_run_and_commit_layer-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="container_run_and_commit_layer-commands">
      <td><code>commands</code></td>
      <td>
        List of strings; required
        <p>
          A list of commands to run (sequentially) inside `sh` in the container. If the base image uses a non-standard entrypoint, you may need to use `docker_run_flags` to change the entrypoint to a shell.
        </p>
      </td>
    </tr>
    <tr id="container_run_and_commit_layer-docker_run_flags">
      <td><code>docker_run_flags</code></td>
      <td>
        List of strings; optional
        <p>
          Extra flags to pass to the docker run command. You may want to use this to override the `entrypoint` for images with a non-standard entrypoint with `["--entrypoint=''"]`. These flags only apply to the build step of this rule, and do not affect the output layer. That is, if you change the entrypoint here, and use the layer in a `container_image` later, the entrypoint of that image will not be changed.
        </p>
      </td>
    </tr>
    <tr id="container_run_and_commit_layer-image">
      <td><code>image</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          The image to run the commands in.
        </p>
      </td>
    </tr>
    <tr id="container_run_and_commit_layer-env">
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
  </tbody>
</table>

