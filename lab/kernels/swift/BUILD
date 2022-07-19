load("@pip//:requirements.bzl", "requirement")

py_library(
    name = "matplotlib_swift",
    srcs = [
        "matplotlib_swift/__init__.py",
        "matplotlib_swift/backend_inline.py",
    ],
    imports = ["."],
)

py_binary(
    name = "swift_kernel",
    srcs = ["swift_kernel.py"],
    data = ["whole_archive.bzl"],
    visibility = ["//lab:__subpackages__"],
    deps = [
        ":matplotlib_swift",
        "//lab:common",
        "@bazel_tools//tools/python/runfiles",
    ],
)
