.PHONY: test lint format coverage install clean docs api-documentation docs-all vimtags check all

# Add luarocks local bin to PATH
LUAROCKS_BIN := $(HOME)/.luarocks/bin
PATH := $(LUAROCKS_BIN):$(PATH)

# Default target
all: lint test

# Run tests
test:
	@echo "Running tests..."
	busted --verbose

# Run tests with coverage
coverage:
	@echo "Running tests with coverage..."
	busted --verbose --coverage
	luacov -r html

# Run linter
lint:
	@echo "Running luacheck..."
	luacheck lua/ --globals vim

# Format code
format:
	@echo "Formatting code with stylua..."
	stylua lua/ spec/

# Format check (for CI)
format-check:
	@echo "Checking code formatting..."
	stylua --check lua/ spec/

# Install development dependencies
install:
	@echo "Installing development dependencies..."
	luarocks install --local busted
	luarocks install --local luacov
	luarocks install --local luacov-html
	luarocks install --local luacheck
	luarocks install --local mini.doc

# Clean up generated files
clean:
	@echo "Cleaning up..."
	rm -rf luacov.*.out
	rm -rf coverage/
	rm -rf doc/api.md
	rm -rf doc/screw_api.txt
	rm -rf doc/screw_types.txt

# Generate user documentation from README.md
docs:
	@echo "Generating user documentation..."
	@if command -v panvimdoc >/dev/null 2>&1; then \
		panvimdoc \
			--project-name screw.nvim \
			--input-file README.md \
			--vim-version "0.9.0" \
			--toc true \
			--description "Security code review plugin for Neovim" \
			--title "screw.nvim" \
			--treesitter true; \
	else \
		echo "panvimdoc not installed. Install with: luarocks install panvimdoc"; \
	fi

# Generate API documentation from source code
api-documentation:
	@echo "Generating API documentation..."
	nvim -u scripts/make_api_documentation/minimal_init.lua -l scripts/make_api_documentation/main.lua

# Generate vim help tags
vimtags:
	@echo "Generating vim help tags..."
	@if command -v nvim >/dev/null 2>&1; then \
		nvim --headless -c 'helptags doc' -c 'quit'; \
	else \
		echo "Neovim not available for tag generation"; \
	fi

# Generate all documentation (user docs + API docs + tags)
docs-all: docs api-documentation vimtags

# Check all (lint + test + format-check)
check: lint test format-check

# Help
help:
	@echo "Available targets:"
	@echo "  all              - Run lint and test (default)"
	@echo "  test             - Run tests"
	@echo "  coverage         - Run tests with coverage report"
	@echo "  lint             - Run luacheck linter"
	@echo "  format           - Format code with stylua"
	@echo "  format-check     - Check code formatting"
	@echo "  install          - Install development dependencies"
	@echo "  clean            - Clean up generated files"
	@echo "  docs             - Generate user documentation from README.md"
	@echo "  api-documentation - Generate API documentation from source code"
	@echo "  vimtags          - Generate vim help tags"
	@echo "  docs-all         - Generate all documentation (user + API + tags)"
	@echo "  check            - Run all checks (lint + test + format-check)"
	@echo "  help             - Show this help message"