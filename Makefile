SHELL := /bin/bash

.PHONY: install dev build css clean

FNM_SH := eval "$$(fnm env)" &&

css:
	$(FNM_SH) npx @tailwindcss/cli -i _css/styles.css -o styles.css --minify

dev: css
	$(FNM_SH) npx @tailwindcss/cli -i _css/styles.css -o styles.css --watch & \
	CSS_PID=$$!; \
	trap "kill $$CSS_PID 2>/dev/null" EXIT; \
	bundle exec jekyll serve --livereload

build: css
	bundle exec jekyll build

install:
	bundle install
	$(FNM_SH) npm install

clean:
	rm -rf _site .jekyll-cache
