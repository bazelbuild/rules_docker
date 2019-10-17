# Bazel toolchain container rules

Rules in this directory provide functionality to build `toolchain_container`s.
These are containers made up of `language_tool_layer`s. Each `language_tool_layer`
produces a `container_image` with a set of debian packages installed.
A `language_tool_layer` can define any attributes of a `container_image`.
Note these rules depend on `docker/package_managers` rules which in turn 
require a docker binary to be present and configured properly via
[docker toolchain rules](https://github.com/nlopezgi/rules_docker/blob/master/toolchains/docker/readme.md#how-to-use-the-docker-toolchain).

## Toolchain container macros

* [language_tool_layer](#language_tool_layer)
* [toolchain_container](#toolchain_container)

<a name="#language_tool_layer"></a>

## language_tool_layer

<pre>
language_tool_layer(<a href="#language_tool_layer-kwargs">kwargs</a>)
</pre>

A wrapper around attrs in `container_image`, `download_pkgs` and `install_pkgs` rules.

Downloads and installs debian packages using
https://github.com/GoogleCloudPlatform/base-images-docker/tree/master/package_managers,
and configures the rest using https://github.com/bazelbuild/rules_docker#container_image-1.


### Parameters

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="language_tool_layer-kwargs">
      <td><code>kwargs</code></td>
      <td>
        optional.
        <p>
          Same args as https://github.com/bazelbuild/rules_docker#container_image-1
      minus:
          debs: debian packages should be listed in 'packages', or be included in
          'installables_tar' as .deb files.
      plus:
          packages: list of packages to fetch and install in the base image.
          additional_repos: list of additional debian package repos to use,
          in sources.list format.
          keys: list of labels of additional gpg keys to use while downloading
          packages.
          installables_tar: a tar of debian packages to install in the base image.
          installation_cleanup_commands: cleanup commands to run after package
          installation.
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#toolchain_container"></a>

## toolchain_container

<pre>
toolchain_container(<a href="#toolchain_container-kwargs">kwargs</a>)
</pre>

Composes multiple `language_tool_layer`s into a single resulting image.

A `toolchain_container` is a `container_image` composed from multiple `language_tool_layer`
targets. Each `language_tool_layer` target can install a list of debian packages.

If `installables_tar` is specified in the `toolchain_container` rule, then
`packages` or `installables_tar` specified in any of the `language_layers`
passed to this `toolchain_container` rule will be ignored.


### Parameters

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="toolchain_container-kwargs">
      <td><code>kwargs</code></td>
      <td>
        optional.
        <p>
          Same args as https://github.com/bazelbuild/rules_docker#container_image-1
      minus:
          debs: debian packages should be listed in `packages`, or be included in
              `installables_tar` as .deb files.
      plus:
          language_layers: a list of language_tool_layer.
          installables_tar: a tar of debian packages to install in the base image.
          packages: list of packages to fetch and install in the base image.
          additional_repos: list of additional debian package repos to use,
          in sources.list format.
          keys: list of labels of additional gpg keys to use while downloading
          packages.
          installation_cleanup_commands: cleanup commands to run after package
          installation.
        </p>
      </td>
    </tr>
  </tbody>
</table>

