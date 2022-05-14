<!-- Generated with Stardoc, Do Not Edit! -->


Generated API documentation for rules that manipulating containers.

Load these from `@io_bazel_rules_docker//container:container.bzl`.

<a id="#container_bundle"></a>

## container_bundle

<pre>
container_bundle(<a href="#container_bundle-name">name</a>, <a href="#container_bundle-experimental_tarball_format">experimental_tarball_format</a>, <a href="#container_bundle-extract_config">extract_config</a>, <a href="#container_bundle-image_target_strings">image_target_strings</a>,
                 <a href="#container_bundle-image_targets">image_targets</a>, <a href="#container_bundle-images">images</a>, <a href="#container_bundle-incremental_load_template">incremental_load_template</a>, <a href="#container_bundle-stamp">stamp</a>, <a href="#container_bundle-tar_output">tar_output</a>)
</pre>

A rule that aliases and saves N images into a single `docker save` tarball.

This can be consumed in 2 different ways:

  - The output tarball could be used for `docker load` to load all images to docker daemon.

  - The emitted BundleInfo provider could be consumed by contrib/push-all.bzl rules to
    create an executable target which tag and push multiple images to a container registry.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_bundle-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="container_bundle-experimental_tarball_format"></a>experimental_tarball_format |  The tarball format to use when producing an image .tar file. Defaults to "legacy", which contains uncompressed layers. If set to "compressed", the resulting tarball will contain compressed layers, but is only loadable by newer versions of docker. This is an experimental attribute, which is subject to change or removal: do not depend on its exact behavior.   | String | optional | "legacy" |
| <a id="container_bundle-extract_config"></a>extract_config |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container/go/cmd/extract_config:extract_config |
| <a id="container_bundle-image_target_strings"></a>image_target_strings |  -   | List of strings | optional | [] |
| <a id="container_bundle-image_targets"></a>image_targets |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="container_bundle-images"></a>images |  -   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="container_bundle-incremental_load_template"></a>incremental_load_template |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container:incremental_load_template |
| <a id="container_bundle-stamp"></a>stamp |  Whether to encode build information into the output. Possible values:<br><br>    - <code>@io_bazel_rules_docker//stamp:always</code>:         Always stamp the build information into the output, even in [--nostamp][stamp] builds.         This setting should be avoided, since it potentially causes cache misses remote caching for         any downstream actions that depend on it.<br><br>    - <code>@io_bazel_rules_docker//stamp:never</code>:         Always replace build information by constant values. This gives good build result caching.<br><br>    - <code>@io_bazel_rules_docker//stamp:use_stamp_flag</code>:         Embedding of build information is controlled by the [--[no]stamp][stamp] flag.         Stamped binaries are not rebuilt unless their dependencies change.<br><br>    [stamp]: https://docs.bazel.build/versions/main/user-manual.html#flag--stamp   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @io_bazel_rules_docker//stamp:use_stamp_flag |
| <a id="container_bundle-tar_output"></a>tar_output |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional |  |


<a id="#container_flatten"></a>

## container_flatten

<pre>
container_flatten(<a href="#container_flatten-name">name</a>, <a href="#container_flatten-extract_config">extract_config</a>, <a href="#container_flatten-image">image</a>, <a href="#container_flatten-incremental_load_template">incremental_load_template</a>)
</pre>

A rule to flatten container images.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_flatten-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="container_flatten-extract_config"></a>extract_config |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container/go/cmd/extract_config:extract_config |
| <a id="container_flatten-image"></a>image |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="container_flatten-incremental_load_template"></a>incremental_load_template |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container:incremental_load_template |


<a id="#container_import"></a>

## container_import

<pre>
container_import(<a href="#container_import-name">name</a>, <a href="#container_import-base_image_digest">base_image_digest</a>, <a href="#container_import-base_image_registry">base_image_registry</a>, <a href="#container_import-base_image_repository">base_image_repository</a>, <a href="#container_import-config">config</a>,
                 <a href="#container_import-extract_config">extract_config</a>, <a href="#container_import-incremental_load_template">incremental_load_template</a>, <a href="#container_import-layers">layers</a>, <a href="#container_import-manifest">manifest</a>, <a href="#container_import-repository">repository</a>, <a href="#container_import-sha256">sha256</a>)
</pre>

A rule that imports a docker image into our intermediate form.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_import-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="container_import-base_image_digest"></a>base_image_digest |  The digest of the image   | String | optional | "" |
| <a id="container_import-base_image_registry"></a>base_image_registry |  The registry from which we pulled the image   | String | optional | "" |
| <a id="container_import-base_image_repository"></a>base_image_repository |  The repository from which we pulled the image   | String | optional | "" |
| <a id="container_import-config"></a>config |  A json configuration file containing the image's metadata.<br><br>            This appears in <code>docker save</code> tarballs as <code>.json</code> and is referenced by <code>manifest.json</code> in the config field.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="container_import-extract_config"></a>extract_config |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container/go/cmd/extract_config:extract_config |
| <a id="container_import-incremental_load_template"></a>incremental_load_template |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container:incremental_load_template |
| <a id="container_import-layers"></a>layers |  The list of layer .tar.gz files in the order they appear in the config.json's layer section,             or in the order that they appear in the <code>Layers</code> field of the docker save tarballs'             <code>manifest.json</code> (these may or may not be gzipped).<br><br>            Note that the layers should each have a different basename.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="container_import-manifest"></a>manifest |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="container_import-repository"></a>repository |  -   | String | optional | "bazel" |
| <a id="container_import-sha256"></a>sha256 |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container/go/cmd/sha256:sha256 |


<a id="#container_layer"></a>

## container_layer

<pre>
container_layer(<a href="#container_layer-name">name</a>, <a href="#container_layer-build_layer">build_layer</a>, <a href="#container_layer-compression">compression</a>, <a href="#container_layer-compression_options">compression_options</a>, <a href="#container_layer-data_path">data_path</a>, <a href="#container_layer-debs">debs</a>, <a href="#container_layer-directory">directory</a>,
                <a href="#container_layer-empty_dirs">empty_dirs</a>, <a href="#container_layer-empty_files">empty_files</a>, <a href="#container_layer-enable_mtime_preservation">enable_mtime_preservation</a>, <a href="#container_layer-env">env</a>, <a href="#container_layer-extract_config">extract_config</a>, <a href="#container_layer-files">files</a>,
                <a href="#container_layer-incremental_load_template">incremental_load_template</a>, <a href="#container_layer-mode">mode</a>, <a href="#container_layer-mtime">mtime</a>, <a href="#container_layer-operating_system">operating_system</a>, <a href="#container_layer-portable_mtime">portable_mtime</a>, <a href="#container_layer-sha256">sha256</a>,
                <a href="#container_layer-symlinks">symlinks</a>, <a href="#container_layer-tars">tars</a>)
</pre>

A rule that assembles data into a tarball which can be use as in layers attr in container_image rule.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_layer-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="container_layer-build_layer"></a>build_layer |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container:build_tar |
| <a id="container_layer-compression"></a>compression |  -   | String | optional | "gzip" |
| <a id="container_layer-compression_options"></a>compression_options |  -   | List of strings | optional | [] |
| <a id="container_layer-data_path"></a>data_path |  Root path of the files.<br><br>        The directory structure from the files is preserved inside the         Docker image, but a prefix path determined by <code>data_path</code>         is removed from the directory structure. This path can         be absolute from the workspace root if starting with a <code>/</code> or         relative to the rule's directory. A relative path may starts with "./"         (or be ".") but cannot use go up with "..". By default, the         <code>data_path</code> attribute is unused, and all files should have no prefix.   | String | optional | "" |
| <a id="container_layer-debs"></a>debs |  Debian packages to extract.<br><br>        Deprecated: A list of debian packages that will be extracted in the Docker image.         Note that this doesn't actually install the packages. Installation needs apt         or apt-get which need to be executed within a running container which         <code>container_image</code> can't do.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="container_layer-directory"></a>directory |  Target directory.<br><br>        The directory in which to expand the specified files, defaulting to '/'.         Only makes sense accompanying one of files/tars/debs.   | String | optional | "/" |
| <a id="container_layer-empty_dirs"></a>empty_dirs |  -   | List of strings | optional | [] |
| <a id="container_layer-empty_files"></a>empty_files |  -   | List of strings | optional | [] |
| <a id="container_layer-enable_mtime_preservation"></a>enable_mtime_preservation |  -   | Boolean | optional | False |
| <a id="container_layer-env"></a>env |  Dictionary from environment variable names to their values when running the Docker image.<br><br>        See https://docs.docker.com/engine/reference/builder/#env<br><br>        For example,<br><br>            env = {                 "FOO": "bar",                 ...             },<br><br>        The values of this field support make variables (e.g., <code>$(FOO)</code>)         and stamp variables; keys support make variables as well.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="container_layer-extract_config"></a>extract_config |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container/go/cmd/extract_config:extract_config |
| <a id="container_layer-files"></a>files |  File to add to the layer.<br><br>        A list of files that should be included in the Docker image.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="container_layer-incremental_load_template"></a>incremental_load_template |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container:incremental_load_template |
| <a id="container_layer-mode"></a>mode |  Set the mode of files added by the <code>files</code> attribute.   | String | optional | "0o555" |
| <a id="container_layer-mtime"></a>mtime |  -   | Integer | optional | -1 |
| <a id="container_layer-operating_system"></a>operating_system |  -   | String | optional | "linux" |
| <a id="container_layer-portable_mtime"></a>portable_mtime |  -   | Boolean | optional | False |
| <a id="container_layer-sha256"></a>sha256 |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container/go/cmd/sha256:sha256 |
| <a id="container_layer-symlinks"></a>symlinks |  Symlinks to create in the Docker image.<br><br>        For example,<br><br>            symlinks = {                 "/path/to/link": "/path/to/target",                 ...             },   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="container_layer-tars"></a>tars |  Tar file to extract in the layer.<br><br>        A list of tar files whose content should be in the Docker image.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a id="#container_load"></a>

## container_load

<pre>
container_load(<a href="#container_load-name">name</a>, <a href="#container_load-file">file</a>, <a href="#container_load-repo_mapping">repo_mapping</a>)
</pre>

A repository rule that examines the contents of a docker save tarball and creates a container_import target.

This extracts the tarball amd creates a filegroup of the untarred objects in OCI intermediate layout.
The created target can be referenced as `@label_name//image`.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_load-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="container_load-file"></a>file |  A label targeting a single file which is a compressed or uncompressed tar,             as obtained through <code>docker save IMAGE</code>.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="container_load-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |


<a id="#container_pull"></a>

## container_pull

<pre>
container_pull(<a href="#container_pull-name">name</a>, <a href="#container_pull-architecture">architecture</a>, <a href="#container_pull-cpu_variant">cpu_variant</a>, <a href="#container_pull-cred_helpers">cred_helpers</a>, <a href="#container_pull-digest">digest</a>, <a href="#container_pull-docker_client_config">docker_client_config</a>,
               <a href="#container_pull-import_tags">import_tags</a>, <a href="#container_pull-os">os</a>, <a href="#container_pull-os_features">os_features</a>, <a href="#container_pull-os_version">os_version</a>, <a href="#container_pull-platform_features">platform_features</a>, <a href="#container_pull-puller_darwin">puller_darwin</a>,
               <a href="#container_pull-puller_linux_amd64">puller_linux_amd64</a>, <a href="#container_pull-puller_linux_arm64">puller_linux_arm64</a>, <a href="#container_pull-puller_linux_s390x">puller_linux_s390x</a>, <a href="#container_pull-registry">registry</a>, <a href="#container_pull-repo_mapping">repo_mapping</a>,
               <a href="#container_pull-repository">repository</a>, <a href="#container_pull-tag">tag</a>, <a href="#container_pull-timeout">timeout</a>)
</pre>

A repository rule that pulls down a Docker base image in a manner suitable for use with the `base` attribute of `container_image`.

This is based on google/containerregistry using google/go-containerregistry.
It wraps the rulesdocker.go.cmd.puller.puller executable in a
Bazel rule for downloading base images without a Docker client to
construct new images.

NOTE: `container_pull` now supports authentication using custom docker client configuration.
See [here](https://github.com/bazelbuild/rules_docker#container_pull-custom-client-configuration) for details.

NOTE: Set `PULLER_TIMEOUT` env variable to change the default 600s timeout for all container_pull targets.

NOTE: Set `DOCKER_REPO_CACHE` env variable to make the container puller cache downloaded layers at the directory specified as a value to this env variable.
The caching feature hasn't been thoroughly tested and may be thread unsafe.
If you notice flakiness after enabling it, see the warning below on how to workaround it.

NOTE: `container_pull` is suspected to have thread safety issues.
To ensure multiple `container_pull`(s) don't execute concurrently,
please use the bazel startup flag `--loading_phase_threads=1` in your bazel invocation
(typically by adding `startup --loading_phase_threads=1` as a line in your `.bazelrc`)


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_pull-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="container_pull-architecture"></a>architecture |  Which CPU architecture to pull if this image refers to a multi-platform manifest list, default 'amd64'.   | String | optional | "amd64" |
| <a id="container_pull-cpu_variant"></a>cpu_variant |  Which CPU variant to pull if this image refers to a multi-platform manifest list.   | String | optional | "" |
| <a id="container_pull-cred_helpers"></a>cred_helpers |  Labels to a list of credential helper binaries that are configured in <code>docker_client_config</code>.<br><br>        More about credential helpers: https://docs.docker.com/engine/reference/commandline/login/#credential-helpers   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="container_pull-digest"></a>digest |  The digest of the image to pull.   | String | optional | "" |
| <a id="container_pull-docker_client_config"></a>docker_client_config |  Specifies  a Bazel label of the config.json file.<br><br>            Don't use this directly.             Instead, specify the docker configuration directory using a custom docker toolchain configuration.             Look for the <code>client_config</code> attribute in <code>docker_toolchain_configure</code>             [here](https://github.com/bazelbuild/rules_docker#setup) for details.             See [here](https://github.com/bazelbuild/rules_docker#container_pull-custom-client-configuration)             for an example on how to use container_pull after configuring the docker toolchain<br><br>            When left unspecified (ie not set explicitly or set by the docker toolchain),             docker will use the directory specified via the <code>DOCKER_CONFIG</code> environment variable.<br><br>            If <code>DOCKER_CONFIG</code> isn't set, docker falls back to <code>$HOME/.docker</code>.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="container_pull-import_tags"></a>import_tags |  Tags to be propagated to generated rules.   | List of strings | optional | [] |
| <a id="container_pull-os"></a>os |  Which os to pull if this image refers to a multi-platform manifest list.   | String | optional | "linux" |
| <a id="container_pull-os_features"></a>os_features |  Specifies os features when pulling a multi-platform manifest list.   | List of strings | optional | [] |
| <a id="container_pull-os_version"></a>os_version |  Which os version to pull if this image refers to a multi-platform manifest list.   | String | optional | "" |
| <a id="container_pull-platform_features"></a>platform_features |  Specifies platform features when pulling a multi-platform manifest list.   | List of strings | optional | [] |
| <a id="container_pull-puller_darwin"></a>puller_darwin |  Exposed to provide a way to test other pullers on macOS   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @go_puller_darwin//file:downloaded |
| <a id="container_pull-puller_linux_amd64"></a>puller_linux_amd64 |  Exposed to provide a way to test other pullers on Linux   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @go_puller_linux_amd64//file:downloaded |
| <a id="container_pull-puller_linux_arm64"></a>puller_linux_arm64 |  Exposed to provide a way to test other pullers on Linux   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @go_puller_linux_arm64//file:downloaded |
| <a id="container_pull-puller_linux_s390x"></a>puller_linux_s390x |  Exposed to provide a way to test other pullers on Linux   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @go_puller_linux_s390x//file:downloaded |
| <a id="container_pull-registry"></a>registry |  The registry from which we are pulling.   | String | required |  |
| <a id="container_pull-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |
| <a id="container_pull-repository"></a>repository |  The name of the image.   | String | required |  |
| <a id="container_pull-tag"></a>tag |  The <code>tag</code> of the Docker image to pull from the specified <code>repository</code>.<br><br>        If neither this nor <code>digest</code> is specified, this attribute defaults to <code>latest</code>.         If both are specified, then <code>tag</code> is ignored.<br><br>        Note: For reproducible builds, use of <code>digest</code> is recommended.   | String | optional | "latest" |
| <a id="container_pull-timeout"></a>timeout |  Timeout in seconds to fetch the image from the registry.<br><br>        This attribute will be overridden by the PULLER_TIMEOUT environment variable, if it is set.   | Integer | optional | 0 |


<a id="#container_push"></a>

## container_push

<pre>
container_push(<a href="#container_push-name">name</a>, <a href="#container_push-extension">extension</a>, <a href="#container_push-extract_config">extract_config</a>, <a href="#container_push-format">format</a>, <a href="#container_push-image">image</a>, <a href="#container_push-incremental_load_template">incremental_load_template</a>,
               <a href="#container_push-insecure_repository">insecure_repository</a>, <a href="#container_push-registry">registry</a>, <a href="#container_push-repository">repository</a>, <a href="#container_push-repository_file">repository_file</a>, <a href="#container_push-skip_unchanged_digest">skip_unchanged_digest</a>,
               <a href="#container_push-stamp">stamp</a>, <a href="#container_push-tag">tag</a>, <a href="#container_push-tag_file">tag_file</a>, <a href="#container_push-tag_tpl">tag_tpl</a>, <a href="#container_push-windows_paths">windows_paths</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_push-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="container_push-extension"></a>extension |  The file extension for the push script.   | String | optional | "" |
| <a id="container_push-extract_config"></a>extract_config |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container/go/cmd/extract_config:extract_config |
| <a id="container_push-format"></a>format |  The form to push: Docker or OCI, default to 'Docker'.   | String | required |  |
| <a id="container_push-image"></a>image |  The label of the image to push.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="container_push-incremental_load_template"></a>incremental_load_template |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container:incremental_load_template |
| <a id="container_push-insecure_repository"></a>insecure_repository |  Whether the repository is insecure or not (http vs https)   | Boolean | optional | False |
| <a id="container_push-registry"></a>registry |  The registry to which we are pushing.   | String | required |  |
| <a id="container_push-repository"></a>repository |  The name of the image.   | String | required |  |
| <a id="container_push-repository_file"></a>repository_file |  The label of the file with repository value. Overrides 'repository'.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="container_push-skip_unchanged_digest"></a>skip_unchanged_digest |  Check if the container registry already contain the image's digest. If yes, skip the push for that image. Default to False. Note that there is no transactional guarantee between checking for digest existence and pushing the digest. This means that you should try to avoid running the same container_push targets in parallel.   | Boolean | optional | False |
| <a id="container_push-stamp"></a>stamp |  Whether to encode build information into the output. Possible values:<br><br>    - <code>@io_bazel_rules_docker//stamp:always</code>:         Always stamp the build information into the output, even in [--nostamp][stamp] builds.         This setting should be avoided, since it potentially causes cache misses remote caching for         any downstream actions that depend on it.<br><br>    - <code>@io_bazel_rules_docker//stamp:never</code>:         Always replace build information by constant values. This gives good build result caching.<br><br>    - <code>@io_bazel_rules_docker//stamp:use_stamp_flag</code>:         Embedding of build information is controlled by the [--[no]stamp][stamp] flag.         Stamped binaries are not rebuilt unless their dependencies change.<br><br>    [stamp]: https://docs.bazel.build/versions/main/user-manual.html#flag--stamp   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @io_bazel_rules_docker//stamp:use_stamp_flag |
| <a id="container_push-tag"></a>tag |  The tag of the image.   | String | optional | "latest" |
| <a id="container_push-tag_file"></a>tag_file |  The label of the file with tag value. Overrides 'tag'.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="container_push-tag_tpl"></a>tag_tpl |  The script template to use.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="container_push-windows_paths"></a>windows_paths |  -   | Boolean | required |  |


<a id="#container_push_index"></a>

## container_push_index

<pre>
container_push_index(<a href="#container_push_index-name">name</a>, <a href="#container_push_index-extension">extension</a>, <a href="#container_push_index-extract_config">extract_config</a>, <a href="#container_push_index-format">format</a>, <a href="#container_push_index-images">images</a>, <a href="#container_push_index-incremental_load_template">incremental_load_template</a>,
                     <a href="#container_push_index-insecure_repository">insecure_repository</a>, <a href="#container_push_index-registry">registry</a>, <a href="#container_push_index-repository">repository</a>, <a href="#container_push_index-repository_file">repository_file</a>,
                     <a href="#container_push_index-skip_unchanged_digest">skip_unchanged_digest</a>, <a href="#container_push_index-stamp">stamp</a>, <a href="#container_push_index-tag">tag</a>, <a href="#container_push_index-tag_file">tag_file</a>, <a href="#container_push_index-tag_tpl">tag_tpl</a>, <a href="#container_push_index-windows_paths">windows_paths</a>)
</pre>

Push a docker image for multiple platforms.

This rule will push all given image manifests, and then the manifest list,
aka the _fat manifest_, with the definition of all image platforms.

An image platforms must follow the format: `[<os>/][<arch>][/<variant>]`.

Example of the `images` attribute value:

```json
{
    ":my_image_amd64": "linux/amd64",
    ":my_image_arm64": "linux/arm64/v8",
    ":my_image_ppc64le": "linux/ppc64le",
}
```

- if `<os>` is missing, `linux` will be used.
- if `<arch>` is missing, `amd64` will be used.
- `<variant>` cannot be specified without `<os>` and `<arch>`.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_push_index-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="container_push_index-extension"></a>extension |  The file extension for the push script.   | String | optional | "" |
| <a id="container_push_index-extract_config"></a>extract_config |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container/go/cmd/extract_config:extract_config |
| <a id="container_push_index-format"></a>format |  The form to push: Docker or OCI, default to 'Docker'.   | String | required |  |
| <a id="container_push_index-images"></a>images |  The list of all images to push.<br><br>            The value of each entries is the platform of the container image.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: Label -> String</a> | required |  |
| <a id="container_push_index-incremental_load_template"></a>incremental_load_template |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container:incremental_load_template |
| <a id="container_push_index-insecure_repository"></a>insecure_repository |  Whether the repository is insecure or not (http vs https)   | Boolean | optional | False |
| <a id="container_push_index-registry"></a>registry |  The registry to which we are pushing.   | String | required |  |
| <a id="container_push_index-repository"></a>repository |  The name of the image.   | String | required |  |
| <a id="container_push_index-repository_file"></a>repository_file |  The label of the file with repository value. Overrides 'repository'.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="container_push_index-skip_unchanged_digest"></a>skip_unchanged_digest |  Check if the container registry already contain the image's digest. If yes, skip the push for that image. Default to False. Note that there is no transactional guarantee between checking for digest existence and pushing the digest. This means that you should try to avoid running the same container_push targets in parallel.   | Boolean | optional | False |
| <a id="container_push_index-stamp"></a>stamp |  Whether to encode build information into the output. Possible values:<br><br>    - <code>@io_bazel_rules_docker//stamp:always</code>:         Always stamp the build information into the output, even in [--nostamp][stamp] builds.         This setting should be avoided, since it potentially causes cache misses remote caching for         any downstream actions that depend on it.<br><br>    - <code>@io_bazel_rules_docker//stamp:never</code>:         Always replace build information by constant values. This gives good build result caching.<br><br>    - <code>@io_bazel_rules_docker//stamp:use_stamp_flag</code>:         Embedding of build information is controlled by the [--[no]stamp][stamp] flag.         Stamped binaries are not rebuilt unless their dependencies change.<br><br>    [stamp]: https://docs.bazel.build/versions/main/user-manual.html#flag--stamp   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @io_bazel_rules_docker//stamp:use_stamp_flag |
| <a id="container_push_index-tag"></a>tag |  The tag of the image.   | String | optional | "latest" |
| <a id="container_push_index-tag_file"></a>tag_file |  The label of the file with tag value. Overrides 'tag'.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="container_push_index-tag_tpl"></a>tag_tpl |  The script template to use.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="container_push_index-windows_paths"></a>windows_paths |  -   | Boolean | required |  |


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
See [How to use the Docker Toolchain](/toolchains/docker/readme.md#how-to-use-the-docker-toolchain) for details.


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
                     <a href="#image.implementation-output_config_digest">output_config_digest</a>, <a href="#image.implementation-output_digest">output_digest</a>, <a href="#image.implementation-output_layer">output_layer</a>, <a href="#image.implementation-workdir">workdir</a>, <a href="#image.implementation-user">user</a>, <a href="#image.implementation-null_cmd">null_cmd</a>,
                     <a href="#image.implementation-null_entrypoint">null_entrypoint</a>, <a href="#image.implementation-tag_name">tag_name</a>)
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
        cfg = _container.image.cfg,
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
| <a id="image.implementation-user"></a>user |  str, overrides ctx.attr.user   |  <code>None</code> |
| <a id="image.implementation-null_cmd"></a>null_cmd |  bool, overrides ctx.attr.null_cmd   |  <code>None</code> |
| <a id="image.implementation-null_entrypoint"></a>null_entrypoint |  bool, overrides ctx.attr.null_entrypoint   |  <code>None</code> |
| <a id="image.implementation-tag_name"></a>tag_name |  str, overrides ctx.attr.tag_name   |  <code>None</code> |


