load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_binary")

cc_library(
    name = "CNIOAtomics",
    srcs = glob(["Sources/CNIOAtomics/src/*.c", "Sources/CNIOAtomics/src/*.h"]),
    hdrs = glob(["Sources/CNIOAtomics/include/*.h"]),
    includes = [
        "Sources/CNIOAtomics/include/",
    ],
    tags = ["swift_module=CNIOAtomics"],
)

cc_library(
    name = "CNIOSHA1",
    srcs = glob(["Sources/CNIOSHA1/*.c", "Sources/CNIOSHA1/*.h"]),
    hdrs = glob(["Sources/CNIOSHA1/include/*.h"]),
    includes = [
        "Sources/CNIOSHA1/include/",
    ],
    tags = ["swift_module=CNIOSHA1"],
)

cc_library(
    name = "CNIOLinux",
    srcs = glob(["Sources/CNIOLinux/*.c", "Sources/CNIOLinux/*.h"]),
    hdrs = glob(["Sources/CNIOLinux/include/*.h"]),
    includes = [
        "Sources/CNIOLinux/include/",
    ],
    tags = ["swift_module=CNIOLinux"],
)

cc_library(
    name = "CNIODarwin",
    srcs = glob(["Sources/CNIODarwin/*.c", "Sources/CNIODarwin/*.h"]),
    hdrs = glob(["Sources/CNIODarwin/include/*.h"]),
    defines = ["__APPLE_USE_RFC_3542"],
    includes = [
        "Sources/CNIODarwin/include/",
    ],
    tags = ["swift_module=CNIODarwin"],
)

cc_library(
    name = "CNIOWindows",
    srcs = glob(["Sources/CNIOWindows/*.c", "Sources/CNIOWindows/*.h"]),
    hdrs = glob(["Sources/CNIOWindows/include/*.h"]),
    includes = [
        "Sources/CNIOWindows/include/",
    ],
    tags = ["swift_module=CNIOWindows"],
)

swift_library(
    name = "NIOConcurrencyHelpers",
    srcs = glob([
        "Sources/NIOConcurrencyHelpers/**/*.swift",
    ]),
    deps = [":CNIOAtomics"],
    module_name = "NIOConcurrencyHelpers",
    visibility = ["//visibility:public"],
)

swift_library(
    name = "NIOCore",
    srcs = glob([
        "Sources/NIOCore/**/*.swift",
    ]),
    deps = [":NIOConcurrencyHelpers", ":CNIOLinux", ":CNIOWindows"],
    module_name = "NIOCore",
    visibility = ["//visibility:public"],
)

swift_library(
    name = "_NIODataStructures",
    srcs = glob([
        "Sources/_NIODataStructures/**/*.swift",
    ]),
    module_name = "_NIODataStructures",
)

swift_library(
    name = "NIOEmbedded",
    srcs = glob([
        "Sources/NIOEmbedded/**/*.swift",
    ]),
    deps = [":NIOCore", ":NIOConcurrencyHelpers", ":_NIODataStructures", "@swift-atomics//:SwiftAtomics"],
    module_name = "NIOEmbedded",
    visibility = ["//visibility:public"],
)

swift_library(
    name = "NIOPosix",
    srcs = glob([
        "Sources/NIOPosix/**/*.swift",
    ]),
    deps = [":CNIOLinux", ":CNIODarwin", ":CNIOWindows", ":NIOCore", ":NIOConcurrencyHelpers", ":_NIODataStructures", "@swift-atomics//:SwiftAtomics"],
    module_name = "NIOPosix",
    visibility = ["//visibility:public"],
)

swift_library(
    name = "NIO",
    srcs = glob([
        "Sources/NIO/**/*.swift",
    ]),
    deps = [":NIOCore", ":NIOEmbedded", ":NIOPosix"],
    module_name = "NIO",
    visibility = ["//visibility:public"],
)

swift_library(
    name = "NIOFoundationCompat",
    srcs = glob([
        "Sources/NIOFoundationCompat/**/*.swift",
    ]),
    deps = [":NIO", ":NIOCore"],
    module_name = "NIOFoundationCompat",
    visibility = ["//visibility:public"],
)

cc_library(
    name = "CNIOHTTPParser",
    srcs = glob(["Sources/CNIOHTTPParser/*.c", "Sources/CNIOHTTPParser/*.h"]),
    hdrs = glob(["Sources/CNIOHTTPParser/include/*.h"]),
    includes = [
        "Sources/CNIOWindows/include/",
    ],
    tags = ["swift_module=CNIOHTTPParser"],
)

swift_library(
    name = "NIOHTTP1",
    srcs = glob([
        "Sources/NIOHTTP1/**/*.swift",
    ]),
    deps = [":NIO", ":NIOCore", ":NIOConcurrencyHelpers", ":CNIOHTTPParser"],
    module_name = "NIOHTTP1",
    visibility = ["//visibility:public"],
)

swift_library(
    name = "NIOTLS",
    srcs = glob([
        "Sources/NIOTLS/**/*.swift",
    ]),
    module_name = "NIOTLS",
    deps = [":NIO", ":NIOCore"],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "NIOWebSocket",
    srcs = glob([
        "Sources/NIOWebSocket/**/*.swift",
    ]),
    module_name = "NIOWebSocket",
    deps = [":NIO", ":NIOCore", ":NIOHTTP1", ":CNIOSHA1"],
    visibility = ["//visibility:public"],
)

swift_binary(
    name = "NIOHTTP1Server",
    srcs = glob([
        "Sources/NIOHTTP1Server/**/*.swift",
    ]),
	deps = [":NIOPosix", ":NIOCore", ":NIOConcurrencyHelpers", ":NIOHTTP1"],
)
