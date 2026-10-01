EMACS ?= emacs

TESTS = $(basename $(notdir $(wildcard test/*-tests.el)))

.PHONY: test

test:
	$(EMACS) --batch --quick -L . -L test \
	  $(addprefix -l ,$(TESTS)) \
	  -f ert-run-tests-batch-and-exit
