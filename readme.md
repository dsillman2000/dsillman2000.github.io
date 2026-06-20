# dsillman2000.github.io

David Sillman's personal website and technical blog, hosted at [www.dsillman.com](https://www.dsillman.com).

Built with [Jekyll 4](https://jekyllrb.com/) and the custom [Swimmer](https://github.com/dsillman2000/swimmer) theme (forked from [Poole](https://github.com/poole/poole) by [@mdo](https://github.com/mdo)), styled with [Tailwind CSS v4](https://tailwindcss.com/). Deployed to [GitHub Pages](https://pages.github.com/).

## Prerequisites

- Ruby 3.3.2 (see `.ruby-version`)
- Node.js 24 (see `.node-version`; managed via [fnm](https://github.com/Schniz/fnm))
- Bundler (`gem install bundler`)

## Setup

```sh
make install
```

This runs `bundle install`, `npm install`, and downloads the Inter and Roboto Mono variable fonts into `assets/fonts/`.

## Development

```sh
make serve
```

Compiles Tailwind CSS, starts a watcher for CSS changes, and launches `jekyll serve` with live reload at `http://localhost:4000`.

## Build

```sh
make build
```

Compiles Tailwind CSS and builds the Jekyll site into `_site/`.

## Other commands

| Command | Description |
|---------|-------------|
| `make css` | Compile and minify Tailwind CSS only |
| `make clean` | Remove `_site/` and `.jekyll-cache/` |
| `make fonts` | Re-download Inter and Roboto Mono fonts |
| `make resume` | Generate resume `.docx` and `.pdf` into `assets/docs/` |

## Project structure

```
_config.yml        Jekyll configuration
_css/              Tailwind CSS source partials (theme entry point: styles.css)
_includes/         Jekyll HTML partials (head, mathjax, sidebar)
_layouts/          Jekyll layout templates (default, page, post)
_posts/            Blog posts (Markdown)
assets/            Static assets (fonts, images, resume docs)
styles.css         Compiled Tailwind CSS output (generated)
Makefile           Build automation
build_resume.py    Resume generator script (python-docx)
```
