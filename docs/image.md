Rule for building a Container image.

In addition to the base container_image rule, we expose its constituents
(attr, outputs, implementation) directly so that others may expose a
more specialized build leveraging the same implementation.

<a id="#container_image_"></a>

## container_image_

<pre>
container_image_(<a href="#container_image_-name">name</a>, <a href="#container_image_-architecture">architecture</a>, <a href="#container_image_-base">base</a>, <a href="#container_image_-build_layer">build_layer</a>, <a href="#container_image_-cmd">cmd</a>, <a href="#container_image_-compression">compression</a>, <a href="#container_image_-compression_options">compression_options</a>,
                 <a href="#container_image_-create_image_config">create_image_config</a>, <a href="#container_image_-creation_time">creation_time</a>, <a href="#container_image_-data_path">data_path</a>, <a href="#container_image_-debs">debs</a>, <a href="#container_image_-directory">directory</a>, <a href="#container_image_-docker_run_flags">docker_run_flags</a>,
                 <a href="#container_image_-empty_dirs">empty_dirs</a>, <a href="#container_image_-empty_files">empty_files</a>, <a href="#container_image_-enable_mtime_preservation">enable_mtime_preservation</a>, <a href="#container_image_-entrypoint">entrypoint</a>, <a href="#container_image_-env">env</a>,
                 <a href="#container_image_-experimental_tarball_format">experimental_tarball_format</a>, <a href="#container_image_-extract_config">extract_config</a>, <a href="#container_image_-files">files</a>, <a href="#container_image_-incremental_load_template">incremental_load_template</a>,
                 <a href="#container_image_-label_file_strings">label_file_strings</a>, <a href="#container_image_-label_files">label_files</a>, <a href="#container_image_-labels">labels</a>, <a href="#container_image_-launcher">launcher</a>, <a href="#container_image_-launcher_args">launcher_args</a>, <a href="#container_image_-layers">layers</a>,
                 <a href="#container_image_-legacy_repository_naming">legacy_repository_naming</a>, <a href="#container_image_-legacy_run_behavior">legacy_run_behavior</a>, <a href="#container_image_-mode">mode</a>, <a href="#container_image_-mtime">mtime</a>, <a href="#container_image_-null_cmd">null_cmd</a>,
                 <a href="#container_image_-null_entrypoint">null_entrypoint</a>, <a href="#container_image_-operating_system">operating_system</a>, <a href="#container_image_-os_version">os_version</a>, <a href="#container_image_-portable_mtime">portable_mtime</a>, <a href="#container_image_-ports">ports</a>, <a href="#container_image_-repository">repository</a>,
                 <a href="#container_image_-sha256">sha256</a>, <a href="#container_image_-stamp">stamp</a>, <a href="#container_image_-symlinks">symlinks</a>, <a href="#container_image_-tars">tars</a>, <a href="#container_image_-user">user</a>, <a href="#container_image_-volumes">volumes</a>, <a href="#container_image_-workdir">workdir</a>)
</pre>

Called by the `container_image` macro with **kwargs, see below

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_image_-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="container_image_-architecture"></a>architecture |  The desired CPU architecture to be used as label in the container image.   | String | optional | "amd64" |
| <a id="container_image_-base"></a>base |  The base layers on top of which to overlay this layer, equivalent to FROM.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="container_image_-build_layer"></a>build_layer |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container:build_tar |
| <a id="container_image_-cmd"></a>cmd |  List of commands to execute in the image.<br><br>        See https://docs.docker.com/engine/reference/builder/#cmd<br><br>        The behavior between using <code>""</code> and <code>[]</code> may differ.         Please see [#1448](https://github.com/bazelbuild/rules_docker/issues/1448)         for more details.<br><br>        Set <code>cmd</code> to <code>None</code>, <code>[]</code> or <code>""</code> will set the <code>Cmd</code> of the image to be         <code>null</code>.<br><br>        This field supports stamp variables.   | List of strings | optional | [] |
| <a id="container_image_-compression"></a>compression |  Compression method for image layer. Currently only gzip is supported.<br><br>        This affects the compressed layer, which is by the <code>container_push</code> rule.         It doesn't affect the layers specified by the <code>layers</code> attribute.   | String | optional | "gzip" |
| <a id="container_image_-compression_options"></a>compression_options |  Command-line options for the compression tool. Possible values depend on <code>compression</code> method.<br><br>        This affects the compressed layer, which is used by the <code>container_push</code> rule.         It doesn't affect the layers specified by the <code>layers</code> attribute.   | List of strings | optional | [] |
| <a id="container_image_-create_image_config"></a>create_image_config |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container/go/cmd/create_image_config:create_image_config |
| <a id="container_image_-creation_time"></a>creation_time |  The image's creation timestamp.<br><br>        Acceptable formats: Integer or floating point seconds since Unix Epoch, RFC 3339 date/time.<br><br>        This field supports stamp variables.<br><br>        If not set, defaults to {BUILD_TIMESTAMP} when stamp = True, otherwise 0   | String | optional | "" |
| <a id="container_image_-data_path"></a>data_path |  Root path of the files.<br><br>        The directory structure from the files is preserved inside the         Docker image, but a prefix path determined by <code>data_path</code>         is removed from the directory structure. This path can         be absolute from the workspace root if starting with a <code>/</code> or         relative to the rule's directory. A relative path may starts with "./"         (or be ".") but cannot use go up with "..". By default, the         <code>data_path</code> attribute is unused, and all files should have no prefix.   | String | optional | "" |
| <a id="container_image_-debs"></a>debs |  Debian packages to extract.<br><br>        Deprecated: A list of debian packages that will be extracted in the Docker image.         Note that this doesn't actually install the packages. Installation needs apt         or apt-get which need to be executed within a running container which         <code>container_image</code> can't do.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="container_image_-directory"></a>directory |  Target directory.<br><br>        The directory in which to expand the specified files, defaulting to '/'.         Only makes sense accompanying one of files/tars/debs.   | String | optional | "/" |
| <a id="container_image_-docker_run_flags"></a>docker_run_flags |  Optional flags to use with <code>docker run</code> command.<br><br>        Only used when <code>legacy_run_behavior</code> is set to <code>False</code>.   | String | optional | "" |
| <a id="container_image_-empty_dirs"></a>empty_dirs |  -   | List of strings | optional | [] |
| <a id="container_image_-empty_files"></a>empty_files |  -   | List of strings | optional | [] |
| <a id="container_image_-enable_mtime_preservation"></a>enable_mtime_preservation |  -   | Boolean | optional | False |
| <a id="container_image_-entrypoint"></a>entrypoint |  List of entrypoints to add in the image.<br><br>        See https://docs.docker.com/engine/reference/builder/#entrypoint<br><br>        Set <code>entrypoint</code> to <code>None</code>, <code>[]</code> or <code>""</code> will set the <code>Entrypoint</code> of the image         to be <code>null</code>.<br><br>        The behavior between using <code>""</code> and <code>[]</code> may differ.         Please see [#1448](https://github.com/bazelbuild/rules_docker/issues/1448)         for more details.<br><br>        This field supports stamp variables.   | List of strings | optional | [] |
| <a id="container_image_-env"></a>env |  Dictionary from environment variable names to their values when running the Docker image.<br><br>        See https://docs.docker.com/engine/reference/builder/#env<br><br>        For example,<br><br>            env = {                 "FOO": "bar",                 ...             }, <br><br>	    The values of this field support make variables (e.g., <code>$(FOO)</code>)         and stamp variables; keys support make variables as well.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="container_image_-experimental_tarball_format"></a>experimental_tarball_format |  The tarball format to use when producing an image .tar file. Defaults to "legacy", which contains uncompressed layers. If set to "compressed", the resulting tarball will contain compressed layers, but is only loadable by newer versions of docker. This is an experimental attribute, which is subject to change or removal: do not depend on its exact behavior.   | String | optional | "legacy" |
| <a id="container_image_-extract_config"></a>extract_config |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container/go/cmd/extract_config:extract_config |
| <a id="container_image_-files"></a>files |  File to add to the layer.<br><br>        A list of files that should be included in the Docker image.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="container_image_-incremental_load_template"></a>incremental_load_template |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container:incremental_load_template |
| <a id="container_image_-label_file_strings"></a>label_file_strings |  -   | List of strings | optional | [] |
| <a id="container_image_-label_files"></a>label_files |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="container_image_-labels"></a>labels |  Dictionary from custom metadata names to their values.<br><br>        See https://docs.docker.com/engine/reference/builder/#label<br><br>        You can also put a file name prefixed by '@' as a value.         Then the value is replaced with the contents of the file.<br><br>        Example:<br><br>            labels = {                 "com.example.foo": "bar",                 "com.example.baz": "@metadata.json",                 ...             },<br><br>	    The values of this field support stamp variables.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="container_image_-launcher"></a>launcher |  If present, prefix the image's ENTRYPOINT with this file.<br><br>        Note that the launcher should be a container-compatible (OS & Arch)         single executable file without any runtime dependencies (as none         of its runfiles will be included in the image).   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="container_image_-launcher_args"></a>launcher_args |  Optional arguments for the <code>launcher</code> attribute.<br><br>        Only valid when <code>launcher</code> is specified.   | List of strings | optional | [] |
| <a id="container_image_-layers"></a>layers |  List of <code>container_layer</code> targets.<br><br>        The data from each <code>container_layer</code> will be part of container image,         and the environment variable will be available in the image as well.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="container_image_-legacy_repository_naming"></a>legacy_repository_naming |  Whether to use the legacy strategy for setting the repository name           embedded in the resulting tarball.<br><br>          e.g. <code>bazel/{target.replace('/', '_')}</code> vs. <code>bazel/{target}</code>   | Boolean | optional | False |
| <a id="container_image_-legacy_run_behavior"></a>legacy_run_behavior |  If set to False, <code>bazel run</code> will directly invoke <code>docker run</code> with flags specified in the <code>docker_run_flags</code> attribute. Note that it defaults to False when using &lt;lang&gt;_image rules.   | Boolean | optional | True |
| <a id="container_image_-mode"></a>mode |  Set the mode of files added by the <code>files</code> attribute.   | String | optional | "0o555" |
| <a id="container_image_-mtime"></a>mtime |  -   | Integer | optional | -1 |
| <a id="container_image_-null_cmd"></a>null_cmd |  -   | Boolean | optional | False |
| <a id="container_image_-null_entrypoint"></a>null_entrypoint |  -   | Boolean | optional | False |
| <a id="container_image_-operating_system"></a>operating_system |  -   | String | optional | "linux" |
| <a id="container_image_-os_version"></a>os_version |  The desired OS version to be used in the container image config.   | String | optional | "" |
| <a id="container_image_-portable_mtime"></a>portable_mtime |  -   | Boolean | optional | False |
| <a id="container_image_-ports"></a>ports |  List of ports to expose.<br><br>        See https://docs.docker.com/engine/reference/builder/#expose   | List of strings | optional | [] |
| <a id="container_image_-repository"></a>repository |  The repository for the default tag for the image.<br><br>        Images generated by <code>container_image</code> are tagged by default to         <code>bazel/package_name:target</code> for a <code>container_image</code> target at         <code>//package/name:target</code>.<br><br>        Setting this attribute to <code>gcr.io/dummy</code> would set the default tag to         <code>gcr.io/dummy/package_name:target</code>.   | String | optional | "bazel" |
| <a id="container_image_-sha256"></a>sha256 |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //tools/build_defs/hash:sha256 |
| <a id="container_image_-stamp"></a>stamp |  If true, enable use of workspace status variables         (e.g. <code>BUILD_USER</code>, <code>BUILD_EMBED_LABEL</code>,         and custom values set using <code>--workspace_status_command</code>)         in tags.<br><br>        These fields are specified in attributes using Python format         syntax, e.g. <code>foo{BUILD_USER}bar</code>.   | Boolean | optional | False |
| <a id="container_image_-symlinks"></a>symlinks |  Symlinks to create in the Docker image.<br><br>        For example,<br><br>            symlinks = {                 "/path/to/link": "/path/to/target",                 ...             },   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="container_image_-tars"></a>tars |  Tar file to extract in the layer.<br><br>        A list of tar files whose content should be in the Docker image.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="container_image_-user"></a>user |  The user that the image should run as.<br><br>        See https://docs.docker.com/engine/reference/builder/#user<br><br>        Because building the image never happens inside a Docker container,         this user does not affect the other actions (e.g., adding files).<br><br>	    This field supports stamp variables.   | String | optional | "" |
| <a id="container_image_-volumes"></a>volumes |  List of volumes to mount.<br><br>        See https://docs.docker.com/engine/reference/builder/#volumes   | List of strings | optional | [] |
| <a id="container_image_-workdir"></a>workdir |  Initial working directory when running the Docker image.<br><br>        See https://docs.docker.com/engine/reference/builder/#workdir<br><br>        Because building the image never happens inside a Docker container,         this working directory does not affect the other actions (e.g., adding files).<br><br>	    This field supports stamp variables.   | String | optional | "" |


<a id="#container_image"></a>

## container_image

<pre>
container_image(<a href="#container_image-kwargs">kwargs</a>)
</pre>

Package a docker image.

Produces a new container image tarball compatible with 'docker load', which
is a single additional layer atop 'base'.  The goal is to have relatively
complete support for building container image, from the Dockerfile spec.

For more information see the 'Config' section of the image specification:
https://github.com/opencontainers/image-spec/blob/v0.2.0/serialization.md

Only 'name' is required. All other fields have sane defaults.

    container_image(
        name="...",
        visibility="...",

        # The base layers on top of which to overlay this layer,
        # equivalent to FROM.
        base="//another/build:rule",

        # The base directory of the files, defaulted to
        # the package of the input.
        # All files structure relatively to that path will be preserved.
        # A leading '/' mean the workspace root and this path is relative
        # to the current package by default.
        data_path="...",

        # The directory in which to expand the specified files,
        # defaulting to '/'.
        # Only makes sense accompanying one of files/tars/debs.
        directory="...",

        # The set of archives to expand, or packages to install
        # within the chroot of this layer
        files=[...],
        tars=[...],
        debs=[...],

        # The set of symlinks to create within a given layer.
        symlinks = {
            "/path/to/link": "/path/to/target",
            ...
        },

        # Other layers built from container_layer rule
        layers = [":c-lang-layer", ":java-lang-layer", ...]

        # https://docs.docker.com/engine/reference/builder/#entrypoint
        entrypoint="...", or
        entrypoint=[...],            -- exec form
        Set entrypoint to None, [] or "" will set the Entrypoint of the image to
        be null.

        # https://docs.docker.com/engine/reference/builder/#cmd
        cmd="...", or
        cmd=[...],                   -- exec form
        Set cmd to None, [] or "" will set the Cmd of the image to be null.

        # https://docs.docker.com/engine/reference/builder/#expose
        ports=[...],

        # https://docs.docker.com/engine/reference/builder/#user
        # NOTE: the normal directive affects subsequent RUN, CMD,
        # and ENTRYPOINT
        user="...",

        # https://docs.docker.com/engine/reference/builder/#volume
        volumes=[...],

        # https://docs.docker.com/engine/reference/builder/#workdir
        # NOTE: the normal directive affects subsequent RUN, CMD,
        # ENTRYPOINT, ADD, and COPY, but this attribute only affects
        # the entry point.
        workdir="...",

        # https://docs.docker.com/engine/reference/builder/#env
        env = {
            "var1": "val1",
            "var2": "val2",
            ...
            "varN": "valN",
        },

        # Compression method and command-line options.
        compression = "gzip",
        compression_options = ["--fast"],
        experimental_tarball_format = "compressed",
    )

This rule generates a sequence of genrules the last of which is named 'name',
so the dependency graph works out properly.  The output of this rule is a
tarball compatible with 'docker save/load' with the structure:

    {layer-name}:
    layer.tar
    VERSION
    json
    {image-config-sha256}.json
    ...
    manifest.json
    repositories
    top     # an implementation detail of our rules, not consumed by Docker.

This rule appends a single new layer to the tarball of this form provided
via the 'base' parameter.

The images produced by this rule are always named `bazel/tmp:latest` when
loaded (an internal detail).  The expectation is that the images produced
by these rules will be uploaded using the `docker_push` rule below.

The implicit output targets are:

- `[name].tar`: A full Docker image containing all the layers, identical to
    what `docker save` would return. This is only generated on demand.
- `[name].digest`: An image digest that can be used to refer to that image. Unlike tags,
    digest references are immutable i.e. always refer to the same content.
- `[name]-layer.tar`: A Docker image containing only the layer corresponding to
    that target. It is used for incremental loading of the layer.

    **Note:** this target is not suitable for direct consumption.
    It is used for incremental loading and non-docker rules should
    depend on the Docker image (`[name].tar`) instead.
- `[name]`: The incremental image loader. It will load only changed
        layers inside the Docker registry.

This rule references the `@io_bazel_rules_docker//toolchains/docker:toolchain_type`.
See [How to use the Docker Toolchain](toolchains/docker/readme.md#how-to-use-the-docker-toolchain) for details.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="container_image-kwargs"></a>kwargs |  Attributes are described by <code>container_image_</code> above.   |  none |


<a id="#image.implementation"></a>

## image.implementation

<pre>
image.implementation(<a href="#image.implementation-ctx">ctx</a>, <a href="#image.implementation-name">name</a>, <a href="#image.implementation-base">base</a>, <a href="#image.implementation-files">files</a>, <a href="#image.implementation-file_map">file_map</a>, <a href="#image.implementation-empty_files">empty_files</a>, <a href="#image.implementation-empty_dirs">empty_dirs</a>, <a href="#image.implementation-directory">directory</a>,
                     <a href="#image.implementation-entrypoint">entrypoint</a>, <a href="#image.implementation-cmd">cmd</a>, <a href="#image.implementation-creation_time">creation_time</a>, <a href="#image.implementation-symlinks">symlinks</a>, <a href="#image.implementation-env">env</a>, <a href="#image.implementation-layers">layers</a>, <a href="#image.implementation-compression">compression</a>,
                     <a href="#image.implementation-compression_options">compression_options</a>, <a href="#image.implementation-experimental_tarball_format">experimental_tarball_format</a>, <a href="#image.implementation-debs">debs</a>, <a href="#image.implementation-tars">tars</a>, <a href="#image.implementation-architecture">architecture</a>,
                     <a href="#image.implementation-operating_system">operating_system</a>, <a href="#image.implementation-os_version">os_version</a>, <a href="#image.implementation-output_executable">output_executable</a>, <a href="#image.implementation-output_tarball">output_tarball</a>, <a href="#image.implementation-output_config">output_config</a>,
                     <a href="#image.implementation-output_config_digest">output_config_digest</a>, <a href="#image.implementation-output_digest">output_digest</a>, <a href="#image.implementation-output_layer">output_layer</a>, <a href="#image.implementation-workdir">workdir</a>, <a href="#image.implementation-null_cmd">null_cmd</a>,
                     <a href="#image.implementation-null_entrypoint">null_entrypoint</a>)
</pre>

Implementation for the container_image rule.

You can write a customized container_image rule by writing something like:

    load(
        "@io_bazel_rules_docker//container:container.bzl",
        _container="container",
    )

    def _impl(ctx):
        ...
        return _container.image.implementation(ctx, ... kwarg overrides ...)

    _foo_image = rule(
        attrs = _container.image.attrs + {
            # My attributes, or overrides of _container.image.attrs defaults.
            ...
        },
        executable = True,
        outputs = _container.image.outputs,
        implementation = _impl,
    )


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="image.implementation-ctx"></a>ctx |  The bazel rule context   |  none |
| <a id="image.implementation-name"></a>name |  str, overrides ctx.label.name or ctx.attr.name   |  <code>None</code> |
| <a id="image.implementation-base"></a>base |  File, overrides ctx.attr.base and ctx.files.base[0]   |  <code>None</code> |
| <a id="image.implementation-files"></a>files |  File list, overrides ctx.files.files   |  <code>None</code> |
| <a id="image.implementation-file_map"></a>file_map |  Dict[str, File], defaults to {}   |  <code>None</code> |
| <a id="image.implementation-empty_files"></a>empty_files |  str list, overrides ctx.attr.empty_files   |  <code>None</code> |
| <a id="image.implementation-empty_dirs"></a>empty_dirs |  Dict[str, str], overrides ctx.attr.empty_dirs   |  <code>None</code> |
| <a id="image.implementation-directory"></a>directory |  str, overrides ctx.attr.directory   |  <code>None</code> |
| <a id="image.implementation-entrypoint"></a>entrypoint |  str List, overrides ctx.attr.entrypoint   |  <code>None</code> |
| <a id="image.implementation-cmd"></a>cmd |  str List, overrides ctx.attr.cmd   |  <code>None</code> |
| <a id="image.implementation-creation_time"></a>creation_time |  str, overrides ctx.attr.creation_time   |  <code>None</code> |
| <a id="image.implementation-symlinks"></a>symlinks |  str Dict, overrides ctx.attr.symlinks   |  <code>None</code> |
| <a id="image.implementation-env"></a>env |  str Dict, overrides ctx.attr.env   |  <code>None</code> |
| <a id="image.implementation-layers"></a>layers |  label List, overrides ctx.attr.layers   |  <code>None</code> |
| <a id="image.implementation-compression"></a>compression |  str, overrides ctx.attr.compression   |  <code>None</code> |
| <a id="image.implementation-compression_options"></a>compression_options |  str list, overrides ctx.attr.compression_options   |  <code>None</code> |
| <a id="image.implementation-experimental_tarball_format"></a>experimental_tarball_format |  str, overrides ctx.attr.experimental_tarball_format   |  <code>None</code> |
| <a id="image.implementation-debs"></a>debs |  File list, overrides ctx.files.debs   |  <code>None</code> |
| <a id="image.implementation-tars"></a>tars |  File list, overrides ctx.files.tars   |  <code>None</code> |
| <a id="image.implementation-architecture"></a>architecture |  str, overrides ctx.attr.architecture   |  <code>None</code> |
| <a id="image.implementation-operating_system"></a>operating_system |  Operating system to target (e.g. linux, windows)   |  <code>None</code> |
| <a id="image.implementation-os_version"></a>os_version |  Operating system version to target   |  <code>None</code> |
| <a id="image.implementation-output_executable"></a>output_executable |  File to use as output for script to load docker image   |  <code>None</code> |
| <a id="image.implementation-output_tarball"></a>output_tarball |  File, overrides ctx.outputs.out   |  <code>None</code> |
| <a id="image.implementation-output_config"></a>output_config |  File, overrides ctx.outputs.config   |  <code>None</code> |
| <a id="image.implementation-output_config_digest"></a>output_config_digest |  File, overrides ctx.outputs.config_digest   |  <code>None</code> |
| <a id="image.implementation-output_digest"></a>output_digest |  File, overrides ctx.outputs.digest   |  <code>None</code> |
| <a id="image.implementation-output_layer"></a>output_layer |  File, overrides ctx.outputs.layer   |  <code>None</code> |
| <a id="image.implementation-workdir"></a>workdir |  str, overrides ctx.attr.workdir   |  <code>None</code> |
| <a id="image.implementation-null_cmd"></a>null_cmd |  bool, overrides ctx.attr.null_cmd   |  <code>None</code> |
| <a id="image.implementation-null_entrypoint"></a>null_entrypoint |  bool, overrides ctx.attr.null_entrypoint   |  <code>None</code> |


