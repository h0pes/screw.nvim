# 🤖 Automation Features Guide

This document provides a comprehensive overview of all automation features implemented in screw.nvim, their configuration, usage, and workflows.

## Table of Contents

1. [Local Development Tools](#1-local-development-tools)
2. [GitHub Actions CI/CD](#2-github-actions-cicd)
3. [Automated Release System](#3-automated-release-system)
4. [Documentation Generation](#4-documentation-generation)
5. [News Update Validation](#5-news-update-validation)
6. [Issue & PR Templates](#6-issue--pr-templates)
7. [Dependency Management](#7-dependency-management)
8. [Complete Development Workflow](#8-complete-development-workflow)

---

## 1. Local Development Tools

**Configuration File:** [`Makefile`](./Makefile)

### Purpose
Provides standardized commands for local development, testing, and code quality checks.

### Available Commands

#### Testing
```bash
PATH="/home/marco/.luarocks/bin:$PATH" make test
```
- **What it does:** Runs the complete test suite using `busted`
- **Expected output:** Test results with success/failure counts and timing
- **Use when:** Before committing changes, during development

#### Test Coverage
```bash
PATH="/home/marco/.luarocks/bin:$PATH" make coverage
```
- **What it does:** Runs tests with coverage reporting using `luacov`
- **Expected output:** Coverage percentage and detailed line-by-line coverage report
- **Use when:** Analyzing test completeness, before releases

#### Code Quality
```bash
PATH="/home/marco/.luarocks/bin:$PATH" make lint
```
- **What it does:** Runs `luacheck` to identify code quality issues
- **Expected output:** List of warnings/errors with file locations
- **Use when:** Before committing, to maintain code standards

#### Code Formatting
```bash
PATH="/home/marco/.luarocks/bin:$PATH" make format
```
- **What it does:** Formats code using `stylua` with consistent style
- **Expected output:** Reformatted files (or no output if already formatted)
- **Use when:** Before committing, to maintain consistent style

#### Format Check
```bash
PATH="/home/marco/.luarocks/bin:$PATH" make format-check
```
- **What it does:** Checks if code formatting matches style guidelines
- **Expected output:** List of files that need formatting (or success message)
- **Use when:** In CI, to verify formatting compliance

#### Documentation Generation
```bash
PATH="/home/marco/.luarocks/bin:$PATH" make docs
```
- **What it does:** Generates vim help documentation from README.md using panvimdoc
- **Expected output:** Updated `doc/screw.nvim.txt` file
- **Use when:** After updating README.md or adding new features

#### API Documentation Generation
```bash
PATH="/home/marco/.luarocks/bin:$PATH" make api-documentation
```
- **What it does:** Generates API documentation from LuaCATS annotations using mini.doc
- **Expected output:** Updated `doc/screw_api.txt` and `doc/screw_types.txt` files
- **Use when:** After updating function signatures, types, or adding new API functions

#### Vim Help Tags Generation
```bash
PATH="/home/marco/.luarocks/bin:$PATH" make vimtags
```
- **What it does:** Generates vim help tags for improved help system navigation
- **Expected output:** Updated `doc/tags` file
- **Use when:** After generating new documentation files

#### Complete Documentation Generation
```bash
PATH="/home/marco/.luarocks/bin:$PATH" make docs-all
```
- **What it does:** Generates all documentation (user docs + API docs + vim tags)
- **Expected output:** All documentation files updated
- **Use when:** Before releases or comprehensive documentation updates

#### All Checks
```bash
PATH="/home/marco/.luarocks/bin:$PATH" make check
```
- **What it does:** Runs all quality checks (test, lint, format-check)
- **Expected output:** Combined results of all checks
- **Use when:** Before submitting PRs, comprehensive validation

#### Cleanup
```bash
PATH="/home/marco/.luarocks/bin:$PATH" make clean
```
- **What it does:** Removes generated files (coverage reports, logs)
- **Expected output:** Clean workspace
- **Use when:** Starting fresh, before releases

### Workflow
1. **Development:** Run `make test` frequently during coding
2. **Pre-commit:** Run `make check` to ensure all quality gates pass
3. **Documentation updates:** 
   - Run `make docs` after README changes
   - Run `make api-documentation` after API changes
   - Run `make docs-all` for comprehensive documentation updates
4. **Coverage analysis:** Run `make coverage` periodically

---

## 2. GitHub Actions CI/CD

**Configuration File:** [`.github/workflows/ci.yml`](./.github/workflows/ci.yml)

### Purpose
Automated continuous integration that runs on every push and pull request to ensure code quality and compatibility.

### What it does
- **Multi-version testing:** Tests on Neovim stable and nightly versions
- **Code quality checks:** Runs luacheck for static analysis
- **Style enforcement:** Validates code formatting with stylua
- **Coverage reporting:** Uploads coverage data to Codecov

### Triggers
- Push to any branch
- Pull request creation/updates
- Manual workflow dispatch

### Expected Output
- ✅ **Success:** All checks pass, green checkmarks on GitHub
- ❌ **Failure:** Detailed logs showing which step failed and why

### Workflow Steps
1. **Environment Setup**
   - Installs Neovim (stable/nightly)
   - Sets up LuaRocks
   - Installs dependencies (luacheck, stylua, busted, luacov)

2. **Code Quality**
   - Runs `luacheck` with project-specific configuration
   - Validates formatting with `stylua --check`

3. **Testing**
   - Executes test suite with `busted`
   - Generates coverage reports with `luacov`

4. **Reporting**
   - Uploads coverage to Codecov
   - Provides detailed failure logs

### Usage
- **Automatic:** Runs on every push/PR
- **Manual:** Can be triggered from GitHub Actions tab
- **Status:** Check status in PR or commit status checks

---

## 3. Automated Release System

**Configuration File:** [`.github/workflows/release.yml`](./.github/workflows/release.yml)

### Purpose
Automates the entire release process when version tags are pushed, including changelog generation and asset creation.

### What it does
- **Changelog generation:** Creates detailed changelogs from git history
- **Release creation:** Creates GitHub releases with proper formatting
- **Asset management:** Packages and uploads release artifacts
- **Notification:** Provides release notes and links

### Triggers
```bash
git tag v1.0.0
git push origin v1.0.0
```

### Expected Output
- New GitHub release at `https://github.com/h0pes/screw.nvim/releases`
- Automatically generated changelog
- Release assets (if configured)
- Release notifications

### Workflow Steps
1. **Tag Detection**
   - Validates semantic version format (v1.0.0, v1.2.3-beta.1)
   - Extracts version information

2. **Changelog Generation**
   - Analyzes git commits since last release
   - Groups commits by type (feat, fix, docs, etc.)
   - Formats into readable changelog

3. **Release Creation**
   - Creates GitHub release with version tag
   - Includes generated changelog
   - Marks as published

4. **Asset Upload** (if configured)
   - Packages plugin files
   - Uploads to release

### Usage Workflow
1. **Prepare release:**
   ```bash
   # Ensure all changes are committed and pushed
   git status
   git push origin main
   ```

2. **Create and push tag:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. **Monitor:** Check GitHub Actions tab for release workflow progress

4. **Verify:** Check releases page for new release

---

## 4. Documentation Generation

**Configuration File:** [`.github/workflows/docs.yml`](./.github/workflows/docs.yml)

### Purpose
Automatically generates and maintains plugin documentation from source code and README.

### What it does
- **Vim help docs:** Converts README.md to vim help format using panvimdoc
- **API documentation:** Generates API docs from source code using mini.doc
- **Vim help tags:** Generates help tags for improved navigation
- **Auto-commit:** Commits documentation updates back to repository

### Triggers
- Push to main branch
- Manual workflow dispatch

### Expected Output
- Updated `doc/screw.nvim.txt` (vim help documentation)
- Updated `doc/screw_api.txt` (API reference)
- Updated `doc/screw_types.txt` (type definitions)
- Updated `doc/tags` (vim help tags)
- Automatic commits with documentation updates

### Workflow Steps
1. **Environment Setup**
   - Installs documentation tools (panvimdoc, mini.doc)
   - Sets up Neovim environment

2. **Vim Help Generation**
   ```bash
   panvimdoc \
     --project-name screw.nvim \
     --input-file README.md \
     --vim-version "0.9.0" \
     --toc true \
     --description "Security code review plugin for Neovim" \
     --title "screw.nvim" \
     --treesitter true
   ```

3. **API Documentation**
   - Uses `make api-documentation` to run mini.doc generation
   - Scans `lua/screw/init.lua`, `lua/screw/types.lua`, and `lua/screw/config/meta.lua`
   - Generates `doc/screw_api.txt` and `doc/screw_types.txt`
   - Creates cross-references and links

4. **Vim Help Tags Generation**
   - Runs `nvim --headless -c 'helptags doc' -c 'quit'`
   - Updates `doc/tags` file for improved help navigation

5. **Auto-commit**
   - Commits all generated documentation
   - Pushes back to main branch

### Usage
- **Automatic:** Runs on main branch pushes
- **Manual:** Trigger from GitHub Actions tab
- **Local:** Use `make docs` for user docs, `make api-documentation` for API docs, or `make docs-all` for everything

### User Access
After generation, users can access documentation via:
```vim
:help screw.nvim        " User documentation
:help screw_api         " API reference  
:help screw_types       " Type definitions
```

---

## 5. News Update Validation

**Configuration File:** [`.github/workflows/news.yml`](./.github/workflows/news.yml)

### Purpose
Ensures that pull requests with new features or breaking changes include appropriate updates to `doc/news.txt`, maintaining a comprehensive changelog for users.

### What it does
- **Feature detection:** Identifies commits with `feat:` prefix or feature indicators
- **Breaking change detection:** Identifies commits with `!` markers indicating breaking changes
- **News.txt validation:** Checks if `doc/news.txt` was updated in the PR
- **PR blocking:** Prevents merging PRs that introduce changes without documentation

### Triggers
- Pull request creation/updates
- PR ready for review (not draft PRs)

### Expected Output
- ✅ **Pass:** PR includes news.txt updates for new features/breaking changes, or contains only minor changes
- ❌ **Fail:** PR introduces significant changes but doesn't update news.txt

### Workflow Logic
1. **Commit Analysis**
   - Scans all commits in the PR
   - Identifies feature commits (feat:, feat(), feat prefix)
   - Identifies breaking changes (! marker in commit messages)

2. **News.txt Check**
   - Verifies if `doc/news.txt` was modified in the PR
   - Compares required updates vs. actual changes

3. **Validation Result**
   - Passes if no significant changes or news.txt updated appropriately
   - Fails with helpful message explaining what needs to be updated

### Usage
- **Automatic:** Runs on every non-draft PR
- **Bypass:** Add `[skip news]` to commit message for minor changes
- **Fix:** Update `doc/news.txt` with new features or breaking changes

---

## 6. Issue & PR Templates

**Configuration Files:**
- [`.github/ISSUE_TEMPLATE/bug_report.yml`](./.github/ISSUE_TEMPLATE/bug_report.yml)
- [`.github/ISSUE_TEMPLATE/feature_request.yml`](./.github/ISSUE_TEMPLATE/feature_request.yml)
- [`.github/pull_request_template.md`](./.github/pull_request_template.md)

### Purpose
Standardizes issue reporting and pull request submissions to improve quality and maintainability.

### Bug Report Template
**What it does:**
- Collects environment information (Neovim version, OS)
- Ensures documentation has been read
- Gathers reproduction steps
- Requests expected vs actual behavior

**Workflow:**
1. User clicks "New Issue" → "Bug Report"
2. Template guides through required information
3. Automated labels applied (bug)
4. Maintainers receive structured, actionable reports

### Feature Request Template
**What it does:**
- Captures feature description and motivation
- Evaluates use cases and alternatives
- Assesses implementation complexity

**Workflow:**
1. User selects "Feature Request" template
2. Provides structured feature proposal
3. Automatic labeling (enhancement)
4. Community discussion on merit and implementation

### Pull Request Template
**What it does:**
- Ensures code quality checklist completion
- Requires test coverage
- Validates documentation updates
- Links to related issues

**Workflow:**
1. Developer creates PR
2. Template auto-loads with checklist
3. Required checks must pass before merge
4. Maintainer review with standardized criteria

### Expected Output
- **Higher quality reports:** Structured, actionable issues
- **Faster resolution:** All necessary information collected upfront
- **Consistent PRs:** Standardized review process

---

## 7. Dependency Management

**Configuration File:** [`.github/dependabot.yml`](./.github/dependabot.yml)

### Purpose
Automates dependency updates to maintain security and compatibility.

### What it does
- **GitHub Actions updates:** Keeps workflow actions current
- **Security patches:** Automatically applies security updates
- **Version management:** Manages update frequency and scope

### Configuration
```yaml
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
```

### Expected Output
- Weekly PRs for GitHub Actions updates
- Security alerts for vulnerable dependencies
- Automated version bump PRs

### Workflow
1. **Weekly scan:** Dependabot checks for updates
2. **PR creation:** Creates PRs for available updates
3. **CI validation:** Automated tests run on update PRs
4. **Manual review:** Maintainer reviews and merges
5. **Auto-merge:** Low-risk updates can be auto-merged (if configured)

---

## 8. Complete Development Workflow

### Daily Development
1. **Start work:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/my-feature
   ```

2. **During development:**
   ```bash
   # Test frequently
   PATH="/home/marco/.luarocks/bin:$PATH" make test
   
   # Check code quality
   PATH="/home/marco/.luarocks/bin:$PATH" make lint
   ```

3. **Before committing:**
   ```bash
   # Run all checks
   PATH="/home/marco/.luarocks/bin:$PATH" make check
   
   # Format code
   PATH="/home/marco/.luarocks/bin:$PATH" make format
   ```

4. **Commit and push:**
   ```bash
   git add .
   git commit -m "feat: add new security annotation feature"
   git push origin feature/my-feature
   ```

### Pull Request Process
1. **Create PR:** Use GitHub UI, template auto-loads
2. **CI validation:** Wait for all checks to pass
3. **Review:** Address feedback, update as needed
4. **Merge:** Squash and merge to main

### Release Process
1. **Prepare main:**
   ```bash
   git checkout main
   git pull origin main
   ```

2. **Create release:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. **Monitor:** Check GitHub Actions for release workflow
4. **Verify:** Confirm release appears on GitHub

### Monitoring & Maintenance
- **Weekly:** Review Dependabot PRs
- **Monthly:** Check coverage reports
- **Per release:** Verify documentation updates
- **Ongoing:** Monitor CI health and performance

---

## 🔧 Troubleshooting

### Common Issues

**Tests failing locally but not in CI:**
- Check LuaRocks path: `PATH="/home/marco/.luarocks/bin:$PATH"`
- Verify dependencies: `luarocks list`

**Formatting issues:**
- Install stylua: `cargo install stylua`
- Run format: `make format`

**Documentation not generating:**
- Check panvimdoc installation in workflow
- Verify README.md formatting

**Release workflow failing:**
- Ensure tag follows semantic versioning
- Check repository permissions

### Getting Help
- Check workflow logs in GitHub Actions tab
- Review make command output for local issues
- Consult this automation guide for workflow understanding

---

*This automation setup ensures high code quality, streamlined releases, and maintainable documentation for screw.nvim.*