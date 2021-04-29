Rule for importing a container image.
<a id="#container_import"></a>

## container_import

<pre>
container_import(<a href="#container_import-name">name</a>, <a href="#container_import-base_image_digest">base_image_digest</a>, <a href="#container_import-base_image_registry">base_image_registry</a>, <a href="#container_import-base_image_repository">base_image_repository</a>, <a href="#container_import-config">config</a>,
                 <a href="#container_import-extract_config">extract_config</a>, <a href="#container_import-incremental_load_template">incremental_load_template</a>, <a href="#container_import-layers">layers</a>, <a href="#container_import-manifest">manifest</a>, <a href="#container_import-repository">repository</a>, <a href="#container_import-sha256">sha256</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_import-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="container_import-base_image_digest"></a>base_image_digest |  The digest of the image   | String | optional | "" |
| <a id="container_import-base_image_registry"></a>base_image_registry |  The registry from which we pulled the image   | String | optional | "" |
| <a id="container_import-base_image_repository"></a>base_image_repository |  The repository from which we pulled the image   | String | optional | "" |
| <a id="container_import-config"></a>config |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="container_import-extract_config"></a>extract_config |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container/go/cmd/extract_config:extract_config |
| <a id="container_import-incremental_load_template"></a>incremental_load_template |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container:incremental_load_template |
| <a id="container_import-layers"></a>layers |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required |  |
| <a id="container_import-manifest"></a>manifest |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| <a id="container_import-repository"></a>repository |  -   | String | optional | "bazel" |
| <a id="container_import-sha256"></a>sha256 |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //tools/build_defs/hash:sha256 |


