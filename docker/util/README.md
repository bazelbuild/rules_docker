# Bazel Docker run Rules

Rules in this directory provide functionality to run commands inside
a docker container.
Note these rules require a docker binary to be present and configured
properly via
[docker toolchain rules](https://github.com/nlopezgi/rules_docker/blob/master/toolchains/docker/readme.md#how-to-use-the-docker-toolchain).


## Docker run Rules

* [container_run_and_commit](#container_run_and_commit)
* [container_run_and_extract](#container_run_and_extract)

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

