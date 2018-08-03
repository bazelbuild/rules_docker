load("//container:container.bzl", "container_import")

package(default_visibility = ["//visibility:public"])

PAUSE_CONFIG = "2b58359142b094165abfc9ad9c327c453a3eaa624d0c5ee8f0ed1ab50483603b.json"

genrule(
    name = "pause_config",
    srcs = ["//testdata:pause.tar"],
    outs = ["pause_config.json"],
    cmd = ("tar xOf $(location //testdata:pause.tar) %s " +
           "> $(location :pause_config.json)") % PAUSE_CONFIG,
)

PAUSE_LAYERS = [
    "9285c41a2f85a67c85185be04743004e806fd1e16777f2230166281f4e49cb4c",
    "da7bd81140ca921a067c604a3ba3f54d4e0d51ba5276cd9f32ad6a28e588f470",
]

[genrule(
    name = "extract_%s" % id,
    srcs = ["//testdata:pause.tar"],
    outs = ["%s.tar" % id],
    cmd = ("tar xOf $(location //testdata:pause.tar) %s/layer.tar " +
           "> $(location :%s.tar)") % (id, id),
) for id in PAUSE_LAYERS]

[genrule(
    name = "extract_%s_gz" % id,
    srcs = ["//testdata:pause.tar"],
    outs = ["%s.tar.gz" % id],
    cmd = ("tar xOf $(location //testdata:pause.tar) %s/layer.tar " +
           "| gzip -n > $(location :%s.tar.gz)") % (id, id),
) for id in PAUSE_LAYERS]

container_import(
    name = "pause_piecemeal",
    config = ":pause_config.json",
    layers = ["%s.tar" % x for x in PAUSE_LAYERS],
)

filegroup(
    name = "gz_layers",
    srcs = [":%s.tar.gz" % x for x in PAUSE_LAYERS],
)
