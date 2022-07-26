load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository", "new_git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

git_repository(
    name = "s4nnc",
    commit = "aecee3ff69db4b57aadc3968a3d290aebb61b8fe",
    remote = "https://github.com/liuliu/s4nnc.git",
    shallow_since = "1661269458 -0400",
)

load("@s4nnc//:deps.bzl", "s4nnc_deps")

s4nnc_deps()

load("@ccv//config:ccv.bzl", "ccv_deps", "ccv_setting")

ccv_deps()

load("@build_bazel_rules_cuda//gpus:cuda_configure.bzl", "cuda_configure")
load("@build_bazel_rules_cuda//nccl:nccl_configure.bzl", "nccl_configure")

cuda_configure(name = "local_config_cuda")

nccl_configure(name = "local_config_nccl")

ccv_setting(
    name = "local_config_ccv",
    have_cblas = True,
    have_cudnn = True,
    have_fftw3 = True,
    have_gsl = True,
    have_libjpeg = True,
    have_liblinear = False,
    have_libpng = True,
    have_nccl = True,
    have_pthread = True,
    have_tesseract = True,
    use_dispatch = True,
    use_openmp = True,
)

git_repository(
    name = "build_bazel_rules_swift",
    commit = "3bc7bc164020a842ae08e0cf071ed35f0939dd39",
    remote = "https://github.com/bazelbuild/rules_swift.git",
    shallow_since = "1654173801 -0500",
)

load("@build_bazel_rules_swift//swift:repositories.bzl", "swift_rules_dependencies")

swift_rules_dependencies()

load("@build_bazel_rules_swift//swift:extras.bzl", "swift_rules_extra_dependencies")

swift_rules_extra_dependencies()

http_archive(
    name = "rules_python",
    url = "https://github.com/bazelbuild/rules_python/releases/download/0.4.0/rules_python-0.4.0.tar.gz",
    sha256 = "954aa89b491be4a083304a2cb838019c8b8c3720a7abb9c4cb81ac7a24230cea",
)

load("@rules_python//python:pip.bzl", "pip_install")

# Install Python dependencies

pip_install(
    requirements = ":requirements.txt",
)

git_repository(
    name = "swift-jupyter",
    commit = "8e8bc98c11381d62bc76fafbf5e0e50522e67a78",
    remote = "https://github.com/liuliu/swift-jupyter.git",
    shallow_since = "1659051282 -0400",
)

git_repository(
    name = "swift-mujoco",
    commit = "3c0a4496bd3b984fb5ddceebc8f8def7c698bd2f",
    remote = "https://github.com/liuliu/swift-mujoco.git",
    shallow_since = "1658628786 -0400"
)

load("@swift-mujoco//:deps.bzl", "swift_mujoco_deps")

swift_mujoco_deps()

new_git_repository(
    name = "swift-atomics",
    build_file = "swift-atomics.BUILD",
    commit = "088df27f0683f2b458021ebf04873174b91ae597",
    remote = "https://github.com/apple/swift-atomics.git",
    shallow_since = "1649274362 -0700",
)

new_git_repository(
    name = "SwiftNIO",
    build_file = "swift-nio.BUILD",
    commit = "48916a49afedec69275b70893c773261fdd2cfde",
    remote = "https://github.com/apple/swift-nio.git",
    shallow_since = "1657195654 +0100",
)

new_git_repository(
    name = "SwiftArgumentParser",
    build_file = "swift-argument-parser.BUILD",
    commit = "82905286cc3f0fa8adc4674bf49437cab65a8373",
    remote = "https://github.com/apple/swift-argument-parser.git",
    shallow_since = "1647436700 -0500",
)

new_git_repository(
    name = "SwiftSystem",
    build_file = "swift-system.BUILD",
    commit = "836bc4557b74fe6d2660218d56e3ce96aff76574",
    remote = "https://github.com/apple/swift-system.git",
    shallow_since = "1638472952 -0800",
)

new_git_repository(
    name = "SwiftToolsSupportCore",
    build_file = "swift-tools-support-core.BUILD",
    commit = "b7667f3e266af621e5cc9c77e74cacd8e8c00cb4",
    remote = "https://github.com/apple/swift-tools-support-core.git",
    shallow_since = "1643831290 -0800",
)

new_git_repository(
    name = "SwiftSyntax",
    build_file = "swift-syntax.BUILD",
    commit = "0b6c22b97f8e9320bca62e82cdbee601cf37ad3f",
    remote = "https://github.com/apple/swift-syntax.git",
    shallow_since = "1647591231 +0100",
)

new_git_repository(
    name = "SwiftFormat",
    build_file = "swift-format.BUILD",
    commit = "e6b8c60c7671066d229e30efa1e31acf57be412e",
    remote = "https://github.com/apple/swift-format.git",
    shallow_since = "1647972246 -0700",
)

new_git_repository(
    name = "SwiftCrypto",
    build_file = "swift-crypto.BUILD",
    commit = "a8911e0fadc25aef1071d582355bd1037a176060",
    remote = "https://github.com/apple/swift-crypto.git",
    shallow_since = "1641892042 +0000",
)

load("@s4nnc//:deps.bzl", "s4nnc_extra_deps")

s4nnc_extra_deps()

# buildifier is written in Go and hence needs rules_go to be built.
# See https://github.com/bazelbuild/rules_go for the up to date setup instructions.

http_archive(
    name = "io_bazel_rules_go",
    sha256 = "d1ffd055969c8f8d431e2d439813e42326961d0942bdf734d2c95dc30c369566",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.24.5/rules_go-v0.24.5.tar.gz",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.24.5/rules_go-v0.24.5.tar.gz",
    ],
)

load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains()

http_archive(
    name = "bazel_gazelle",
    sha256 = "b85f48fa105c4403326e9525ad2b2cc437babaa6e15a3fc0b1dbab0ab064bc7c",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.22.2/bazel-gazelle-v0.22.2.tar.gz",
        "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.22.2/bazel-gazelle-v0.22.2.tar.gz",
    ],
)

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

gazelle_dependencies()

git_repository(
    name = "com_github_bazelbuild_buildtools",
    commit = "174cbb4ba7d15a3ad029c2e4ee4f30ea4d76edce",
    remote = "https://github.com/bazelbuild/buildtools.git",
    shallow_since = "1607975103 +0100",
)
