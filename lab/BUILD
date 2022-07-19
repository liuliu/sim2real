load("@pip//:requirements.bzl", "requirement")

py_library(
    name = "common",
    visibility = ["//lab:__subpackages__"],
    deps = [
        requirement("jupyterlab"),
        requirement("pandas"),
        requirement("numpy"),
        requirement("matplotlib"),
    ],
)

py_binary(
    name = "bootup",
    srcs = ["bootup.py"],
    data = ["//lab/kernels/swift:swift_kernel"],
    deps = [
        ":common",
        "@bazel_tools//tools/python/runfiles",
    ],
)
