dev:
	@echo "Starting development server"
	@cd docs && bundle exec jekyll serve

install:
	@echo "Installing dependencies"
	@cd docs && bundle install && npm install
