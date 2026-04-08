.PHONY: test test-hugo test-md

test: test-hugo test-md

test-hugo:
	@command -v hugo >/dev/null 2>&1 || { echo "hugo n'est pas installé"; exit 1; }
	hugo --gc --minify

test-md:
	@command -v npx >/dev/null 2>&1 || { echo "npx n'est pas installé (installez Node.js/npm)"; exit 1; }
	npx --yes markdownlint-cli2@0.18.1