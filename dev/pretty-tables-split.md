# Splitting into pretty-tables — a plan not built

A plan for drawing Org tables as this package draws Markdown tables, by
splitting the code into a shared core package and one adaptor per markup.
It is decided and not started: the split happens while the Org adaptor is
written, so that the core's interface is designed from two adaptors.

Recorded 2026-10-01.

## Names

| Package | Replaces | Mode |
|---|---|---|
| `pretty-tables` | — (the core) | none |
| `pretty-tables-for-markdown` | `markdown-table-view` | `pretty-tables-for-markdown-mode` |
| `pretty-tables-for-org` | — | `pretty-tables-for-org-mode` |

One repository, `pretty-tables` (or `pretty-tables-for-emacs`), with one MELPA
recipe per package, each with its own `:files`, as `latex-to-svg` ships its
front-end and adaptors.

Names considered:

- **`table-view`:** rejected. The built-in `table.el` uses the `table-` prefix
  for 188 definitions; a reader may take `table-view` for part of it.
- **`tableviewer`:** rejected. A viewer suggests read-only, and this package
  shows the row point is on as raw text so that it can be edited.
- **`pretty-tables`:** chosen. In Emacs "pretty" means display only, as in the
  built-in `prettify-symbols-mode`: the buffer text is not changed. The name
  is meant to be easy to remember; the README and the summary line say what
  the package does.

In September 2026 no package on MELPA, GNU ELPA or NonGNU ELPA had a name
starting with `pretty-tables`, `table-view` or `tableviewer`, and Emacs defines
nothing starting with `pretty-`.

## What depends on Markdown

About a quarter of `markdown-table-view.el`:

- **Finding the tables and their rows:** the `pipe_table` tree-sitter query in
  `markdown-table-view--fontify`, and how `markdown-table-view--render-table`
  walks the row nodes.
- **`markdown-table-view--row-cells`:** cell bounds from the `|` nodes,
  including rows without outer pipes.
- **`markdown-table-view--alignments`:** alignment from the colons of the
  delimiter row.
- **`markdown-table-view--cell-paragraphs`:** `<br>` as the line break inside
  a cell.
- **`markdown-table-view--parse-cells` and
  `markdown-table-view--cells-parsed-p`:** the range rule that runs
  `markdown-inline` on table cells. It works around `markdown-ts-mode`.

## What goes into the core

- **Reading cells as displayed** (`--visible-string`): invisibility, `display`
  strings and `(space :width N)`. Org hides link brackets with `invisible`
  too, so this works unchanged.
- **Layout:** `--column-widths`, `--wrap`, `--break-word`, `--pad`,
  `--draw-row`.
- **Row faces:** `--row-face`, `--decorate-row` and the row lines, with the
  faces and options.
- **Overlays and jit-lock:** registering at depth 90, the nested
  `jit-lock-fontify-now` on the whole table, the `--rendering` guard, and
  deleting a table's overlays before reading its cells.
- **Point and mouse:** reveal, the scroll-command rule, the row keymap and the
  mouse command.
- **Redrawing:** the option watchers and the theme hooks.
- **Most of the tests.**

## The interface

An adaptor gives the core a function that returns, for a region of the
buffer, each table that overlaps it as plain data:

- the bounds of each row;
- the kind of each row: header, separator or data;
- the cell bounds of each row;
- an alignment per column;
- how to split a cell into lines (`<br>` for Markdown).

The core does the rest. Each package keeps its own minor mode,
customization group and documentation.

## Where Org differs

- **Org edits the buffer:** `org-table-align` pads the cells in the text, so
  raw Org tables are already aligned. The gain in Org is wrapping, and widths
  without hidden link text. The core reads cells with their padding trimmed,
  so this works; an Org user may expect the revealed raw row to stay aligned.
- **Separators anywhere:** an Org `|---+---|` line can appear between any two
  rows, not only under the header, so the kind of a row comes from each row.
- **Org's own column shrinking:** width cookies (`<10>`) and
  `org-table-shrink` narrow columns with overlays of their own. The adaptor
  has to honour or ignore them, and not fight over the same text.
- **Alignment cookies:** `<l>`, `<r>` and `<c>` set the alignment, and Org
  right-aligns numeric columns by default.
- **Special rows and columns:** `#+TBLFM` lines and the marking columns (`!`,
  `#`, `$`, `^`).
- **No line break inside a cell:** Org has no counterpart of `<br>`.
- **No tree-sitter:** Org fontifies with font-lock regexps. The core does not
  use tree-sitter; only the Markdown adaptor does.

## Steps at the split

- Rename the GitHub repository `alberti42/markdown-table-view.el`. GitHub
  redirects the old URLs, but the `URL:` header, the badges, the melpazoid
  recipe and `release.yml` name the new one.
- Check whether the v0.1.0 attestations still verify. They were signed by
  `alberti42/markdown-table-view.el/.github/workflows/release.yml`; after the
  rename, `gh attestation verify --repo <new name>` may not match that signer,
  and the README's verification section may need the old name for 0.1.0.
- Decide whether the three packages share one version and one tag, or each
  has its own. `release.yml` today reads a single `Version:` header.
- Set the adaptors' `Package-Requires` to the lowest `pretty-tables` version
  they work with.
- In the changelog of the first release under the new names, tell 0.1.0
  users that the mode, option and face names changed.
