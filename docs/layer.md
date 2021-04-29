Rule for building a Container layer.
<a id="#container_layer_"></a>

## container_layer_

<pre>
container_layer_(<a href="#container_layer_-name">name</a>, <a href="#container_layer_-build_layer">build_layer</a>, <a href="#container_layer_-compression">compression</a>, <a href="#container_layer_-compression_options">compression_options</a>, <a href="#container_layer_-data_path">data_path</a>, <a href="#container_layer_-debs">debs</a>, <a href="#container_layer_-directory">directory</a>,
                 <a href="#container_layer_-empty_dirs">empty_dirs</a>, <a href="#container_layer_-empty_files">empty_files</a>, <a href="#container_layer_-enable_mtime_preservation">enable_mtime_preservation</a>, <a href="#container_layer_-env">env</a>, <a href="#container_layer_-extract_config">extract_config</a>, <a href="#container_layer_-files">files</a>,
                 <a href="#container_layer_-incremental_load_template">incremental_load_template</a>, <a href="#container_layer_-mode">mode</a>, <a href="#container_layer_-mtime">mtime</a>, <a href="#container_layer_-operating_system">operating_system</a>, <a href="#container_layer_-portable_mtime">portable_mtime</a>, <a href="#container_layer_-sha256">sha256</a>,
                 <a href="#container_layer_-symlinks">symlinks</a>, <a href="#container_layer_-tars">tars</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_layer_-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="container_layer_-build_layer"></a>build_layer |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container:build_tar |
| <a id="container_layer_-compression"></a>compression |  -   | String | optional | "gzip" |
| <a id="container_layer_-compression_options"></a>compression_options |  -   | List of strings | optional | [] |
| <a id="container_layer_-data_path"></a>data_path |  Root path of the files.<br><br>        The directory structure from the files is preserved inside the         Docker image, but a prefix path determined by <code>data_path</code>         is removed from the directory structure. This path can         be absolute from the workspace root if starting with a <code>/</code> or         relative to the rule's directory. A relative path may starts with "./"         (or be ".") but cannot use go up with "..". By default, the         <code>data_path</code> attribute is unused, and all files should have no prefix.   | String | optional | "" |
| <a id="container_layer_-debs"></a>debs |  Debian packages to extract.<br><br>        Deprecated: A list of debian packages that will be extracted in the Docker image.         Note that this doesn't actually install the packages. Installation needs apt         or apt-get which need to be executed within a running container which         <code>container_image</code> can't do.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="container_layer_-directory"></a>directory |  Target directory.<br><br>        The directory in which to expand the specified files, defaulting to '/'.         Only makes sense accompanying one of files/tars/debs.   | String | optional | "/" |
| <a id="container_layer_-empty_dirs"></a>empty_dirs |  -   | List of strings | optional | [] |
| <a id="container_layer_-empty_files"></a>empty_files |  -   | List of strings | optional | [] |
| <a id="container_layer_-enable_mtime_preservation"></a>enable_mtime_preservation |  -   | Boolean | optional | False |
| <a id="container_layer_-env"></a>env |  Dictionary from environment variable names to their values when running the Docker image.<br><br>        See https://docs.docker.com/engine/reference/builder/#env<br><br>        For example,<br><br>            env = {                 "FOO": "bar",                 ...             }, <br><br>        The values of this field support make variables (e.g., <code>$(FOO)</code>)         and stamp variables; keys support make variables as well.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="container_layer_-extract_config"></a>extract_config |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container/go/cmd/extract_config:extract_config |
| <a id="container_layer_-files"></a>files |  File to add to the layer.<br><br>        A list of files that should be included in the Docker image.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="container_layer_-incremental_load_template"></a>incremental_load_template |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container:incremental_load_template |
| <a id="container_layer_-mode"></a>mode |  Set the mode of files added by the <code>files</code> attribute.   | String | optional | "0o555" |
| <a id="container_layer_-mtime"></a>mtime |  -   | Integer | optional | -1 |
| <a id="container_layer_-operating_system"></a>operating_system |  -   | String | optional | "linux" |
| <a id="container_layer_-portable_mtime"></a>portable_mtime |  -   | Boolean | optional | False |
| <a id="container_layer_-sha256"></a>sha256 |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //tools/build_defs/hash:sha256 |
| <a id="container_layer_-symlinks"></a>symlinks |  Symlinks to create in the Docker image.<br><br>        For example,<br><br>            symlinks = {                 "/path/to/link": "/path/to/target",                 ...             },   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="container_layer_-tars"></a>tars |  Tar file to extract in the layer.<br><br>        A list of tar files whose content should be in the Docker image.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a id="#build_layer"></a>

## build_layer

<pre>
build_layer(<a href="#build_layer-ctx">ctx</a>, <a href="#build_layer-name">name</a>, <a href="#build_layer-output_layer">output_layer</a>, <a href="#build_layer-files">files</a>, <a href="#build_layer-file_map">file_map</a>, <a href="#build_layer-empty_files">empty_files</a>, <a href="#build_layer-empty_dirs">empty_dirs</a>, <a href="#build_layer-directory">directory</a>, <a href="#build_layer-symlinks">symlinks</a>,
            <a href="#build_layer-debs">debs</a>, <a href="#build_layer-tars">tars</a>, <a href="#build_layer-operating_system">operating_system</a>)
</pre>

Build the current layer for appending it to the base layer

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="build_layer-ctx"></a>ctx |  The context   |  none |
| <a id="build_layer-name"></a>name |  The name of the layer   |  none |
| <a id="build_layer-output_layer"></a>output_layer |  The output location for this layer   |  none |
| <a id="build_layer-files"></a>files |  Files to include in the layer   |  <code>None</code> |
| <a id="build_layer-file_map"></a>file_map |  Map of files to include in layer (source to dest inside layer)   |  <code>None</code> |
| <a id="build_layer-empty_files"></a>empty_files |  List of empty files in the layer   |  <code>None</code> |
| <a id="build_layer-empty_dirs"></a>empty_dirs |  List of empty dirs in the layer   |  <code>None</code> |
| <a id="build_layer-directory"></a>directory |  Directory in which to store the file inside the layer   |  <code>None</code> |
| <a id="build_layer-symlinks"></a>symlinks |  List of symlinks to include in the layer   |  <code>None</code> |
| <a id="build_layer-debs"></a>debs |  List of debian package tar files   |  <code>None</code> |
| <a id="build_layer-tars"></a>tars |  List of tar files   |  <code>None</code> |
| <a id="build_layer-operating_system"></a>operating_system |  The OS (e.g., 'linux', 'windows')   |  <code>None</code> |


<a id="#container_layer"></a>

## container_layer

<pre>
container_layer(<a href="#container_layer-kwargs">kwargs</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="container_layer-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="#layer.implementation"></a>

## layer.implementation

<pre>
layer.implementation(<a href="#layer.implementation-ctx">ctx</a>, <a href="#layer.implementation-name">name</a>, <a href="#layer.implementation-files">files</a>, <a href="#layer.implementation-file_map">file_map</a>, <a href="#layer.implementation-empty_files">empty_files</a>, <a href="#layer.implementation-empty_dirs">empty_dirs</a>, <a href="#layer.implementation-directory">directory</a>, <a href="#layer.implementation-symlinks">symlinks</a>, <a href="#layer.implementation-debs">debs</a>,
                     <a href="#layer.implementation-tars">tars</a>, <a href="#layer.implementation-env">env</a>, <a href="#layer.implementation-compression">compression</a>, <a href="#layer.implementation-compression_options">compression_options</a>, <a href="#layer.implementation-operating_system">operating_system</a>, <a href="#layer.implementation-output_layer">output_layer</a>)
</pre>

Implementation for the container_layer rule.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="layer.implementation-ctx"></a>ctx |  The bazel rule context   |  none |
| <a id="layer.implementation-name"></a>name |  str, overrides ctx.label.name or ctx.attr.name   |  <code>None</code> |
| <a id="layer.implementation-files"></a>files |  File list, overrides ctx.files.files   |  <code>None</code> |
| <a id="layer.implementation-file_map"></a>file_map |  Dict[str, File], defaults to {}   |  <code>None</code> |
| <a id="layer.implementation-empty_files"></a>empty_files |  str list, overrides ctx.attr.empty_files   |  <code>None</code> |
| <a id="layer.implementation-empty_dirs"></a>empty_dirs |  Dict[str, str], overrides ctx.attr.empty_dirs   |  <code>None</code> |
| <a id="layer.implementation-directory"></a>directory |  str, overrides ctx.attr.directory   |  <code>None</code> |
| <a id="layer.implementation-symlinks"></a>symlinks |  str Dict, overrides ctx.attr.symlinks   |  <code>None</code> |
| <a id="layer.implementation-debs"></a>debs |  File list, overrides ctx.files.debs   |  <code>None</code> |
| <a id="layer.implementation-tars"></a>tars |  File list, overrides ctx.files.tars   |  <code>None</code> |
| <a id="layer.implementation-env"></a>env |  str Dict, overrides ctx.attr.env   |  <code>None</code> |
| <a id="layer.implementation-compression"></a>compression |  str, overrides ctx.attr.compression   |  <code>None</code> |
| <a id="layer.implementation-compression_options"></a>compression_options |  str list, overrides ctx.attr.compression_options   |  <code>None</code> |
| <a id="layer.implementation-operating_system"></a>operating_system |  operating system to target (e.g. linux, windows)   |  <code>None</code> |
| <a id="layer.implementation-output_layer"></a>output_layer |  File, overrides ctx.outputs.layer   |  <code>None</code> |


<a id="#zip_layer"></a>

## zip_layer

<pre>
zip_layer(<a href="#zip_layer-ctx">ctx</a>, <a href="#zip_layer-layer">layer</a>, <a href="#zip_layer-compression">compression</a>, <a href="#zip_layer-compression_options">compression_options</a>)
</pre>

Generate the zipped filesystem layer, and its sha256 (aka blob sum)

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="zip_layer-ctx"></a>ctx |  The bazel rule context   |  none |
| <a id="zip_layer-layer"></a>layer |  File, layer tar   |  none |
| <a id="zip_layer-compression"></a>compression |  str, compression mode, eg "gzip"   |  <code>""</code> |
| <a id="zip_layer-compression_options"></a>compression_options |  str, command-line options for the compression tool   |  <code>None</code> |


