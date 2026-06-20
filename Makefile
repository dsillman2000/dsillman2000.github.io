SHELL := /bin/bash

.PHONY: install serve build css clean fonts resume

FNM_SH := eval "$$(fnm env)" &&

install: fonts
	bundle install
	$(FNM_SH) npm install

css:
	$(FNM_SH) npx @tailwindcss/cli -i _css/styles.css -o styles.css --minify

serve: css
	$(FNM_SH) npx @tailwindcss/cli -i _css/styles.css -o styles.css --watch & \
	CSS_PID=$$!; \
	trap "kill $$CSS_PID 2>/dev/null" EXIT; \
	bundle exec jekyll serve --livereload --host 0.0.0.0

build: css
	bundle exec jekyll build

clean:
	rm -rf _site .jekyll-cache

fonts:
	mkdir -p assets/fonts
	curl -sL -o assets/fonts/InterVariable.woff2 \
		https://raw.githubusercontent.com/rsms/inter/master/docs/font-files/InterVariable.woff2
	curl -sL -o assets/fonts/RobotoMono-Variable.woff2 \
		"https://raw.githubusercontent.com/googlefonts/RobotoMono/main/fonts/webfonts/RobotoMono%5Bwght%5D.woff2"

resume:
	mkdir -p assets/docs
	OUTPUT_DIR=assets/docs python3 build_resume.py
	soffice --headless --convert-to pdf --outdir assets/docs assets/docs/David_Sillman_Resume.docx
