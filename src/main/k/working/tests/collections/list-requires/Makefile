include $(CURDIR)/../../../include.mk

KOMPILED := list-requires-kompiled
DEFINITION := $(KOMPILED)/definition.kore

$(DEFINITION): list-requires.k
	$(KOMPILE) $(KOMPILE_OPTS) $< --syntax-module LIST-REQUIRES

%.output: %.list-requires $(DEFINITION) $(KORE_EXEC)
	$(KRUN) $(KRUN_OPTS) $< --output-file $@

%.krun: %.list-requires $(DEFINITION) $(KORE_EXEC)
	$(KRUN) $(KRUN_OPTS) $<

%.test: %.output
	diff -u $<.golden $<

%.output.golden: %.output
	mv $< $<.golden

test: tests/1.test

test-k: tests/1.test

golden: tests/1.output.golden

clean:
	rm -rf $(KOMPILED) tests/*.output

.PHONY: test-k test golden clean %.test %.krun
