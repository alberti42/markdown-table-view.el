;;; markdown-table-view-tests.el --- Tests for markdown-table-view -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Andrea Alberti

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
;; Run with `make test'.  The tests that draw tables need the `markdown'
;; and `markdown-inline' tree-sitter grammars and are skipped without
;; them.

;;; Code:

(require 'ert)
(require 'markdown-table-view)
(require 'markdown-ts-mode)

;;; Helpers

(defmacro markdown-table-view-tests--with-buffer (text &rest body)
  "Run BODY in a `markdown-ts-mode' buffer holding TEXT.
Font-lock and `markdown-table-view-mode' are on, the table width is
80, and point is at the start of the buffer."
  (declare (indent 1) (debug t))
  `(progn
     (skip-unless (and (treesit-language-available-p 'markdown)
                       (treesit-language-available-p 'markdown-inline)))
     (let ((buf (generate-new-buffer "markdown-table-view-test")))
       (unwind-protect
           (with-current-buffer buf
             (insert ,text)
             (markdown-ts-mode)
             ;; `font-lock-mode' does not turn on in batch mode.
             (let ((noninteractive nil))
               (font-lock-mode 1))
             (setq-local markdown-table-view-width 80)
             (markdown-table-view-mode 1)
             (goto-char (point-min))
             (jit-lock-fontify-now)
             ,@body)
         (kill-buffer buf)))))

(defun markdown-table-view-tests--overlays ()
  "Return this mode's overlays in the buffer, in buffer order."
  (sort (seq-filter (lambda (ov) (overlay-get ov 'markdown-table-view))
                    (overlays-in (point-min) (point-max)))
        (lambda (a b) (< (overlay-start a) (overlay-start b)))))

(defun markdown-table-view-tests--rows ()
  "Return the string drawing each row, without text properties."
  (mapcar (lambda (ov)
            (substring-no-properties
             (overlay-get ov 'markdown-table-view-string)))
          (markdown-table-view-tests--overlays)))

(defun markdown-table-view-tests--hide-markup (value)
  "Set `markdown-ts-hide-markup' to VALUE and fontify the buffer again."
  (setq-local markdown-ts-hide-markup value)
  (markdown-ts--set-hide-markup value)
  (jit-lock-fontify-now))

(defun markdown-table-view-tests--goto-row (n)
  "Move point to the start of table row N, counting from 0."
  (goto-char (overlay-start (nth n (markdown-table-view-tests--overlays)))))

(defconst markdown-table-view-tests--link-table
  "# Title

| Name | Link |
|------|------|
| one | [Emacs](https://www.gnu.org/software/emacs/) |
| two | plain |

End.
"
  "A table whose second column holds a link.")

;;; Layout

(ert-deftest markdown-table-view-test-column-widths-fit ()
  "Widths that fit the target are returned unchanged."
  (should (equal (markdown-table-view--column-widths '(10 20 5) 80)
                 '(10 20 5))))

(ert-deftest markdown-table-view-test-column-widths-narrow ()
  "The widest column is narrowed until the table fits."
  ;; 3 columns take 10 columns of pipes and spaces, leaving 30.
  (should (equal (markdown-table-view--column-widths '(10 30 5) 40)
                 '(10 15 5))))

(ert-deftest markdown-table-view-test-column-widths-floor ()
  "No column is narrowed below `markdown-table-view-min-column-width'."
  (let ((markdown-table-view-min-column-width 8))
    (should (equal (markdown-table-view--column-widths '(10 30 5) 30)
                   '(8 8 5)))))

(ert-deftest markdown-table-view-test-break-word ()
  "A word is split into pieces no wider than the width."
  (should (equal (markdown-table-view--break-word "abcdefgh" 3)
                 '("abc" "def" "gh")))
  (should (equal (markdown-table-view--break-word "日本語" 4)
                 '("日本" "語"))))

(ert-deftest markdown-table-view-test-wrap ()
  "A paragraph is word-wrapped, and a word wider than the width is broken."
  (should (equal (markdown-table-view--wrap "the quick brown fox" 9)
                 '("the quick" "brown fox")))
  (should (equal (markdown-table-view--wrap "a abcdefghij b" 4)
                 '("a" "abcd" "efgh" "ij b")))
  (should (equal (markdown-table-view--wrap "" 4) '(""))))

(ert-deftest markdown-table-view-test-wrap-keeps-properties ()
  "Wrapped lines keep the text properties of the paragraph."
  (let* ((paragraph (concat "aaa " (propertize "bbb" 'face 'bold)))
         (lines (markdown-table-view--wrap paragraph 3)))
    (should (equal lines '("aaa" "bbb")))
    (should (eq (get-text-property 0 'face (nth 1 lines)) 'bold))))

(ert-deftest markdown-table-view-test-pad ()
  "Text is padded to the width according to the alignment."
  (should (equal (markdown-table-view--pad "ab" 6 'left) "ab    "))
  (should (equal (markdown-table-view--pad "ab" 6 'right) "    ab"))
  (should (equal (markdown-table-view--pad "ab" 6 'center) "  ab  "))
  (should (equal (markdown-table-view--pad "abcdef" 4 'left) "abcdef")))

(ert-deftest markdown-table-view-test-draw-delimiter ()
  "The delimiter row shows each column's alignment."
  (should (equal (markdown-table-view--draw-delimiter
                  '(3 4 5) '(left right center))
                 "|-----|-----:|:-----:|")))

(ert-deftest markdown-table-view-test-draw-row ()
  "A row is as tall as its tallest cell."
  (should (equal (markdown-table-view--draw-row
                  '(("a") ("b" "c")) '(3 3) '(left right))
                 "| a   |   b |\n|     |   c |")))

;;; Reading the buffer

(ert-deftest markdown-table-view-test-visible-string ()
  "The text is read as it is displayed."
  (with-temp-buffer
    (insert "abcdef")
    (put-text-property 2 3 'invisible t)
    (put-text-property 3 4 'display "XY")
    (put-text-property 4 5 'display '(space :width 3))
    (let ((s (markdown-table-view--visible-string 1 7)))
      (should (equal (substring-no-properties s) "aXY   ef"))
      (should (equal (mapcar (lambda (i)
                               (get-text-property i 'markdown-table-view-pos s))
                             (number-sequence 0 (1- (length s))))
                     '(1 3 3 4 4 4 5 6))))))

;;; Drawing tables

(ert-deftest markdown-table-view-test-draw-table ()
  "Columns are aligned to their widest cell."
  (markdown-table-view-tests--with-buffer
      "# Title\n\n| a | bb |\n|---|---|\n| ccc | d |\n"
    (should (equal (markdown-table-view-tests--rows)
                   '("| a   | bb |"
                     "|-----|----|"
                     "| ccc | d  |")))))

(ert-deftest markdown-table-view-test-alignment ()
  "The delimiter row sets each column's alignment."
  (markdown-table-view-tests--with-buffer
      "# Title\n\n| a | b | c |\n|:--|--:|:-:|\n| xxxxx | yyyyy | zzzzz |\n"
    (should (equal (markdown-table-view-tests--rows)
                   '("| a     |     b |   c   |"
                     "|-------|------:|:-----:|"
                     "| xxxxx | yyyyy | zzzzz |")))))

(ert-deftest markdown-table-view-test-br ()
  "`<br>' starts a new line in a cell."
  (markdown-table-view-tests--with-buffer
      "# Title\n\n| a | b |\n|---|---|\n| one<br>two | x |\n"
    (should (equal (car (last (markdown-table-view-tests--rows)))
                   "| one | x |\n| two |   |"))))

(ert-deftest markdown-table-view-test-wrap-to-width ()
  "A table wider than `markdown-table-view-width' is wrapped."
  (markdown-table-view-tests--with-buffer
      "# Title\n\n| a | b |\n|---|---|\n| x | one two three four |\n"
    (setq-local markdown-table-view-width 20)
    (font-lock-flush)
    (jit-lock-fontify-now)
    (should (equal (markdown-table-view-tests--rows)
                   '("| a | b            |"
                     "|---|--------------|"
                     "| x | one two      |\n|   | three four   |")))))

(ert-deftest markdown-table-view-test-hide-markup ()
  "Hidden link markup takes no room, and the table follows the toggle."
  (markdown-table-view-tests--with-buffer markdown-table-view-tests--link-table
    (markdown-table-view-tests--hide-markup t)
    (should (equal (markdown-table-view-tests--rows)
                   '("| Name | Link  |"
                     "|------|-------|"
                     "| one  | Emacs |"
                     "| two  | plain |")))
    (markdown-table-view-tests--hide-markup nil)
    (should (equal (nth 2 (markdown-table-view-tests--rows))
                   "| one  | [Emacs](https://www.gnu.org/software/emacs/) |"))))

(ert-deftest markdown-table-view-test-partial-chunk ()
  "Fontifying part of a table draws the whole table from the buffer text.
The rows outside the region still have their overlays when the table
is read, as they do when jit-lock fontifies a window in chunks."
  (markdown-table-view-tests--with-buffer markdown-table-view-tests--link-table
    (let ((expected (markdown-table-view-tests--rows))
          (last-row (overlay-start
                     (car (last (markdown-table-view-tests--overlays))))))
      (font-lock-flush)
      (jit-lock-fontify-now last-row (point-max))
      (should (equal (markdown-table-view-tests--rows) expected)))))

(ert-deftest markdown-table-view-test-mode-off ()
  "Turning the mode off removes its overlays."
  (markdown-table-view-tests--with-buffer markdown-table-view-tests--link-table
    (should (markdown-table-view-tests--overlays))
    (markdown-table-view-mode -1)
    (should-not (markdown-table-view-tests--overlays))))

;;; Stripes and row lines

(defun markdown-table-view-tests--faces (string)
  "Return the faces anywhere in STRING, as one flat list."
  (let (faces)
    (dotimes (i (length string))
      (let ((face (get-text-property i 'face string)))
        (setq faces (append (ensure-list face) faces))))
    (delete-dups faces)))

(defconst markdown-table-view-tests--four-rows
  "# Title\n\n| a | b |\n|---|---|\n| r0 | x |\n| r1 | y |\n| r2 | z<br>w |\n| r3 | v |\n"
  "A table with four data rows; the third is two screen lines tall.")

(defun markdown-table-view-tests--row-strings ()
  "Return the string drawing each row, with its text properties."
  (mapcar (lambda (ov) (overlay-get ov 'markdown-table-view-string))
          (markdown-table-view-tests--overlays)))

(ert-deftest markdown-table-view-test-stripes ()
  "Data rows alternate between the row and stripe faces.
The header and the delimiter row get neither."
  (markdown-table-view-tests--with-buffer markdown-table-view-tests--four-rows
    (should (equal (mapcar (lambda (row)
                             (let ((faces (markdown-table-view-tests--faces row)))
                               (cond ((memq 'markdown-table-view-stripe faces) 'stripe)
                                     ((memq 'markdown-table-view-row faces) 'row))))
                           (markdown-table-view-tests--row-strings))
                   '(nil nil row stripe row stripe)))))

(ert-deftest markdown-table-view-test-stripes-not-on-newlines ()
  "The newlines between the screen lines of a row get no background face."
  (markdown-table-view-tests--with-buffer markdown-table-view-tests--four-rows
    (let* ((row (nth 4 (markdown-table-view-tests--row-strings)))
           (newline (string-search "\n" row))
           (faces (ensure-list (get-text-property newline 'face row))))
      (should newline)
      (should (memq 'markdown-table-view-row
                    (ensure-list (get-text-property (1- newline) 'face row))))
      (should (memq 'markdown-table-view-row
                    (ensure-list (get-text-property (1+ newline) 'face row))))
      (should-not (memq 'markdown-table-view-row faces))
      (should-not (memq 'markdown-table-view-stripe faces)))))

(ert-deftest markdown-table-view-test-row-face-defined ()
  "The faces the row face inherits are defined once the package is loaded."
  (should (facep 'hl-line))
  (should (facep 'lazy-highlight)))

(ert-deftest markdown-table-view-test-stripes-off ()
  "With `markdown-table-view-stripe-rows' nil, no row gets a background face."
  (let ((markdown-table-view-stripe-rows nil))
    (markdown-table-view-tests--with-buffer markdown-table-view-tests--four-rows
      (should-not (seq-some (lambda (row)
                              (let ((faces (markdown-table-view-tests--faces row)))
                                (or (memq 'markdown-table-view-stripe faces)
                                    (memq 'markdown-table-view-row faces))))
                            (markdown-table-view-tests--row-strings))))))

(ert-deftest markdown-table-view-test-row-lines ()
  "The last screen line of each data row but the last has the row-line face."
  (let ((markdown-table-view-row-lines t))
    (markdown-table-view-tests--with-buffer markdown-table-view-tests--four-rows
      (let* ((rows (markdown-table-view-tests--row-strings))
             (lined (lambda (s)
                      (and (memq 'markdown-table-view-row-line
                                 (markdown-table-view-tests--faces s))
                           t))))
        (should (equal (mapcar lined rows) '(nil nil t t t nil)))
        ;; In the two-line row, only the second screen line is underlined.
        (let* ((row (nth 4 rows))
               (newline (string-search "\n" row)))
          (should-not (funcall lined (substring row 0 newline)))
          (should (funcall lined (substring row (1+ newline)))))))))

(ert-deftest markdown-table-view-test-row-lines-off ()
  "By default no row line is drawn."
  (markdown-table-view-tests--with-buffer markdown-table-view-tests--four-rows
    (should-not (seq-some (lambda (row)
                            (memq 'markdown-table-view-row-line
                                  (markdown-table-view-tests--faces row)))
                          (markdown-table-view-tests--row-strings)))))

(ert-deftest markdown-table-view-test-stripe-under-cell-faces ()
  "The stripe comes after the faces of the cell text."
  (markdown-table-view-tests--with-buffer
      "# Title\n\n| a |\n|---|\n| x |\n| **b** |\n"
    (let* ((row (car (last (markdown-table-view-tests--row-strings))))
           (pos (string-search "b" row))
           (face (get-text-property pos 'face row)))
      (should (memq 'markdown-table-view-stripe face))
      (should (< (seq-position face 'markdown-ts-bold)
                 (seq-position face 'markdown-table-view-stripe))))))

;;; Parsing cells

(defun markdown-table-view-tests--cell-pos (text)
  "Return the position of the first occurrence of TEXT after the table header."
  (save-excursion
    (goto-char (point-min))
    (search-forward "|--")
    (search-forward text)
    (match-beginning 0)))

(ert-deftest markdown-table-view-test-parse-cells ()
  "Links and emphasis in cells are fontified and their markup hidden."
  (markdown-table-view-tests--with-buffer
      "# Title\n\n| a | b |\n|---|---|\n| **bold** | [Emacs](https://x.org) |\n"
    (should (get-text-property (markdown-table-view-tests--cell-pos "Emacs")
                               'button))
    (markdown-table-view-tests--hide-markup t)
    (should (equal (car (last (markdown-table-view-tests--rows)))
                   "| bold | Emacs |"))))

(ert-deftest markdown-table-view-test-cells-parsed-p ()
  "`markdown-ts-mode' alone does not run `markdown-inline' on cells."
  (markdown-table-view-tests--with-buffer "# Title\n"
    (markdown-table-view-mode -1)
    (should-not (markdown-table-view--cells-parsed-p))
    (markdown-table-view-mode 1)
    (should (markdown-table-view--cells-parsed-p))))

(ert-deftest markdown-table-view-test-parse-cells-installed ()
  "A rule that already parses cells is used, and the mode adds none.
The rule has the form a fixed `markdown-ts-mode' would install."
  (markdown-table-view-tests--with-buffer
      "# Title\n\n| a | b |\n|---|---|\n| **bold** | [Emacs](https://x.org) |\n"
    (markdown-table-view-mode -1)
    (setq-local treesit-range-settings
                (append treesit-range-settings
                        (treesit-range-rules
                         :embed 'markdown-inline
                         :host 'markdown
                         :local t
                         '([(inline) (pipe_table_cell)] @markdown-inline))))
    (let ((settings treesit-range-settings))
      (markdown-table-view-mode 1)
      (should-not markdown-table-view--range-settings)
      (should (eq treesit-range-settings settings))
      (markdown-table-view-tests--hide-markup t)
      (should (equal (car (last (markdown-table-view-tests--rows)))
                     "| bold | Emacs |"))
      (markdown-table-view-mode -1)
      (should (eq treesit-range-settings settings))
      (should (treesit-local-parsers-at
               (markdown-table-view-tests--cell-pos "Emacs") 'markdown-inline)))))

(ert-deftest markdown-table-view-test-parse-cells-mode-off ()
  "Turning the mode off removes the range rule and the cell parsers."
  (markdown-table-view-tests--with-buffer
      "# Title\n\n| a | b |\n|---|---|\n| x | [Emacs](https://x.org) |\n\nA [link](https://y.org).\n"
    (let ((cell (markdown-table-view-tests--cell-pos "Emacs"))
          (paragraph (markdown-table-view-tests--cell-pos "link")))
      (should (treesit-local-parsers-at cell 'markdown-inline))
      (markdown-table-view-mode -1)
      (jit-lock-fontify-now)
      (should-not markdown-table-view--range-settings)
      (should-not (treesit-local-parsers-at cell 'markdown-inline))
      (should-not (get-text-property cell 'button))
      (should (treesit-local-parsers-at paragraph 'markdown-inline))
      (should (get-text-property paragraph 'button)))))

;;; Point

(ert-deftest markdown-table-view-test-reveal ()
  "The row point is on is shown raw; the row point left is drawn again."
  (markdown-table-view-tests--with-buffer markdown-table-view-tests--link-table
    (let ((ovs (markdown-table-view-tests--overlays))
          (this-command 'next-line))
      (should (seq-every-p (lambda (ov) (overlay-get ov 'display)) ovs))
      (markdown-table-view-tests--goto-row 2)
      (markdown-table-view--reveal)
      (should-not (overlay-get (nth 2 ovs) 'display))
      (markdown-table-view-tests--goto-row 3)
      (markdown-table-view--reveal)
      (should (overlay-get (nth 2 ovs) 'display))
      (should-not (overlay-get (nth 3 ovs) 'display)))))

(ert-deftest markdown-table-view-test-redraw-keeps-revealed ()
  "Drawing a table again leaves the revealed row raw.
`jit-lock-fontify-now' moves point to the start of the region, so the
drawing cannot find the row from point."
  (markdown-table-view-tests--with-buffer markdown-table-view-tests--link-table
    (markdown-table-view-tests--goto-row 2)
    (let ((this-command 'next-line))
      (markdown-table-view--reveal))
    (font-lock-flush)
    (jit-lock-fontify-now)
    (let ((ovs (markdown-table-view-tests--overlays)))
      (should-not (overlay-get (nth 2 ovs) 'display))
      (should (eq markdown-table-view--revealed (nth 2 ovs))))))

(ert-deftest markdown-table-view-test-scroll-keeps-drawn ()
  "After a scroll command, a row point moved onto stays drawn."
  (markdown-table-view-tests--with-buffer markdown-table-view-tests--link-table
    (let ((ovs (markdown-table-view-tests--overlays))
          (this-command 'scroll-up-command))
      (markdown-table-view-tests--goto-row 2)
      (markdown-table-view--reveal)
      (should (overlay-get (nth 2 ovs) 'display))
      (should-not markdown-table-view--revealed))))

(ert-deftest markdown-table-view-test-scroll-keeps-revealed ()
  "After a scroll command, a row that was already revealed stays revealed."
  (markdown-table-view-tests--with-buffer markdown-table-view-tests--link-table
    (let ((ovs (markdown-table-view-tests--overlays)))
      (markdown-table-view-tests--goto-row 2)
      (let ((this-command 'next-line))
        (markdown-table-view--reveal))
      (let ((this-command 'mwheel-scroll))
        (markdown-table-view--reveal))
      (should-not (overlay-get (nth 2 ovs) 'display))
      (should (eq markdown-table-view--revealed (nth 2 ovs))))))

(provide 'markdown-table-view-tests)
;;; markdown-table-view-tests.el ends here
