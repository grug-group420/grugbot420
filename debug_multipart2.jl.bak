include("src/Main.jl")

const SPEC_PATH = joinpath(@__DIR__, "grug_comprehensive_v740.specimen")
load_specimen_from_file!(SPEC_PATH)
ENV["GRUG_CHATTER_ENABLED"] = "false"

# Hook into output
read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

function ask_grug(text::String)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]=""; end
    try; process_mission(text); catch e; @warn "err: $e"; end
    r = read_last()
    ti = findfirst("--- DEBUG TELEMETRY", r)
    if ti !== nothing; r = r[1:first(ti)-1]; end
    return strip(replace(r, r"\n{3,}" => "\n\n"))
end

# Test multipart with verbose output
inp = "what is fire and what is water"
println("\n========================================")
println("TESTING: $inp")
println("========================================")
result = ask_grug(inp)
println("RESULT:\n$result")
