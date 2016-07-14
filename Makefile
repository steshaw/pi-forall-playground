%.html: %.org
	pandoc --self-contained -o $@ $<

.PHONY:
all: notes1.html
