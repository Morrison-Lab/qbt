#!/usr/bin/env python3
"""Link the tracked-changes Word file from gha's preview home-page banner.

gha's `changed-chapters-banner` writes a banner to the home page, but it has no
link to the Word file `docx-tracked-changes` generates (gha#1025). This adds
that link, and the `no-preview-highlights` tip, inside gha's banner. It does not
make a second banner.

Environment:
  RENDERED_DIR  Directory holding the staged preview site. Required.

Anything unexpected is an error rather than a silent no-op: a wrong directory,
a missing home page, or a home page without gha's banner all exit non-zero.
No tracked-changes file is not an error. That is the normal case when there is
no published Word file to compare against.
"""

import html
import os
import re
import sys
from pathlib import Path

END_MARKER = "<!-- gha-preview-banner:end -->"
MY_MARKER = "<!-- qbt-docx-link -->"
TAIL_RE = re.compile(r"</p></div>\s*" + re.escape(END_MARKER))


def main():
    raw = os.getenv("RENDERED_DIR", "").strip()
    if not raw:
        sys.exit("RENDERED_DIR is required")
    rendered = Path(raw)
    if not rendered.is_dir():
        sys.exit(f"rendered directory {rendered} does not exist")

    index = rendered / "index.html"
    if not index.is_file():
        sys.exit(f"home page {index} does not exist")

    docx_files = sorted(rendered.glob("*-tracked-changes.docx"))
    if not docx_files:
        print("No tracked-changes Word file in the preview; nothing to link.")
        return

    page = index.read_text(encoding="utf-8")
    if MY_MARKER in page:
        print("Word link already present.")
        return
    if not TAIL_RE.search(page):
        sys.exit(
            f"{index} has no gha preview banner to add the Word link to "
            "(is `changed-chapters-banner` on?)"
        )

    links = ", ".join(
        f'<a href="{html.escape(f.name, quote=True)}" download>{html.escape(f.name)}</a>'
        for f in docx_files
    )
    extra = (
        f"{MY_MARKER}<br><strong>Word file with tracked changes:</strong> {links}"
        "<br><strong>Tip:</strong> if change highlighting is glitchy, add the "
        "<code>no-preview-highlights</code> label to this pull request."
    )
    page = TAIL_RE.sub(lambda _: extra + "</p></div>\n" + END_MARKER, page, count=1)
    index.write_text(page, encoding="utf-8")
    print(f"Added a link to {len(docx_files)} Word file(s) in {index}.")


if __name__ == "__main__":
    main()
