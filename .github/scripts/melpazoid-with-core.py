"""Run melpazoid with pretty-tables installed from this checkout.

melpazoid installs a package's Package-Requires from MELPA.  An adaptor
requires pretty-tables, which this repository ships too, so this script
adds to the requirements script melpazoid generates the installation of
pretty-tables.el from the checkout, with `package-install-from-buffer'.
package-lint then finds pretty-tables in `package-alist'.  The Emacs of
melpazoid's container can be older than the one pretty-tables requires,
so the copy installed there requires the container's Emacs instead; the
package under test keeps its own header.

Run from the melpazoid checkout, with RECIPE and LOCAL_REPO set as for
`make':

    cd ~/melpazoid && python3 $LOCAL_REPO/.github/scripts/melpazoid-with-core.py
"""

import sys
from pathlib import Path

# melpazoid finds its Makefile and Docker files from the path of its
# module, so the module is imported from the checkout, not from an
# installed copy.
sys.path.insert(0, str(Path.cwd()))
from melpazoid import melpazoid  # noqa: E402

CORE = Path(melpazoid._local_repo()) / 'pretty-tables.el'
_write_requirements = melpazoid._write_requirements


def _elisp_string(text: str) -> str:
    """Return TEXT as an Emacs Lisp string literal."""
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"') + '"'


def write_requirements(name: str, files: list[Path]) -> None:
    """Write melpazoid's requirements, then install pretty-tables.el."""
    _write_requirements(name, files)
    with Path('_requirements.el').open('a', encoding='utf-8') as requirements:
        requirements.write(
            '\n(message "Installing pretty-tables from the checkout")\n'
            '(with-temp-buffer\n'
            f'  (insert {_elisp_string(CORE.read_text(encoding="utf-8"))})\n'
            '  (goto-char (point-min))\n'
            '  (re-search-forward "^;; Package-Requires: .*(emacs \\"\\\\([0-9.]+\\\\)\\")")\n'
            '  (replace-match emacs-version t t nil 1)\n'
            '  (package-install-from-buffer))\n'
        )


melpazoid._write_requirements = write_requirements
melpazoid._main()
sys.exit(melpazoid._return_code())
