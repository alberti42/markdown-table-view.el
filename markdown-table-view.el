;;; markdown-table-view.el --- Aligned, wrapped display of Markdown tables -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Andrea Alberti

;; Author: Andrea Alberti <a.alberti82@gmail.com>
;; Maintainer: Andrea Alberti <a.alberti82@gmail.com>
;; Assisted-by: Claude:claude-opus-5-5
;; URL: https://github.com/alberti42/markdown-table-view
;; Version: 0.1.0
;; Package-Requires: ((emacs "31.1"))
;; Keywords: text, wp, convenience
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; `markdown-table-view-mode' is a buffer-local minor mode for
;; `markdown-ts-mode' that changes how pipe tables are displayed and
;; nothing else.  The buffer text is never modified.
;;
;; `markdown-ts-mode' runs the `markdown-inline' grammar only on
;; `inline' nodes, and a table cell is not one, so links, emphasis and
;; code in a cell are not fontified and their markup is not hidden.
;; While the mode is on, it runs the grammar on table cells too, and
;; `markdown-ts-mode' fontifies them as it fontifies a paragraph.  The
;; mode adds this rule only when `treesit-range-settings' does not
;; already run the grammar on table cells.
;;
;; Each table row is covered by an overlay whose `display' property is a
;; string drawing the row with aligned columns.  Column widths come from
;; the text a reader sees in each cell: characters that are invisible
;; (for example link markup hidden by `markdown-ts-hide-markup') take no
;; room.  When the table is wider than `markdown-table-view-width',
;; the widest columns are narrowed and their cells are word-wrapped onto
;; several screen lines.  `<br>' in a cell starts a new line.
;;
;; The row point is on is shown as its raw text, so it can be edited and
;; its links followed with RET.  After a scroll command, a row point
;; moved onto stays drawn until the next command.  Clicking a character
;; of a drawn row moves point to that character in the buffer, and
;; follows the link there if there is one.

;;; Code:

(require 'treesit)
(require 'jit-lock)
(require 'subr-x)

(defgroup markdown-table-view nil
  "Aligned, wrapped display of Markdown tables."
  :group 'text
  :prefix "markdown-table-view-")

(defcustom markdown-table-view-width nil
  "Maximum width, in columns, of a displayed table.
When nil, use `fill-column'."
  :type '(choice (const :tag "fill-column" nil) natnum))

(defcustom markdown-table-view-min-column-width 8
  "Width below which a column is not narrowed to fit the table width."
  :type 'natnum)

(defvar-local markdown-table-view--range-settings nil
  "The entries this mode added to `treesit-range-settings', or nil.")

(defvar-local markdown-table-view--revealed nil
  "Row overlay currently shown as raw text, or nil.")

(defvar markdown-table-view--rendering nil
  "Non-nil while a table is being drawn.
Stops the nested `jit-lock-fontify-now' from running the drawing
function again.")

(defvar-keymap markdown-table-view-row-map
  :doc "Keymap on the strings that draw table rows."
  "<down-mouse-1>" #'ignore
  "<mouse-1>" #'markdown-table-view-mouse-follow
  "<down-mouse-2>" #'ignore
  "<mouse-2>" #'markdown-table-view-mouse-follow)

;;; Reading the buffer

(defun markdown-table-view--visible-string (beg end)
  "Return the text between BEG and END as it is displayed.
Invisible characters are dropped and a `display' string replaces the
text it covers.  Each character carries the buffer position it came
from in the `markdown-table-view-pos' property."
  (let ((pos beg) parts)
    (while (< pos end)
      (let ((next (min (next-single-char-property-change pos 'invisible nil end)
                       (next-single-char-property-change pos 'display nil end)))
            (display (get-char-property pos 'display)))
        (cond
         ((invisible-p pos))
         ((stringp display)
          (push (propertize (copy-sequence display)
                            'markdown-table-view-pos pos)
                parts))
         ((and (eq (car-safe display) 'space)
               (natnump (plist-get (cdr display) :width)))
          (push (propertize (make-string (plist-get (cdr display) :width) ?\s)
                            'markdown-table-view-pos pos)
                parts))
         (t
          (let ((s (buffer-substring pos next)))
            (dotimes (i (length s))
              (put-text-property i (1+ i) 'markdown-table-view-pos (+ pos i) s))
            (push s parts))))
        (setq pos next)))
    (apply #'concat (nreverse parts))))

(defun markdown-table-view--row-cells (row)
  "Return the cells of table ROW as a list of (BEG . END) pairs.
The bounds exclude the pipes.  A row may omit its outer pipes."
  (let* ((beg (treesit-node-start row))
         (end (min (treesit-node-end row)
                   (save-excursion (goto-char beg) (pos-eol))))
         (pipes (mapcar #'treesit-node-start
                        (seq-filter (lambda (n) (equal (treesit-node-type n) "|"))
                                    (treesit-node-children row))))
         (bounds (append (unless (eql (car pipes) beg) (list (1- beg)))
                         pipes
                         (unless (eql (car (last pipes)) (1- end)) (list end))))
         cells)
    (while (cdr bounds)
      (push (cons (1+ (car bounds)) (cadr bounds)) cells)
      (setq bounds (cdr bounds)))
    (nreverse cells)))

(defun markdown-table-view--cell-paragraphs (beg end)
  "Return the displayed text of the cell from BEG to END.
The value is a list of strings, one per piece separated by `<br>'."
  (let ((case-fold-search t))
    (mapcar #'string-trim
            (split-string (markdown-table-view--visible-string beg end)
                          "<br[ \t]*/?>"))))

(defun markdown-table-view--alignments (row)
  "Return the column alignments declared by delimiter ROW.
Each element is `left', `right' or `center'."
  (mapcar (lambda (cell)
            (let ((text (string-trim (buffer-substring-no-properties
                                      (car cell) (cdr cell)))))
              (cond ((and (string-prefix-p ":" text) (string-suffix-p ":" text)
                          (> (length text) 1))
                     'center)
                    ((string-suffix-p ":" text) 'right)
                    (t 'left))))
          (markdown-table-view--row-cells row)))

;;; Layout

(defun markdown-table-view--column-widths (natural target)
  "Narrow the NATURAL column widths until the table fits TARGET columns.
A table with N columns of widths W takes sum(W) + 3N + 1 columns.  The
widest column is narrowed by one until the table fits or every column
is at `markdown-table-view-min-column-width'."
  (let* ((widths (copy-sequence natural))
         (n (length widths))
         (floor markdown-table-view-min-column-width))
    (while (and (> (+ (apply #'+ widths) (* 3 n) 1) target)
                (seq-some (lambda (w) (> w floor)) widths))
      (let ((i (seq-position widths (apply #'max widths))))
        (setf (nth i widths) (1- (nth i widths)))))
    widths))

(defun markdown-table-view--break-word (word width)
  "Split WORD into pieces no wider than WIDTH."
  (let (pieces)
    (while (> (string-width word) width)
      (let ((head (truncate-string-to-width word width)))
        (when (string-empty-p head)
          (setq head (substring word 0 1)))
        (push head pieces)
        (setq word (substring word (length head)))))
    (nreverse (cons word pieces))))

(defun markdown-table-view--wrap (paragraph width)
  "Word-wrap PARAGRAPH into lines no wider than WIDTH.
Lines are substrings of PARAGRAPH, so they keep its text properties."
  (let ((pos 0) (line-beg nil) (line-end nil) lines)
    (while (string-match "[^ \t]+" paragraph pos)
      (let ((wbeg (match-beginning 0))
            (wend (match-end 0)))
        (cond
         ((and line-beg
               (<= (string-width (substring paragraph line-beg wend)) width))
          (setq line-end wend))
         (t
          (when line-beg
            (push (substring paragraph line-beg line-end) lines))
          (let ((word (substring paragraph wbeg wend)))
            (if (<= (string-width word) width)
                (setq line-beg wbeg line-end wend)
              (let ((pieces (markdown-table-view--break-word word width)))
                (setq lines (append (reverse (butlast pieces)) lines))
                (setq line-end wend
                      line-beg (- wend (length (car (last pieces)))))))))))
      (setq pos (match-end 0)))
    (when line-beg
      (push (substring paragraph line-beg line-end) lines))
    (or (nreverse lines) (list ""))))

(defun markdown-table-view--pad (text width alignment)
  "Pad TEXT with spaces to WIDTH, placing it according to ALIGNMENT."
  (let* ((gap (max 0 (- width (string-width text))))
         (left (pcase alignment
                 ('right gap)
                 ('center (/ gap 2))
                 (_ 0))))
    (concat (make-string left ?\s) text (make-string (- gap left) ?\s))))

(defun markdown-table-view--draw-row (cells widths alignments)
  "Return the string drawing a row whose cells are CELLS.
CELLS is a list of cells, each a list of paragraphs.  WIDTHS and
ALIGNMENTS give each column's width and alignment."
  (let* ((wrapped (seq-map-indexed
                   (lambda (width i)
                     (mapcan (lambda (p) (markdown-table-view--wrap p width))
                             (nth i cells)))
                   widths))
         (height (apply #'max 1 (mapcar #'length wrapped)))
         lines)
    (dotimes (k height)
      (push (concat "|"
                    (mapconcat
                     (lambda (i)
                       (concat " "
                               (markdown-table-view--pad
                                (or (nth k (nth i wrapped)) "")
                                (nth i widths) (nth i alignments))
                               " |"))
                     (number-sequence 0 (1- (length widths)))))
            lines))
    (mapconcat #'identity (nreverse lines) "\n")))

(defun markdown-table-view--draw-delimiter (widths alignments)
  "Return the string drawing the delimiter row for WIDTHS and ALIGNMENTS."
  (concat "|"
          (mapconcat
           (lambda (i)
             (let ((dashes (make-string (+ 2 (nth i widths)) ?-)))
               (pcase (nth i alignments)
                 ('right (aset dashes (1- (length dashes)) ?:))
                 ('center (aset dashes 0 ?:)
                          (aset dashes (1- (length dashes)) ?:)))
               (concat dashes "|")))
           (number-sequence 0 (1- (length widths))))))

;;; Drawing a table

(defun markdown-table-view--delete-overlays (beg end)
  "Delete this mode's overlays that overlap BEG to END."
  (dolist (ov (overlays-in beg end))
    (when (overlay-get ov 'markdown-table-view)
      (delete-overlay ov))))

(defun markdown-table-view--render-table (table revealed)
  "Cover each row of TABLE with an overlay that draws it aligned.
The row starting at REVEALED is left as raw text."
  ;; The old overlays go first: the cells are read with
  ;; `get-char-property', which would return their `display' strings.
  (markdown-table-view--delete-overlays (treesit-node-start table)
                                        (treesit-node-end table))
  (let* ((rows (seq-filter
                (lambda (n) (member (treesit-node-type n)
                                    '("pipe_table_header"
                                      "pipe_table_delimiter_row"
                                      "pipe_table_row")))
                (treesit-node-children table)))
         (delimiter (seq-find (lambda (n) (equal (treesit-node-type n)
                                                 "pipe_table_delimiter_row"))
                              rows))
         (data (mapcar (lambda (row)
                         (unless (eq row delimiter)
                           (mapcar (lambda (cell)
                                     (markdown-table-view--cell-paragraphs
                                      (car cell) (cdr cell)))
                                   (markdown-table-view--row-cells row))))
                       rows))
         (ncols (apply #'max 1 (mapcar #'length data)))
         (natural (mapcar (lambda (i)
                            (apply #'max 1
                                   (mapcar (lambda (cells)
                                             (apply #'max 0
                                                    (mapcar #'string-width
                                                            (nth i cells))))
                                           data)))
                          (number-sequence 0 (1- ncols))))
         (widths (markdown-table-view--column-widths
                  natural (or markdown-table-view-width fill-column)))
         (alignments (let ((a (and delimiter
                                   (markdown-table-view--alignments delimiter))))
                       (mapcar (lambda (i) (or (nth i a) 'left))
                               (number-sequence 0 (1- ncols))))))
    (seq-mapn
     (lambda (row cells)
       (let* ((beg (treesit-node-start row))
              (end (min (treesit-node-end row)
                        (save-excursion (goto-char beg) (pos-eol))))
              (string (if (eq row delimiter)
                          (markdown-table-view--draw-delimiter widths alignments)
                        (markdown-table-view--draw-row cells widths alignments)))
              (ov (make-overlay beg end nil t nil)))
         (add-face-text-property 0 (length string) 'markdown-ts-table t string)
         (add-text-properties 0 (length string)
                              (list 'keymap markdown-table-view-row-map
                                    'pointer 'arrow)
                              string)
         (overlay-put ov 'markdown-table-view t)
         (overlay-put ov 'markdown-table-view-string string)
         (overlay-put ov 'evaporate t)
         (if (eql beg revealed)
             (setq markdown-table-view--revealed ov)
           (overlay-put ov 'display string))))
     rows data)))

(defun markdown-table-view--fontify (beg end)
  "Draw every table that overlaps BEG to END.
Runs from `jit-lock-functions' after font-lock, since the drawing reads
the faces and invisibility font-lock puts on the cells.  A table is
drawn whole, so the parts of it outside BEG to END are fontified
first.
The row `markdown-table-view--reveal' revealed stays raw.  Point is not
used: `jit-lock-fontify-now' moves it to the start of the chunk."
  (unless markdown-table-view--rendering
    (let ((markdown-table-view--rendering t)
          (revealed (and markdown-table-view--revealed
                         (overlay-start markdown-table-view--revealed))))
      (markdown-table-view--delete-overlays beg end)
      (when (treesit-parser-list nil 'markdown)
        (dolist (table (treesit-query-capture 'markdown '((pipe_table) @table)
                                              beg end t))
          (jit-lock-fontify-now (treesit-node-start table)
                                (treesit-node-end table))
          (markdown-table-view--render-table table revealed))))))

;;; Point and mouse

(defun markdown-table-view--row-overlay-at-point ()
  "Return the row overlay on the line of point, or nil."
  (seq-find (lambda (ov) (overlay-get ov 'markdown-table-view))
            (overlays-in (pos-bol) (pos-eol))))

(defun markdown-table-view--reveal ()
  "Show the row point is on as raw text, and draw the one point left.
After a command with a non-nil `scroll-command' property, a row point
moved onto stays drawn."
  (let ((ov (markdown-table-view--row-overlay-at-point))
        (old markdown-table-view--revealed))
    (when (and (symbolp this-command) (get this-command 'scroll-command)
               (not (eq ov old)))
      (setq ov nil))
    (unless (eq ov old)
      (when (and old (overlay-buffer old))
        (overlay-put old 'display (overlay-get old 'markdown-table-view-string)))
      (when ov
        (overlay-put ov 'display nil))
      (setq markdown-table-view--revealed ov))))

(defun markdown-table-view-mouse-follow (event)
  "Move point to the buffer text under the drawn row clicked in EVENT.
When that text is a link, follow it with the command RET runs there."
  (interactive "e")
  (let* ((posn (event-start event))
         (string (posn-string posn))
         (pos (or (and string
                       (get-text-property (cdr string) 'markdown-table-view-pos
                                          (car string)))
                  (posn-point posn))))
    (select-window (posn-window posn))
    (goto-char pos)
    (markdown-table-view--reveal)
    (when (get-char-property pos 'mouse-face)
      (let ((command (key-binding (kbd "RET") t nil pos)))
        (when (commandp command)
          (call-interactively command))))))

;;; Parsing cells

(defun markdown-table-view--cells-parsed-p ()
  "Return non-nil when `treesit-range-settings' runs `markdown-inline' on cells.
A compiled query cannot be read back, so each query that embeds
`markdown-inline' is run on a small table in a temporary buffer, and
the value is non-nil when one of them captures a `pipe_table_cell'."
  (when-let* ((queries (seq-keep (lambda (setting)
                                   (and (eq (nth 1 setting) 'markdown-inline)
                                        (car setting)))
                                 treesit-range-settings)))
    (with-temp-buffer
      (insert "| a |\n|---|\n| b |\n")
      (let ((root (treesit-parser-root-node (treesit-parser-create 'markdown))))
        (seq-some (lambda (query)
                    (seq-some (lambda (capture)
                                (equal (treesit-node-type (cdr capture))
                                       "pipe_table_cell"))
                              (treesit-query-capture root query)))
                  queries)))))

(defun markdown-table-view--parse-cells (on)
  "Run the `markdown-inline' grammar on table cells if ON is non-nil.
The rule is added only when `markdown-table-view--cells-parsed-p' is
nil.  When ON is nil, remove the rule this mode added and delete the
parsers made for the cells."
  (when markdown-table-view--range-settings
    (setq-local treesit-range-settings
                (seq-difference treesit-range-settings
                                markdown-table-view--range-settings #'eq))
    (setq markdown-table-view--range-settings nil)
    ;; treesit deletes a local parser it no longer needs only after the
    ;; buffer is modified.
    (dolist (ov (overlays-in (point-min) (point-max)))
      (let ((parser (overlay-get ov 'treesit-parser)))
        (when (and parser
                   (overlay-get ov 'treesit-parser-local-p)
                   (eq (treesit-parser-language parser) 'markdown-inline)
                   (treesit-parent-until
                    (treesit-node-at (overlay-start ov) 'markdown)
                    "\\`pipe_table_cell\\'" t))
          (treesit-parser-delete parser)
          (delete-overlay ov)))))
  (when (and on
             (treesit-parser-list nil 'markdown)
             (treesit-language-available-p 'markdown-inline)
             (not (markdown-table-view--cells-parsed-p)))
    (setq markdown-table-view--range-settings
          (treesit-range-rules
           :embed 'markdown-inline
           :host 'markdown
           :local t
           '((pipe_table_cell) @markdown-inline)))
    (setq-local treesit-range-settings
                (append treesit-range-settings
                        markdown-table-view--range-settings))))

;;; Mode

;;;###autoload
(define-minor-mode markdown-table-view-mode
  "Display Markdown pipe tables with aligned, wrapped columns.
The buffer text is not changed.  The row point is on is shown as its
raw text, except after a scroll command moved point onto it.
Table cells are parsed as inline Markdown, so their links, emphasis and
code are fontified."
  :lighter nil
  (cond
   (markdown-table-view-mode
    (jit-lock-register #'markdown-table-view--fontify)
    ;; `jit-lock-register' puts the function first; it has to run after
    ;; font-lock, whose faces and invisibility it reads.
    (remove-hook 'jit-lock-functions #'markdown-table-view--fontify t)
    (add-hook 'jit-lock-functions #'markdown-table-view--fontify 90 t)
    (add-hook 'post-command-hook #'markdown-table-view--reveal nil t)
    (markdown-table-view--parse-cells t))
   (t
    (markdown-table-view--parse-cells nil)
    (jit-lock-unregister #'markdown-table-view--fontify)
    (remove-hook 'post-command-hook #'markdown-table-view--reveal t)
    (markdown-table-view--delete-overlays (point-min) (point-max))
    (setq markdown-table-view--revealed nil)))
  (font-lock-flush))

(provide 'markdown-table-view)
;;; markdown-table-view.el ends here
