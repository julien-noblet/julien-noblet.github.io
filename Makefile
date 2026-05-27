.PHONY: test test-hugo test-md test-md-all test-md-backlog test-md-batch

OFFSET ?= 0
SIZE ?= 10

test:
	nix develop --command test-all

test-hugo:
	nix develop --command test-hugo

test-md:
	nix develop --command test-md

test-md-all:
	nix develop --command test-md-all

test-md-backlog:
	nix develop --command test-md-backlog

test-md-batch:
	nix develop --command test-md-batch $(OFFSET) $(SIZE)