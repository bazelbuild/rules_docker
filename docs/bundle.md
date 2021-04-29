Rule for bundling Container images into a tarball.
<a id="#container_bundle_"></a>

## container_bundle_

<pre>
container_bundle_(<a href="#container_bundle_-name">name</a>, <a href="#container_bundle_-extract_config">extract_config</a>, <a href="#container_bundle_-image_target_strings">image_target_strings</a>, <a href="#container_bundle_-image_targets">image_targets</a>, <a href="#container_bundle_-images">images</a>,
                  <a href="#container_bundle_-incremental_load_template">incremental_load_template</a>, <a href="#container_bundle_-stamp">stamp</a>, <a href="#container_bundle_-tar_output">tar_output</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="container_bundle_-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="container_bundle_-extract_config"></a>extract_config |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container/go/cmd/extract_config:extract_config |
| <a id="container_bundle_-image_target_strings"></a>image_target_strings |  -   | List of strings | optional | [] |
| <a id="container_bundle_-image_targets"></a>image_targets |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| <a id="container_bundle_-images"></a>images |  -   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| <a id="container_bundle_-incremental_load_template"></a>incremental_load_template |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | //container:incremental_load_template |
| <a id="container_bundle_-stamp"></a>stamp |  -   | Boolean | optional | False |
| <a id="container_bundle_-tar_output"></a>tar_output |  -   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional |  |


<a id="#container_bundle"></a>

## container_bundle

<pre>
container_bundle(<a href="#container_bundle-kwargs">kwargs</a>)
</pre>

Package several container images into a single tarball.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="container_bundle-kwargs"></a>kwargs |  See above.   |  none |


