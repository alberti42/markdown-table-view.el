EMACS ?= emacs

.PHONY: test

test:
	$(EMACS) --batch --quick -L . -L test \
	  -l markdown-table-view-tests \
	  -f ert-run-tests-batch-and-exit
