load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

cc_library(
    name = "CCryptoBoringSSL",
    srcs = glob([
        "Sources/CCryptoBoringSSL/crypto/**/*.c",
        "Sources/CCryptoBoringSSL/crypto/**/*.h",
        "Sources/CCryptoBoringSSL/third_party/**/*.h",
    ]) + glob(["Sources/CCryptoBoringSSL/crypto/**/*.linux.x86_64.S"]) + ["Sources/CCryptoBoringSSL/crypto/hrss/asm/poly_rq_mul.S"],
    hdrs = glob(["Sources/CCryptoBoringSSL/include/**/*.h"]),
    defines = ["WIN32_LEAN_AND_MEAN"],
    includes = [
        "Sources/CCryptoBoringSSL/include/",
    ],
    tags = ["swift_module=CCryptoBoringSSL"],
)

cc_library(
    name = "CCryptoBoringSSLShims",
    srcs = ["Sources/CCryptoBoringSSLShims/shims.c"],
    hdrs = ["Sources/CCryptoBoringSSLShims/include/CCryptoBoringSSLShims.h"],
    defines = ["CRYPTO_IN_SWIFTPM"],
    includes = [
        "Sources/CCryptoBoringSSLShims/include/",
    ],
    tags = ["swift_module=CCryptoBoringSSLShims"],
    deps = [
        ":CCryptoBoringSSL",
    ],
)

swift_library(
    name = "Crypto",
    srcs = glob([
        "Sources/Crypto/**/*.swift",
    ]),
    defines = ["CRYPTO_IN_SWIFTPM"],
    module_name = "Crypto",
    visibility = ["//visibility:public"],
    deps = [
        ":CCryptoBoringSSL",
        ":CCryptoBoringSSLShims",
    ],
)

swift_library(
    name = "_CryptoExtras",
    srcs = glob([
        "Sources/_CryptoExtras/**/*.swift",
    ]),
    module_name = "_CryptoExtras",
    visibility = ["//visibility:public"],
    deps = [
        ":CCrypto",
        ":CCryptoBoringSSL",
        ":CCryptoBoringSSLShims",
    ],
)
