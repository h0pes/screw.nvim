# Contributing to screw.nvim

Thank you for your interest in contributing to screw.nvim! This plugin helps security analysts perform source code reviews from a security perspective, and we welcome contributions that improve this mission.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [Development Workflow](#development-workflow)
- [Code Standards](#code-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Submitting Changes](#submitting-changes)
- [Release Process](#release-process)

## Getting Started

### Prerequisites

- Neovim >= 0.9.0
- Git
- Basic understanding of Lua and Neovim plugin development
- Familiarity with security code review concepts is helpful but not required

### Development Dependencies

The following tools are required for development:

```bash
# Install LuaRocks dependencies
luarocks install busted
luarocks install luacov
luarocks install luacheck

# Install formatting tools
cargo install stylua

# Optional: Install panvimdoc for documentation generation
npm install -g panvimdoc
```

## Development Environment

### Setting up Your Environment

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/screw.nvim.git
   cd screw.nvim
   ```

3. Add the upstream remote:
   ```bash
   git remote add upstream https://github.com/h0pes/screw.nvim.git
   ```

4. Ensure your LuaRocks bin directory is in your PATH:
   ```bash
   export PATH="/home/marco/.luarocks/bin:$PATH"
   ```

### Using the Makefile

All development tasks are standardized through the Makefile. See the available commands:

```bash
# Run tests
make test

# Check code quality
make lint

# Format code
make format

# Check formatting
make format-check

# Generate documentation
make docs

# Generate API documentation
make api-documentation

# Generate all documentation
make docs-all

# Run all checks (test + lint + format-check)
make check

# Clean generated files
make clean
```

## Development Workflow

### Daily Development Process

1. **Start development:**
   ```bash
   git checkout main
   git pull upstream main
   git checkout -b feature/your-feature-name
   ```

2. **During development:**
   ```bash
   # Test frequently
   make test
   
   # Check code quality
   make lint
   ```

3. **Before committing:**
   ```bash
   # Run all checks
   make check
   
   # Format code
   make format
   ```

### Branch Naming

Use descriptive branch names with prefixes:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Test improvements

## Code Standards

### Lua Style Guide

- Use 2-space indentation
- Follow standard Lua naming conventions
- Keep functions focused and small
- Use meaningful variable and function names

### Type Safety

- Use [LuaCATS annotations](https://luals.github.io/wiki/annotations/) for all public functions
- Define types in `lua/screw/types.lua` when appropriate
- Leverage type checking to catch errors early

### Plugin Best Practices

Following [Neovim Plugin Best Practices](https://github.com/nvim-neorocks/nvim-best-practices):

1. **No Default Keymaps** - Users must explicitly configure all keymaps
2. **Scoped Commands** - Use subcommands under `:Screw` instead of multiple commands
3. **Lazy Loading** - Load modules only when needed
4. **User Commands** - Implement proper command completions

### Error Handling

- Always handle potential errors gracefully
- Provide helpful error messages to users
- Use `vim.notify()` for user-facing notifications
- Log detailed errors for debugging

### Performance

- Plugin should load in < 5ms
- All operations should complete in < 100ms
- Minimize memory footprint
- Use efficient algorithms for note management

## Testing

### Writing Tests

- Place tests in the `spec/` directory
- Mirror the source code structure in tests
- Use descriptive test names that explain what is being tested
- Test both success and error cases
- Mock external dependencies when appropriate

### Test Structure

```lua
describe("module_name", function()
  before_each(function()
    -- Setup for each test
  end)

  after_each(function()
    -- Cleanup after each test
  end)

  it("should do something specific", function()
    -- Test implementation
    assert.are.equal(expected, actual)
  end)
end)
```

### Running Tests

```bash
# Run all tests
make test

# Run tests with coverage
make coverage

# View coverage report
luacov && cat luacov.report.out
```

### Test Coverage

- Aim for >90% test coverage
- Focus on edge cases and error conditions
- Test public API thoroughly
- Integration tests for complete workflows

## Documentation

### User Documentation

- Update README.md for user-facing changes
- Use clear, practical examples
- Include configuration options
- Update `doc/news.txt` for new features or breaking changes

### API Documentation

- Use LuaCATS annotations for all public functions
- Generate API docs with `make api-documentation`
- Keep annotations up-to-date with code changes

### Vim Help Documentation

- Generated automatically from README.md using panvimdoc
- Available via `:help screw.nvim` after installation
- Updated automatically by CI

## Submitting Changes

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) format:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Types:
- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `style:` - Formatting changes
- `refactor:` - Code refactoring
- `test:` - Adding or fixing tests
- `chore:` - Maintenance tasks

Examples:
```bash
feat: add CWE classification support
fix: resolve note deletion race condition
docs: update configuration examples
test: add coverage for export functionality
```

### Pull Request Process

1. **Create Pull Request:**
   - Use GitHub UI to create PR from your fork
   - Fill out the PR template completely
   - Ensure all CI checks pass

2. **PR Requirements:**
   - [ ] All tests pass
   - [ ] Code is properly formatted
   - [ ] Documentation is updated
   - [ ] News.txt updated for user-facing changes
   - [ ] Type annotations added for new functions

3. **Review Process:**
   - Address reviewer feedback promptly
   - Update PR as needed
   - Maintain discussion professional and constructive

4. **Merge:**
   - PRs are squashed and merged to main
   - Delete feature branch after merge

### News Updates

For PRs with new features or breaking changes, update `doc/news.txt`:

```
==============================================================================
CHANGELOG                                                    *screw-changelog*

0.2.0 (unreleased)~
NEW FEATURES:
- Added CWE classification support for security notes
- Export functionality now supports CSV format

BUG FIXES:
- Fixed race condition in note deletion
- Resolved memory leak in collaboration mode
```

## Release Process

Releases are automated through GitHub Actions:

1. **Prepare Release:**
   ```bash
   # Ensure main is up-to-date
   git checkout main
   git pull upstream main
   ```

2. **Create Release:**
   ```bash
   # Tag with semantic version
   git tag v1.0.0
   git push upstream v1.0.0
   ```

3. **Automated Process:**
   - GitHub Actions creates release
   - Generates changelog from commits
   - Updates documentation
   - Notifies relevant channels

## Getting Help

### Resources

- [Neovim Lua Guide](https://neovim.io/doc/user/lua.html)
- [Neovim API Documentation](https://neovim.io/doc/user/api.html)
- [LuaCATS Annotations](https://luals.github.io/wiki/annotations/)
- [Plugin Best Practices](https://github.com/nvim-neorocks/nvim-best-practices)

### Communication

- **Issues:** Report bugs or request features via GitHub Issues
- **Discussions:** Use GitHub Discussions for general questions
- **Security:** Email security issues privately to maintainers

### Issue Templates

When reporting bugs or requesting features, use the provided templates:
- Bug reports should include reproduction steps and environment details
- Feature requests should explain the use case and proposed solution

## Security Considerations

Since screw.nvim is designed for security code review:

### Input Validation
- Sanitize all user inputs
- Validate CWE identifiers against known lists
- Prevent injection in export formats
- Handle malformed SAST tool outputs gracefully

### Data Privacy
- No telemetry or data collection
- Local storage by default
- Secure database connections for collaboration
- Configurable data retention policies

### Security Reviews
- Security-related changes require additional review
- Consider attack vectors in new features
- Test with malicious inputs when appropriate

## Code of Conduct

This project follows our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before contributing.

## License

By contributing to screw.nvim, you agree that your contributions will be licensed under the same license as the project.

Thank you for contributing to screw.nvim! 🔒✨