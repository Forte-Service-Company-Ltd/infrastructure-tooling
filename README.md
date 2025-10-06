# infrastructure-tooling

Common Build, Test, and Analysis Github Actions

This repository provides a comprehensive suite of reusable GitHub Actions and workflows for building, testing, and analyzing on-chain (smart contract) or web-service projects. It serves as a centralized tooling solution that can be shared across multiple blockchain development repositories.

## 🚀 Overview

The infrastructure-tooling repository contains standardized CI/CD components specifically designed for Ethereum/EVM-based smart contract development workflows. It includes actions for building contracts, running tests, security analysis, code coverage reporting, and quality assurance checks. Additionally composite actions provide shared actions used by web-service projects, such as building yarn/npm projects or running tests.

## 📁 Repository Structure

### GitHub Actions (`.github/actions/`)

#### Build & Test Actions

- **`install-foundry/`** - Installs and configures the Foundry toolchain (default: v1.2.1)
- **`install-dependencies/`** - Handles dependency installation for Python and Soldeer packages
- **`onchain-build/`** - Compiles smart contracts using Forge with optimization
- **`onchain-test/`** - Runs comprehensive test suites with support for mainnet forking
- **`typescript-build/`** - Builds TypeScript projects with support for multiple workspaces and components
- **`typescript-test/`** - Runs TypeScript test suites with configurable script commands and arguments

#### Code Quality & Analysis Actions

- **`code-coverage/`** - Generates LCOV coverage reports and posts results to pull requests
- **`slither-analysis/`** - Performs static security analysis using Slither with SARIF output
- **`medusa-fuzz/`** - Executes property-based fuzzing tests using Medusa fuzzer
- **`contract-size/`** - Validates contract bytecode size against Ethereum's 24KB limit

#### Documentation & Validation Actions

- **`markdown-link-checker/`** - Validates links in markdown files (README, CHANGELOG, etc.)
- **`formatter-check/`** - Checks formatting using language-appropriate tooling (prettier, black, gofmt), posting a comment on PRs when not passing.

### Workflows (`.github/workflows/`)

#### `onchain-build-test-report.yaml`

A comprehensive callable workflow that orchestrates the complete build and test pipeline:

**Features:**

- Markdown link validation
- Foundry installation and dependency management
- Contract size validation
- Smart contract compilation with optimization
- Test execution with mainnet/polygon forking support
- Code coverage analysis with PR reporting
- Configurable test parameters (salt strings, fork testing, etc.)

**Inputs:**

- GitHub App authentication support
- Multi-repository project support
- Customizable markdown file paths
- Fork testing configuration
- Environment-specific test settings

#### `onchain-code-quality.yaml`

Focused workflow for code quality and security analysis:

**Features:**

- Static security analysis with Slither
- Conditional fuzzing with Medusa (when `medusa.json` exists)
- SARIF report generation for security findings
- Automated PR comments with analysis results

### Utility Scripts (`.github/scripts/`)

#### `check-format.sh`

Runs format-checking using language specific tools:

- Checks only the files passed (files modified in a PR).
- Can be requested to use `prettier`, `black`, or `gofmt`.
- Returns a list of files failing the formatter checks.
- Prints an annotation showing in GitHub Actions summary.

#### `check-links.sh`

Bash script for markdown link validation:

- Installs and runs `markdown-link-check`
- Supports custom configuration files
- Handles comma-separated file lists
- Excludes common directories (node_modules, lib)

#### `contract-size.sh`

Contract size validation script:

- Parses Forge build output for contract sizes
- Warns for contracts >21KB (approaching limit)
- Fails for contracts >24KB (exceeds Ethereum limit)
- Color-coded terminal output for easy identification

## 🔧 Usage

### As a Callable Workflow

Add to your repository's `.github/workflows/` directory:

```yaml
name: Composite Code Quality

on:
  pull_request:
    types: [opened, synchronize, reopened, edited, ready_for_review]

permissions:
  contents: read
  pull-requests: write

jobs:
  code-quality:
    uses: Forte-Service-Company-Ltd/infrastructure-tooling/.github/workflows/onchain-code-quality.yaml@v0.0.2
    secrets: inherit
```

### As Individual Actions

Reference specific actions in your workflows:

```yaml
steps:
  - uses: Forte-Service-Company-Ltd/infrastructure-tooling/.github/actions/install-foundry@main
  - uses: Forte-Service-Company-Ltd/infrastructure-tooling/.github/actions/onchain-build@main

  # For TypeScript projects
  - uses: Forte-Service-Company-Ltd/infrastructure-tooling/.github/actions/typescript-build@main
    with: # All parameters are optional
      components: "server,client"
      node-version: "20.x"
      package-manager: "yarn" # or npm

  - uses: Forte-Service-Company-Ltd/infrastructure-tooling/.github/actions/typescript-test@main
```

## 🛠 Supported Technologies

- **Foundry** - Smart contract development framework
- **Slither** - Static analysis security tool
- **Medusa** - Property-based fuzzing framework
- **LCOV** - Code coverage reporting
- **Python/Pip** - For analysis tool dependencies
- **Node.js** - For markdown link checking and TypeScript projects
- **TypeScript** - Type-safe JavaScript development
- **Yarn/NPM** - JavaScript package managers
- **Soldeer** - Solidity package manager

## 📋 Requirements

- Ubuntu Linux runner (GitHub Actions)
- Foundry-compatible smart contract project
- Optional: Alchemy API keys for fork testing
- Optional: `medusa.json` for fuzzing configuration
- Optional: `slither.config.json` for analysis customization

## 🔐 Security Features

- **Static Analysis**: Comprehensive security scanning with Slither
- **Fuzzing**: Property-based testing with Medusa
- **SARIF Reports**: Industry-standard security report format
- **Automated PR Comments**: Security findings reported directly on pull requests

## 📊 Quality Assurance

- **Code Coverage**: Line-by-line test coverage reporting
- **Contract Size Validation**: Ensures contracts fit within Ethereum limits
- **Link Validation**: Prevents broken documentation links
- **Dependency Management**: Automated installation and updates
- **Format Validation**: Ensures code formatting conforms to accepted conventions

## 🤝 Contributing

This tooling is designed to be shared across multiple blockchain development projects. When making changes, ensure backward compatibility and test across different project structures.
