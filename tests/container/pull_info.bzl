


import_info_test = rule(
    implementation = _impl,
    attrs = {
        "target": attr.label(providers = [JavaInfo]),
        "ignore_prefixes": attr.string_list(doc = "prefixes of jar entries to ignore", default = []),
        "ignore_suffixes": attr.string_list(doc = "suffixes of jar entries to ignore", default = []),
        "_validator": attr.label(providers = [DefaultInfo], default = "//src/main/com/bazelbuild/java/classpath:classpath_run"),
    },
    test = True,
)