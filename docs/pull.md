An implementation of container_pull based on google/containerregistry using google/go-containerregistry.

This wraps the rulesdocker.go.cmd.puller.puller executable in a
Bazel rule for downloading base images without a Docker client to
construct new images.

<a id="#container_pull"></a>

## container_pull

<pre>
container_pull(<a href="#container_pull-name">name</a>, <a href="#container_pull-architecture">architecture</a>, <a href="#container_pull-cpu_variant">cpu_variant</a>, <a href="#container_pull-digest">digest</a>, <a href="#container_pull-docker_client_config">docker_client_config</a>, <a href="#container_pull-import_tags">import_tags</a>, <a href="#container_pull-os">os</a>,
               <a href="#container_pull-os_features">os_features</a>, <a href="#container_pull-os_version">os_version</a>, <a href="#container_pull-platform_features">platform_features</a>, <a href="#container_pull-puller_darwin">puller_darwin</a>, <a href="#container_pull-puller_linux_amd64">puller_linux_amd64</a>,
               <a href="#container_pull-puller_linux_arm64">puller_linux_arm64</a>, <a href="#container_pull-puller_linux_s390x">puller_linux_s390x</a>, <a href="#container_pull-registry">registry</a>, <a href="#container_pull-repo_mapping">repo_mapping</a>, <a href="#container_pull-repository">repository</a>, <a href="#container_pull-tag">tag</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_pull-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="container_pull-architecture"></a>architecture |  (optional) Which CPU architecture to pull if this image refers to a multi-platform manifest list, default 'amd64'.   | String | optional | "amd64" |
| <a id="container_pull-cpu_variant"></a>cpu_variant |  Which CPU variant to pull if this image refers to a multi-platform manifest list.   | String | optional | "" |
| <a id="container_pull-digest"></a>digest |  (optional) The digest of the image to pull.   | String | optional | "" |
| <a id="container_pull-docker_client_config"></a>docker_client_config |  A custom directory for the docker client config.json. If DOCKER_CONFIG is not specified, the value of the DOCKER_CONFIG environment variable will be used. DOCKER_CONFIG is not defined, the home directory will be used.   | String | optional | "" |
| <a id="container_pull-import_tags"></a>import_tags |  (optional) tags to be propagated to generated rules.   | List of strings | optional | [] |
| <a id="container_pull-os"></a>os |  (optional) Which os to pull if this image refers to a multi-platform manifest list, default 'linux'.   | String | optional | "linux" |
| <a id="container_pull-os_features"></a>os_features |  (optional) Specifies os features when pulling a multi-platform manifest list.   | List of strings | optional | [] |
| <a id="container_pull-os_version"></a>os_version |  (optional) Which os version to pull if this image refers to a multi-platform manifest list.   | String | optional | "" |
| <a id="container_pull-platform_features"></a>platform_features |  (optional) Specifies platform features when pulling a multi-platform manifest list.   | List of strings | optional | [] |
| <a id="container_pull-puller_darwin"></a>puller_darwin |  (optional) Exposed to provide a way to test other pullers on macOS   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @go_puller_darwin//file:downloaded |
| <a id="container_pull-puller_linux_amd64"></a>puller_linux_amd64 |  (optional) Exposed to provide a way to test other pullers on Linux   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @go_puller_linux_amd64//file:downloaded |
| <a id="container_pull-puller_linux_arm64"></a>puller_linux_arm64 |  (optional) Exposed to provide a way to test other pullers on Linux   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @go_puller_linux_arm64//file:downloaded |
| <a id="container_pull-puller_linux_s390x"></a>puller_linux_s390x |  (optional) Exposed to provide a way to test other pullers on Linux   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @go_puller_linux_s390x//file:downloaded |
| <a id="container_pull-registry"></a>registry |  The registry from which we are pulling.   | String | required |  |
| <a id="container_pull-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |
| <a id="container_pull-repository"></a>repository |  The name of the image.   | String | required |  |
| <a id="container_pull-tag"></a>tag |  (optional) The tag of the image, default to 'latest' if this and 'digest' remain unspecified.   | String | optional | "latest" |


<a id="#pull.implementation"></a>

## pull.implementation

<pre>
pull.implementation(<a href="#pull.implementation-repository_ctx">repository_ctx</a>)
</pre>

Core implementation of container_pull.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="pull.implementation-repository_ctx"></a>repository_ctx |  <p align="center"> - </p>   |  none |


