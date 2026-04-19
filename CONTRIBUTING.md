# Contributing to grugbot420

Thanks for your interest in contributing! 🪨

## Getting Started

1. **Fork** the repository
2. **Clone** your fork: `git clone https://github.com/YOUR_USERNAME/grugbot420.git`
3. **Install** Julia 1.9+: [julialang.org/downloads](https://julialang.org/downloads/)
4. **Setup**: `julia --project=. -e 'using Pkg; Pkg.instantiate()'`
5. **Branch**: `git checkout -b my-feature`
6. **Test**: `julia --project=. -e 'using Pkg; Pkg.test()'`
7. **Push** and open a pull request

## What to Contribute

### Documentation
- Improve wiki pages or README sections
- Add usage examples
- Clarify existing docs

### Code
- New action types for action packets
- Pattern scanner optimizations
- Additional PhagyMode maintenance actions
- Thesaurus seed dictionary expansions
- Test coverage improvements

### Specimens
Share interesting trained specimens! Save with `/saveSpecimen` and include the `.specimen.gz` file.

## Code Style

- Follow existing Julia conventions
- Use `@coinflip` for stochastic branching
- One responsibility per function
- No silent failures — log or error explicitly
- Add comments for non-obvious logic

## Pull Requests

- One feature or fix per PR
- Include tests for new functionality
- Update docs if behavior changes
- Describe what and why in the PR description

## Running Tests

```bash
# Full suite
julia --project=. -e 'using Pkg; Pkg.test()'

# Individual test files
julia --project=. test/test_brainstem.jl
julia --project=. test/test_immune.jl
julia --project=. test/test_input_queue.jl
```

## Reporting Issues

Please include:
- What you expected vs what happened
- Steps to reproduce
- Julia version (`julia --version`)
- OS and version

## Community

- **Founder:** [@marshalldavidson61-arch](https://github.com/marshalldavidson61-arch)
- **Organization:** [grug-group420](https://github.com/grug-group420)

---

*grug say: "ship code, not complexity" 🪨*
