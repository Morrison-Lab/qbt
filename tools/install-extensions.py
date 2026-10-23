"""Install the third-party Quarto extensions that this repository does not vendor.

`coatless-quarto/custom-callout` publishes no license, so a copy of it is not
committed here; this script fetches it at a pinned commit instead.
Run as a Quarto `pre-render` script, before any other, so the extension is in
`_extensions/` by the time a page's filters are resolved.
An extension that is already installed is left alone.
To change a pin, edit EXTENSIONS and nothing else.
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Each entry: (installed path under `_extensions/`, upstream repository,
# commit, path of the extension inside that repository).
EXTENSIONS = [
    (
        "coatless-quarto/custom-callout",
        "https://github.com/coatless-quarto/custom-callout",
        "dca63b4f7178f7b544c10196202665029adca1a7",
        "_extensions/custom-callout",
    ),
]


def run(*args, cwd=None):
    subprocess.run(args, cwd=cwd, check=True, capture_output=True, text=True)


def install(target, repository, commit, source):
    with tempfile.TemporaryDirectory() as scratch:
        run("git", "init", "--quiet", scratch)
        run("git", "fetch", "--quiet", "--depth", "1", repository, commit, cwd=scratch)
        run("git", "checkout", "--quiet", "FETCH_HEAD", cwd=scratch)
        shutil.copytree(Path(scratch) / source, target)


def main():
    root = Path(__file__).resolve().parent.parent / "_extensions"
    for path, repository, commit, source in EXTENSIONS:
        target = root / path
        if target.exists():
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        try:
            install(target, repository, commit, source)
        except subprocess.CalledProcessError as err:
            print(
                f"install-extensions: could not fetch {repository} at {commit}: "
                f"{err.stderr.strip()}",
                file=sys.stderr,
            )
            sys.exit(1)
        print(f"install-extensions: installed {path} from {repository}@{commit[:8]}")


if __name__ == "__main__":
    main()
