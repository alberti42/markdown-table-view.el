# markdown-table-view

`markdown-table-view-mode` is a buffer-local minor mode for the
`markdown-ts-mode` bundled with Emacs 31. It changes how pipe tables are
displayed and nothing else: the buffer text is never modified, and nothing
of `markdown-ts-mode` is replaced or advised.

Column widths come from the text a reader sees in each cell: characters that
are invisible (for example link markup hidden by `markdown-ts-hide-markup`)
take no room. When the table is wider than `markdown-table-view-width`, the
widest columns are narrowed and their cells are word-wrapped onto several
screen lines. `<br>` in a cell starts a new line.

## Example

[`examples/demonstrations.md`](examples/demonstrations.md) holds a table whose
rows are written on one line each:

```markdown
| Demonstration | Catalogue | Index card |
|---|---|---|
| Additive colour mixing | [Additive colour mixing with three projectors](#additive-colour-mixing-with-three-projectors) (p. 144); [Additive colour mixing](#additive-colour-mixing) (p. 147) | [OP 14.11 Additive colour mixing](#op-1411-additive-colour-mixing) (p. 192) |
| Pixels of a monitor | [Pixels of a monitor](#pixels-of-a-monitor) (p. 144) | — |
```

With `markdown-ts-hide-markup` on and `fill-column` set to 100, the mode
draws those rows as:

```text
| Demonstration                  | Catalogue                      | Index card                     |
|--------------------------------|--------------------------------|--------------------------------|
| Additive colour mixing         | Additive colour mixing with    | OP 14.11 Additive colour       |
|                                | three projectors (p. 144);     | mixing (p. 192)                |
|                                | Additive colour mixing (p.     |                                |
|                                | 147)                           |                                |
| Pixels of a monitor            | Pixels of a monitor (p. 144)   | —                              |
```

The link labels keep the faces `markdown-ts-mode` gives them, and clicking
one follows the link.

## Requirements

- Emacs 31.1 or later, for `markdown-ts-mode`.
- The `markdown` and `markdown-inline` tree-sitter grammars, which
  `markdown-ts-mode` needs too. `M-x treesit-install-language-grammar`
  installs them.

Both are part of Emacs or fetched by it; the package needs nothing else.

## Installation

The package is not published yet. Clone the repository and add it to
`load-path`:

```elisp
(use-package markdown-table-view
  :load-path "~/path/to/markdown-table-view"
  :hook (markdown-ts-mode-hook . markdown-table-view-mode))
```

With straight.el, from a local clone:

```elisp
(use-package markdown-table-view
  :straight (markdown-table-view
             :type git
             :local-repo "~/path/to/markdown-table-view")
  :hook (markdown-ts-mode-hook . markdown-table-view-mode))
```

## Usage

`M-x markdown-table-view-mode` turns the mode on in the current buffer; the
hook above turns it on in every `markdown-ts-mode` buffer.

- The row point is on is shown as its raw text, so it can be edited and its
  links followed with RET.
- After a scroll command, a row point moved onto stays drawn until the next
  command. A scroll command is one with a non-nil `scroll-command`
  property: `mwheel-scroll`, `pixel-scroll-precision`, `scroll-up-command`,
  `scroll-down-command` and the other scroll commands of Emacs.
- Clicking a character of a drawn row moves point to that character in the
  buffer, and follows the link there if there is one.
- `markdown-ts-toggle-hide-markup` (`C-c C-x C-m`) shows and hides the
  markup; the tables are drawn again with the new widths.

## Options

| Option                                 | Default | Meaning                                                                       |
|----------------------------------------|---------|-------------------------------------------------------------------------------|
| `markdown-table-view-width`            | `nil`   | Maximum width, in columns, of a displayed table. When nil, use `fill-column`. |
| `markdown-table-view-min-column-width` | `8`     | Width below which a column is not narrowed to fit the table width.            |

## Links and emphasis in table cells

`markdown-ts-mode` runs the `markdown-inline` grammar only on `inline` nodes,
and a table cell is not one, so links, emphasis and code in a cell are not
fontified and their markup is not hidden. While the mode is on, it runs the
grammar on table cells too, and `markdown-ts-mode` fontifies them as it
fontifies a paragraph. The mode adds this rule only when
`treesit-range-settings` does not already run the grammar on table cells, so
once `markdown-ts-mode` parses table cells itself, the mode adds nothing.
Turning the mode off removes the rule.

## Hiding link markup with spaces

A configuration that hides link markup with `(space :width N)`, to keep raw
tables aligned, makes that markup count as N spaces here. Such a
configuration should use `invisible` while this mode is on.

## Tests

```sh
make test
```

The tests run in `emacs --batch --quick`. The tests that draw tables need the
`markdown` and `markdown-inline` grammars and are skipped without them.

## License

GPL-3.0-or-later. Copyright (C) 2026 Andrea Alberti.
