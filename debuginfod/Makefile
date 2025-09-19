include ../common.mk

STEAMOS_DEBUGINFOD_CONFIGS := $(wildcard *.urls)

all:

install: all
	for CONFIG in $(STEAMOS_DEBUGINFOD_CONFIGS); do \
		install -D -m644 $${CONFIG} $(DESTDIR)/etc/debuginfod/$${CONFIG}; \
	done
