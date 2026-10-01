# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The release workflow publishes the section of a version as the text of its
GitHub release, so before tagging `vX.Y.Z`, move `[Unreleased]` into a
`## [X.Y.Z] - YYYY-MM-DD` heading and set `Version:` in
`markdown-table-view.el` to `X.Y.Z`.

## [Unreleased]

## [0.1.0] - 2026-10-01

### Added

- `markdown-table-view-mode`, a buffer-local minor mode for `markdown-ts-mode`
  that draws pipe tables with aligned columns. Column widths come from the
  text a reader sees in each cell.
- Tables wider than `markdown-table-view-width` are narrowed column by column,
  down to `markdown-table-view-min-column-width`, and their cells are
  word-wrapped. `<br>` in a cell starts a new line.
- The row point is on is shown as its raw text. After a scroll command, a row
  point moved onto stays drawn until the next command.
- Clicking a character of a drawn row moves point to that character in the
  buffer, and follows the link there if there is one.
- Table cells are parsed with the `markdown-inline` grammar, so
  `markdown-ts-mode` fontifies their links, emphasis and code and hides their
  markup. The mode adds this rule only when `treesit-range-settings` does not
  already run the grammar on table cells.
- Data rows are drawn with alternating backgrounds: the faces
  `markdown-table-view-row`, which inherits `hl-line`, and
  `markdown-table-view-stripe`, which inherits `lazy-highlight`.
  `markdown-table-view-stripe-rows` turns them off.
- `markdown-table-view-row-lines` draws a line under each data row but the
  last, with the underline of the face `markdown-table-view-row-line`. It is
  off by default.

[Unreleased]: https://github.com/alberti42/markdown-table-view.el/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/alberti42/markdown-table-view.el/releases/tag/v0.1.0
