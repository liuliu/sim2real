import re
import sys
import os
import json
import tempfile

from bazel_tools.tools.python.runfiles import runfiles
from jupyterlab.labapp import main

r = runfiles.Create()

SWIFTPATH = "/opt/swift"


def register_kernels():
    kernel_json = {
        "argv": [
            sys.executable,
            r.Rlocation("__main__/lab/kernels/swift/swift_kernel"),
            "-f",
            "{connection_file}",
        ],
        "display_name": "Swift",
        "language": "swift",
        "env": {
            "PYTHONPATH": os.path.join(
                SWIFTPATH,
                "usr/lib/python3/dist-packages",
            ),
            "REPL_SWIFT_PATH": os.path.join(SWIFTPATH, "usr/bin/repl_swift"),
            "LD_LIBRARY_PATH": os.path.join(SWIFTPATH, "usr/lib/swift/linux"),
            "SWIFT_BUILD_PATH": os.path.join(SWIFTPATH, "usr/bin/swift-build"),
            "SWIFT_PACKAGE_PATH": os.path.join(SWIFTPATH, "usr/bin/swift-package"),
            "SOURCEKIT_LSP_PATH": os.path.join(SWIFTPATH, "usr/bin/sourcekit-lsp"),
        },
    }

    kernel_code_name = "swift"

    td = tempfile.mkdtemp()
    os.environ["JUPYTER_DATA_DIR"] = td
    kernel_td = os.path.join(td, "kernels", "swift")
    os.makedirs(kernel_td, exist_ok=True)
    with open(os.path.join(kernel_td, "kernel.json"), "w") as f:
        json.dump(kernel_json, f, indent=2)


if __name__ == "__main__":
    sys.argv[0] = re.sub(r"(-script\.pyw?|\.exe)?$", "", sys.argv[0])
    jupyterlab = os.path.dirname(
        r.Rlocation("pip/pypi__jupyterlab/jupyterlab/__init__.py")
    )
    os.environ["JUPYTERLAB_DIR"] = jupyterlab
    register_kernels()
    sys.exit(main())
