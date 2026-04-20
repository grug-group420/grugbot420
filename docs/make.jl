using Documenter
# GRUG: GrugBot420 uses __precompile__(false) and dynamic submodule includes,
# so Documenter cannot auto-extract @doc docstrings via the module reference.
# Documentation is maintained manually in docs/src/*.md files.
# modules = Module[] is intentional — do not change to [GrugBot420].

makedocs(
    sitename = "GrugBot420.jl",
    modules  = Module[],
    authors  = "marshalldavidson61-arch",
    format   = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical  = "https://marshalldavidson61-arch.github.io/grugbot420",
    ),
    pages = [
        "Home"          => "index.md",
        "Architecture"  => "architecture.md",
        "CLI Reference" => "cli.md",
        "API Reference" => "api.md",
    ],
)

deploydocs(
    repo = "github.com/grug-group420/grugbot420.git",
    devbranch = "main",
)
