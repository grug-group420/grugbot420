# Contributing

Thanks for your interest in contributing to grugbot420!

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/grugbot420.git`
3. Create a branch: `git checkout -b my-feature`
4. Make your changes
5. Run tests: `julia --project=. -e 'using Pkg; Pkg.test()'`
6. Push and open a pull request

## What to Contribute

### Good First Issues
- Improve documentation and wiki pages
- Add test coverage for existing modules
- Fix typos or clarify README sections

### Feature Contributions
- New action types for action packets
- Additional scan tier optimizations
- New PhagyMode maintenance actions
- Thesaurus seed dictionary expansions
- Specimen analysis/visualization tools

### Specimen Contributions
Share interesting trained specimens! Save with `/saveSpecimen` and share the `.specimen.gz` file.

## Code Style

- Follow existing Julia conventions in the codebase
- Use the `@coinflip` macro for stochastic branching
- Keep functions focused — one responsibility per function
- Add comments for non-obvious logic
- No silent failures — log or error explicitly

## Pull Request Guidelines

- Keep PRs focused — one feature or fix per PR
- Include tests for new functionality
- Update documentation if you change behavior
- Describe what and why in the PR description

## Reporting Issues

Open an issue with:
- What you expected
- What happened instead
- Steps to reproduce
- Julia version and OS

## Community

- **Organization:** [grug-group420](https://github.com/grug-group420)
- **Founder:** [@marshalldavidson61-arch](https://github.com/marshalldavidson61-arch)

---

*grug say: "ship code, not complexity" 🪨*
