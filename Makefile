%.html: %.org
	pandoc --self-contained -o $@ $<

.PHONY:
all: $(patsubst %.org,%.html,$(wildcard *.org))
