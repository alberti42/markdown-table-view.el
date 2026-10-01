# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The release workflow publishes the section of a version as the text of its
GitHub release, so before tagging `vX.Y.Z`, move `[Unreleased]` into a
`## [X.Y.Z] - YYYY-MM-DD` heading and set `Version:` in
`markdown-table-view.el` to `X.Y.Z`.

## [Unreleased]

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

[Unreleased]: https://github.com/alberti42/markdown-table-view.el/commits/main
