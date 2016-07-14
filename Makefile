%.html: %.org
	pandoc --self-contained -o $@ $<

.PHONY:
all: notes.html
