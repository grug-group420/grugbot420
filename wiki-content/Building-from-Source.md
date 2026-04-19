# Building from Source

## Prerequisites

- [Julia 1.9+](https://julialang.org/downloads/)
- [Git](https://git-scm.com/)

## Clone and Setup

```bash
git clone https://github.com/grug-group420/grugbot420.git
cd grugbot420
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Run

```bash
julia --project=. src/Main.jl
```

## Run Tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Or run individual test files:

```bash
julia --project=. test/runtests.jl
julia --project=. test/test_brainstem.jl
julia --project=. test/test_immune.jl
```

## Project Structure

```
grugbot420/
├── src/
│   ├── Main.jl                  # Entry point, CLI loop
│   ├── GrugBot420.jl            # Module definition
│   ├── engine.jl                # Core node engine, scanning, voting
│   ├── patternscanner.jl        # Signal-level pattern matching
│   ├── stochastichelper.jl      # @coinflip macro, bias() helper
│   ├── Lobe.jl                  # Domain partitions
│   ├── LobeTable.jl             # Per-lobe hash tables
│   ├── BrainStem.jl             # Winner-take-all dispatch
│   ├── Thesaurus.jl             # Similarity engine
│   ├── InputQueue.jl            # FIFO queue + NegativeThesaurus
│   ├── ChatterMode.jl           # Idle gossip system
│   ├── PhagyMode.jl             # Maintenance automata
│   ├── EyeSystem.jl             # Visual attention
│   ├── ImageSDF.jl              # GPU SDF conversion
│   ├── SemanticVerbs.jl         # Verb registry
│   ├── ActionTonePredictor.jl   # Pre-vote classifier
│   └── ImmuneSystem.jl          # Specimen immune system
├── test/                        # Test suite
├── docs/                        # Documentation site
├── grug-binary/                 # Prebuilt binary
├── Project.toml                 # Julia package manifest
├── bindboss.toml                # Bindboss packing config
└── README.md
```

## Building with Bindboss

grugbot420 uses [Bindboss](https://github.com/grug-group420/Bindboss) for packaging:

```bash
bindboss pack . grugbot420 --run="julia --project=. src/Main.jl" --needs="julia,julia --version,https://julialang.org/downloads/"
```

## GPU Support

For image SDF features, install GPU backend packages:

```julia
# NVIDIA
using Pkg; Pkg.add("CUDA")

# AMD
using Pkg; Pkg.add("AMDGPU")

# Apple Silicon
using Pkg; Pkg.add("Metal")
```

CPU fallback works without any GPU packages.

## Deploy on Debian

See [Debian_Deploy.md](https://github.com/grug-group420/grugbot420/blob/main/Debian_Deploy.md) for production deployment guide.
