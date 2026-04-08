.PHONY: test test-hugo test-md test-md-all test-md-backlog test-md-batch

OFFSET ?= 0
SIZE ?= 10

test: test-hugo test-md

test-hugo:
	@command -v hugo >/dev/null 2>&1 || { echo "hugo n'est pas installé"; exit 1; }
	hugo --gc --minify

test-md:
	@command -v npx >/dev/null 2>&1 || { echo "npx n'est pas installé (installez Node.js/npm)"; exit 1; }
	bash scripts/lint-markdown.sh --changed

test-md-all:
	@command -v npx >/dev/null 2>&1 || { echo "npx n'est pas installé (installez Node.js/npm)"; exit 1; }
	bash scripts/lint-markdown.sh --all

test-md-backlog:
	@command -v npx >/dev/null 2>&1 || { echo "npx n'est pas installé (installez Node.js/npm)"; exit 1; }
	bash scripts/lint-markdown.sh --backlog

test-md-batch:
	@command -v npx >/dev/null 2>&1 || { echo "npx n'est pas installé (installez Node.js/npm)"; exit 1; }
	bash scripts/lint-markdown.sh --batch $(OFFSET) $(SIZE)