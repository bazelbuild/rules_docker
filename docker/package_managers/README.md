# Bazel Package Manager Rules

Rules in this directory provide functionality to install packages inside
docker containers.
Note these rules require a docker binary to be present and configured
properly via
[docker toolchain rules](https://github.com/nlopezgi/rules_docker/blob/master/toolchains/docker/readme.md#how-to-use-the-docker-toolchain).

## Package Manager Rules

* [add_apt_key](#add_apt_key)
* [download_pkgs](#download_pkgs)
* [install_pkgs](#install_pkgs)

<a name="#add_apt_key"></a>

## add_apt_key

<pre>
add_apt_key(<a href="#add_apt_key-name">name</a>, <a href="#add_apt_key-base">base</a>, <a href="#add_apt_key-build_layer">build_layer</a>, <a href="#add_apt_key-cmd">cmd</a>, <a href="#add_apt_key-commands">commands</a>, <a href="#add_apt_key-create_image_config">create_image_config</a>, <a href="#add_apt_key-creation_time">creation_time</a>, <a href="#add_apt_key-data_path">data_path</a>, <a href="#add_apt_key-debs">debs</a>, <a href="#add_apt_key-directory">directory</a>, <a href="#add_apt_key-docker_run_flags">docker_run_flags</a>, <a href="#add_apt_key-empty_dirs">empty_dirs</a>, <a href="#add_apt_key-empty_files">empty_files</a>, <a href="#add_apt_key-entrypoint">entrypoint</a>, <a href="#add_apt_key-env">env</a>, <a href="#add_apt_key-extract_config">extract_config</a>, <a href="#add_apt_key-extract_file">extract_file</a>, <a href="#add_apt_key-files">files</a>, <a href="#add_apt_key-gpg_image">gpg_image</a>, <a href="#add_apt_key-gzip">gzip</a>, <a href="#add_apt_key-image">image</a>, <a href="#add_apt_key-incremental_load_template">incremental_load_template</a>, <a href="#add_apt_key-join_layers">join_layers</a>, <a href="#add_apt_key-keys">keys</a>, <a href="#add_apt_key-label_file_strings">label_file_strings</a>, <a href="#add_apt_key-label_files">label_files</a>, <a href="#add_apt_key-labels">labels</a>, <a href="#add_apt_key-launcher">launcher</a>, <a href="#add_apt_key-launcher_args">launcher_args</a>, <a href="#add_apt_key-layers">layers</a>, <a href="#add_apt_key-legacy_repository_naming">legacy_repository_naming</a>, <a href="#add_apt_key-legacy_run_behavior">legacy_run_behavior</a>, <a href="#add_apt_key-mode">mode</a>, <a href="#add_apt_key-null_cmd">null_cmd</a>, <a href="#add_apt_key-null_entrypoint">null_entrypoint</a>, <a href="#add_apt_key-operating_system">operating_system</a>, <a href="#add_apt_key-output_file">output_file</a>, <a href="#add_apt_key-ports">ports</a>, <a href="#add_apt_key-repository">repository</a>, <a href="#add_apt_key-sha256">sha256</a>, <a href="#add_apt_key-stamp">stamp</a>, <a href="#add_apt_key-symlinks">symlinks</a>, <a href="#add_apt_key-tars">tars</a>, <a href="#add_apt_key-user">user</a>, <a href="#add_apt_key-volumes">volumes</a>, <a href="#add_apt_key-workdir">workdir</a>)
</pre>



### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="add_apt_key-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="add_apt_key-base">
      <td><code>base</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-build_layer">
      <td><code>build_layer</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-cmd">
      <td><code>cmd</code></td>
      <td>
        List of strings; optional
      </td>
    </tr>
    <tr id="add_apt_key-commands">
      <td><code>commands</code></td>
      <td>
        List of strings; optional
        <p>
          Redeclared from _extract to be non-mandatory, do not set.
        </p>
      </td>
    </tr>
    <tr id="add_apt_key-create_image_config">
      <td><code>create_image_config</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-creation_time">
      <td><code>creation_time</code></td>
      <td>
        String; optional
      </td>
    </tr>
    <tr id="add_apt_key-data_path">
      <td><code>data_path</code></td>
      <td>
        String; optional
      </td>
    </tr>
    <tr id="add_apt_key-debs">
      <td><code>debs</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-directory">
      <td><code>directory</code></td>
      <td>
        String; optional
      </td>
    </tr>
    <tr id="add_apt_key-docker_run_flags">
      <td><code>docker_run_flags</code></td>
      <td>
        List of strings; optional
        <p>
          Extra flags to pass to the docker run command.
        </p>
      </td>
    </tr>
    <tr id="add_apt_key-empty_dirs">
      <td><code>empty_dirs</code></td>
      <td>
        List of strings; optional
      </td>
    </tr>
    <tr id="add_apt_key-empty_files">
      <td><code>empty_files</code></td>
      <td>
        List of strings; optional
      </td>
    </tr>
    <tr id="add_apt_key-entrypoint">
      <td><code>entrypoint</code></td>
      <td>
        List of strings; optional
      </td>
    </tr>
    <tr id="add_apt_key-env">
      <td><code>env</code></td>
      <td>
        <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-extract_config">
      <td><code>extract_config</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-extract_file">
      <td><code>extract_file</code></td>
      <td>
        String; optional
        <p>
          Redeclared from _extract to be non-mandatory, do not set.
        </p>
      </td>
    </tr>
    <tr id="add_apt_key-files">
      <td><code>files</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-gpg_image">
      <td><code>gpg_image</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
        <p>
          If set, keys will be pulled and installed in the given image, the result
          of this installation will then be transfered to the image passed as base
        </p>
      </td>
    </tr>
    <tr id="add_apt_key-gzip">
      <td><code>gzip</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-image">
      <td><code>image</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          The image to run the commands in.
        </p>
      </td>
    </tr>
    <tr id="add_apt_key-incremental_load_template">
      <td><code>incremental_load_template</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-join_layers">
      <td><code>join_layers</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-keys">
      <td><code>keys</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; required
        <p>
          List of keys (each, a file target) to be installed in the container.
        </p>
      </td>
    </tr>
    <tr id="add_apt_key-label_file_strings">
      <td><code>label_file_strings</code></td>
      <td>
        List of strings; optional
      </td>
    </tr>
    <tr id="add_apt_key-label_files">
      <td><code>label_files</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-labels">
      <td><code>labels</code></td>
      <td>
        <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-launcher">
      <td><code>launcher</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-launcher_args">
      <td><code>launcher_args</code></td>
      <td>
        List of strings; optional
      </td>
    </tr>
    <tr id="add_apt_key-layers">
      <td><code>layers</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-legacy_repository_naming">
      <td><code>legacy_repository_naming</code></td>
      <td>
        Boolean; optional
      </td>
    </tr>
    <tr id="add_apt_key-legacy_run_behavior">
      <td><code>legacy_run_behavior</code></td>
      <td>
        Boolean; optional
        <p>
          If set to False, `bazel run` will directly invoke `docker run` with flags specified in the `docker_run_flags` attribute. Note that it defaults to False when using <lang>_image rules.
        </p>
      </td>
    </tr>
    <tr id="add_apt_key-mode">
      <td><code>mode</code></td>
      <td>
        String; optional
      </td>
    </tr>
    <tr id="add_apt_key-null_cmd">
      <td><code>null_cmd</code></td>
      <td>
        Boolean; optional
      </td>
    </tr>
    <tr id="add_apt_key-null_entrypoint">
      <td><code>null_entrypoint</code></td>
      <td>
        Boolean; optional
      </td>
    </tr>
    <tr id="add_apt_key-operating_system">
      <td><code>operating_system</code></td>
      <td>
        String; optional
      </td>
    </tr>
    <tr id="add_apt_key-output_file">
      <td><code>output_file</code></td>
      <td>
        String; optional
        <p>
          Redeclared from _extract to be non-mandatory, do not set.
        </p>
      </td>
    </tr>
    <tr id="add_apt_key-ports">
      <td><code>ports</code></td>
      <td>
        List of strings; optional
      </td>
    </tr>
    <tr id="add_apt_key-repository">
      <td><code>repository</code></td>
      <td>
        String; optional
      </td>
    </tr>
    <tr id="add_apt_key-sha256">
      <td><code>sha256</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-stamp">
      <td><code>stamp</code></td>
      <td>
        Boolean; optional
      </td>
    </tr>
    <tr id="add_apt_key-symlinks">
      <td><code>symlinks</code></td>
      <td>
        <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-tars">
      <td><code>tars</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
    <tr id="add_apt_key-user">
      <td><code>user</code></td>
      <td>
        String; optional
      </td>
    </tr>
    <tr id="add_apt_key-volumes">
      <td><code>volumes</code></td>
      <td>
        List of strings; optional
      </td>
    </tr>
    <tr id="add_apt_key-workdir">
      <td><code>workdir</code></td>
      <td>
        String; optional
      </td>
    </tr>
  </tbody>
</table>

<a name="#download_pkgs"></a>

## download_pkgs

<pre>
download_pkgs(<a href="#download_pkgs-name">name</a>, <a href="#download_pkgs-additional_repos">additional_repos</a>, <a href="#download_pkgs-image_tar">image_tar</a>, <a href="#download_pkgs-packages">packages</a>)
</pre>

This rule creates a script to download packages within a container.
The script bunldes all the packages in a tarball.

### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="download_pkgs-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="download_pkgs-additional_repos">
      <td><code>additional_repos</code></td>
      <td>
        List of strings; optional
        <p>
          list of additional debian package repos to use, in sources.list format
        </p>
      </td>
    </tr>
    <tr id="download_pkgs-image_tar">
      <td><code>image_tar</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          The image tar for the container used to download packages.
        </p>
      </td>
    </tr>
    <tr id="download_pkgs-packages">
      <td><code>packages</code></td>
      <td>
        List of strings; required
        <p>
          list of packages to download. e.g. ['curl', 'netbase']
        </p>
      </td>
    </tr>
  </tbody>
</table>

<a name="#install_pkgs"></a>

## install_pkgs

<pre>
install_pkgs(<a href="#install_pkgs-name">name</a>, <a href="#install_pkgs-image_tar">image_tar</a>, <a href="#install_pkgs-installables_tar">installables_tar</a>, <a href="#install_pkgs-installation_cleanup_commands">installation_cleanup_commands</a>, <a href="#install_pkgs-output_image_name">output_image_name</a>)
</pre>

This rule install deb packages, obtained via a <code>download_pkgs</code> rule,
within a container.

### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="install_pkgs-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="install_pkgs-image_tar">
      <td><code>image_tar</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          The image tar for the container used to install packages.
        </p>
      </td>
    </tr>
    <tr id="install_pkgs-installables_tar">
      <td><code>installables_tar</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          Tar with deb installables, should be a tar produced by a  download_pkgs rule.
        </p>
      </td>
    </tr>
    <tr id="install_pkgs-installation_cleanup_commands">
      <td><code>installation_cleanup_commands</code></td>
      <td>
        String; optional
        <p>
          Commands to run after installation, to e.g., remove or otherwise modify files created during installation.
        </p>
      </td>
    </tr>
    <tr id="install_pkgs-output_image_name">
      <td><code>output_image_name</code></td>
      <td>
        String; required
        <p>
          Name of container_image produced with the packages installed.
        </p>
      </td>
    </tr>
  </tbody>
</table>
