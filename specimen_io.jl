#!/usr/bin/env julia
"""
specimen_io.jl — Cross-Platform Specimen I/O for GrugBot420
════════════════════════════════════════════════════════════════════
Provides cross-platform specimen compression and decompression using Julia,
which works on Windows, Linux, and macOS without external dependencies.

Features:
- Cross-platform gzip compression (GZip.jl built-in)
- Multi-line JSON editing support
- Quick append mode with hotkey-based JSON appending
- Robust error handling with no silent failures
- Consistent comment conventions
- Validation before save
"""

using JSON3
using GZip

# ═════════════════════════════════════════════════════════════════════
# ERROR HANDLING
# ═════════════════════════════════════════════════════════════════════

"""
Custom error type for specimen operations
"""
struct SpecimenError <: Exception
    message::String
end

# ═════════════════════════════════════════════════════════════════════
# VALIDATION
# ═════════════════════════════════════════════════════════════════════

"""
Validate specimen structure before saving

# Arguments
- `specimen::Dict`: The specimen dict to validate

# Returns
- `Bool`: true if valid

# Throws
- `SpecimenError`: if validation fails
"""
function validate_specimen(specimen::Dict)
    # Check required top-level fields
    required_fields = ["meta", "nodes", "lobes"]
    for field in required_fields
        if !haskey(specimen, field)
            throw(SpecimenError("Missing required field: $field"))
        end
    end
    
    # Validate meta section
    if !haskey(specimen["meta"], "version")
        throw(SpecimenError("Missing meta.version field"))
    end
    
    # Validate nodes array
    nodes = specimen["nodes"]
    if !isa(nodes, Array) || isempty(nodes)
        throw(SpecimenError("nodes must be a non-empty array"))
    end
    
    # Validate each node has required fields
    for (i, node) in enumerate(nodes)
        if !isa(node, Dict)
            throw(SpecimenError("Node $i must be a dict"))
        end
        
        node_required = ["id", "pattern"]
        for field in node_required
            if !haskey(node, field)
                throw(SpecimenError("Node $i missing required field: $field"))
            end
        end
    end
    
    # Validate lobes
    lobes = specimen["lobes"]
    if !isa(lobes, Dict)
        throw(SpecimenError("lobes must be a dict"))
    end
    
    return true
end

"""
Validate individual JSON object before appending

# Arguments
- `json_obj::Dict`: The JSON object to validate

# Returns
- `Bool`: true if valid

# Throws
- `SpecimenError`: if validation fails
"""
function validate_json_object(json_obj::Dict)
    # Check it's a dict
    if !isa(json_obj, Dict)
        throw(SpecimenError("JSON must be a dict/object"))
    end
    
    # Basic structure check - must have at least some content
    if isempty(json_obj)
        throw(SpecimenError("JSON object cannot be empty"))
    end
    
    return true
end

# ═════════════════════════════════════════════════════════════════════
# COMPRESSION
# ═════════════════════════════════════════════════════════════════════

"""
Save specimen to compressed file (cross-platform)

# Arguments
- `specimen::Dict`: The specimen dict to save
- `filepath::String`: Output file path (with .gz extension)

# Returns
- `String`: Success message with file size info

# Throws
- `SpecimenError`: if validation or saving fails
"""
function save_specimen(specimen::Dict, filepath::String)
    try
        # Validate specimen first
        validate_specimen(specimen)
        
        # Convert to JSON with pretty printing
        json_str = JSON3.write(specimen, indent=2)
        
        # Write compressed file
        GZip.open(filepath, "w") do io
            write(io, json_str)
        end
        
        # Get file sizes
        json_size = length(json_str)
        gz_size = filesize(filepath)
        compression_ratio = json_size / gz_size
        
        return @sprintf(
            "✓ Specimen saved successfully!\n  Raw JSON: %d bytes\n  Compressed: %d bytes\n  Compression ratio: %.1fx",
            json_size, gz_size, compression_ratio
        )
        
    catch e
        if isa(e, SpecimenError)
            rethrow(e)
        else
            throw(SpecimenError("Failed to save specimen: $(e.msg)"))
        end
    end
end

"""
Load specimen from compressed file (cross-platform)

# Arguments
- `filepath::String`: Input file path

# Returns
- `Dict`: The loaded specimen

# Throws
- `SpecimenError`: if file doesn't exist or is invalid
"""
function load_specimen(filepath::String)
    try
        # Check file exists
        if !isfile(filepath)
            throw(SpecimenError("File not found: $filepath"))
        end
        
        # Read and decompress
        json_str = GZip.open(filepath, "r") do io
            read(io, String)
        end
        
        # Parse JSON
        specimen = JSON3.read(json_str, Dict)
        
        # Validate loaded specimen
        validate_specimen(specimen)
        
        return specimen
        
    catch e
        if isa(e, SpecimenError)
            rethrow(e)
        else
            throw(SpecimenError("Failed to load specimen: $(e.msg)"))
        end
    end
end

# ═════════════════════════════════════════════════════════════════════
# MULTI-LINE JSON EDITING
# ═════════════════════════════════════════════════════════════════════

"""
Interactive multi-line JSON editor

Opens a terminal-based editor for editing JSON with proper validation

# Arguments
- `specimen::Dict`: The specimen to edit

# Returns
- `Dict`: The edited specimen

# Throws
- `SpecimenError`: if editing or validation fails
"""
function edit_specimen_interactive(specimen::Dict)
    try
        # Convert to pretty JSON
        json_str = JSON3.write(specimen, indent=2)
        
        # Determine editor to use
        editor = get(ENV, "EDITOR", "")
        editor = isempty(editor) ? (Sys.iswindows() ? "notepad" : "vim") : editor
        
        # Create temp file
        temp_file = tempname() * ".json"
        
        # Write JSON to temp file
        write(temp_file, json_str)
        
        println("📝 Opening editor: $editor")
        println("📝 Editing file: $temp_file")
        println("📝 Press Ctrl+D (Unix) or Ctrl+Z (Windows) to finish editing")
        
        # Launch editor
        try
            run(`$editor $temp_file`)
        catch
            # Editor failed, provide fallback
            println("⚠️  Editor launch failed. Please edit manually: $temp_file")
            println("⚠️  Press Enter when done editing...")
            readline()
        end
        
        # Read edited JSON
        edited_json = read(temp_file, String)
        
        # Validate JSON syntax
        try
            edited_specimen = JSON3.read(edited_json, Dict)
        catch e
            rm(temp_file)
            throw(SpecimenError("Invalid JSON syntax: $(e.msg)"))
        end
        
        # Validate specimen structure
        validate_specimen(edited_specimen)
        
        # Clean up temp file
        rm(temp_file)
        
        println("✓ Edit completed successfully!")
        
        return edited_specimen
        
    catch e
        if isa(e, SpecimenError)
            rethrow(e)
        else
            throw(SpecimenError("Failed to edit specimen: $(e.msg)"))
        end
    end
end

# ═════════════════════════════════════════════════════════════════════
# QUICK APPEND MODE
# ═════════════════════════════════════════════════════════════════════

"""
Quick append mode editor for rapid JSON appending

Opens a dedicated editor where you can paste JSON and use a hotkey to append.

# Arguments
- `target_file::String`: The specimen file to append to

# Returns
- Nothing

# Throws
- `SpecimenError`: if append operation fails
"""
function quick_append_mode(target_file::String)
    try
        # Check target file exists
        if !isfile(target_file)
            throw(SpecimenError("Target file not found: $target_file"))
        end
        
        # Determine editor to use
        editor = get(ENV, "EDITOR", "")
        editor = isempty(editor) ? (Sys.iswindows() ? "notepad" : "vim") : editor
        
        # Create append editor file with instructions
        append_file = tempname() * "_append.txt"
        
        instructions = """
════════════════════════════════════════════════════════════════════
QUICK APPEND MODE - GRUGBOT420 SPECIMEN
════════════════════════════════════════════════════════════════════

TARGET FILE: $target_file

INSTRUCTIONS:
1. Paste your JSON below this line
2. Save and close editor when done
3. System will automatically validate and append

HOTKEYS (in editor):
- Ctrl+S & Ctrl+Q: Save and append (vim: :wq)
- Esc: Cancel and exit without saving

WHAT CAN I APPEND?
- Individual nodes: {"id": "N-XXXX", "pattern": "...", ...}
- Node arrays: [{"id": "N-001", ...}, {"id": "N-002", ...}]
- Lobe definitions: {"mathematics": "Pure mathematics..."}
- Any valid JSON object that fits specimen structure

════════════════════════════════════════════════════════════════════
APPEND YOUR JSON BELOW THIS LINE:
════════════════════════════════════════════════════════════════════


"""
        
        # Write instructions to append file
        write(append_file, instructions)
        
        println("📝 QUICK APPEND MODE")
        println("📝 Target file: $target_file")
        println("📝 Append file: $append_file")
        println("📝 Opening editor: $editor")
        println("📝 Paste your JSON, then save and close to append")
        println("─" * 70)
        
        # Launch editor
        try
            run(`$editor $append_file`)
        catch
            println("⚠️  Editor launch failed. Please edit manually: $append_file")
            println("⚠️  Press Enter when done...")
            readline()
        end
        
        # Read appended content
        append_content = read(append_file, String)
        
        # Find JSON after instructions
        json_start = findfirst("APPEND YOUR JSON BELOW THIS LINE:", append_content)
        if json_start === nothing
            rm(append_file)
            throw(SpecimenError("Could not find JSON section. Did you modify the instructions?"))
        end
        
        json_section = append_content[last(json_start)+length("APPEND YOUR JSON BELOW THIS LINE:"):end]
        
        # Strip whitespace and check if empty
        json_section = strip(json_section)
        if isempty(json_section)
            println("⚠️  No JSON found. Nothing to append.")
            rm(append_file)
            return
        end
        
        # Try to parse JSON
        try
            json_obj = JSON3.read(json_section, Dict)
            validate_json_object(json_obj)
        catch e
            rm(append_file)
            throw(SpecimenError("Invalid JSON: $(e.msg)"))
        end
        
        # Load current specimen
        specimen = load_specimen(target_file)
        
        # Determine what to append based on structure
        appended_count = 0
        if haskey(json_obj, "id") && haskey(json_obj, "pattern")
            # Single node
            push!(specimen["nodes"], json_obj)
            appended_count = 1
            println("✓ Appended 1 node")
        elseif isa(json_obj, Array) && !isempty(json_obj) && haskey(json_obj[1], "id")
            # Array of nodes
            for node in json_obj
                push!(specimen["nodes"], node)
            end
            appended_count = length(json_obj)
            println("✓ Appended $appended_count nodes")
        elseif !isempty(json_obj) && !any(haskey.(Ref(json_obj), ["id", "signal"]))
            # Likely lobes or other metadata
            for (key, value) in json_obj
                specimen[key] = value
            end
            appended_count = length(json_obj)
            println("✓ Appended $appended_count metadata fields")
        else
            rm(append_file)
            throw(SpecimenError("Unrecognized JSON structure. Cannot determine where to append."))
        end
        
        # Save updated specimen
        result = save_specimen(specimen, target_file)
        println(result)
        
        # Clean up temp file
        rm(append_file)
        
        println("✓ Quick append completed successfully!")
        
    catch e
        if isa(e, SpecimenError)
            rethrow(e)
        else
            throw(SpecimenError("Failed to append to specimen: $(e.msg)"))
        end
    end
end

# ═════════════════════════════════════════════════════════════════════
# CLI INTERFACE
# ═════════════════════════════════════════════════════════════════════

"""
Main CLI entry point
"""
function main()
    if length(ARGS) < 1
        println("Usage: julia specimen_io.jl <command> [args]")
        println("")
        println("Commands:")
        println("  save <input.json> <output.gz>   - Save specimen to compressed file")
        println("  load <input.gz> <output.json>   - Load specimen from compressed file")
        println("  edit <specimen.gz>               - Interactive multi-line JSON editing")
        println("  append <specimen.gz>             - Quick append mode with hotkey")
        println("  validate <file>                  - Validate specimen file")
        exit(1)
    end
    
    command = lowercase(ARGS[1])
    
    try
        if command == "save"
            if length(ARGS) != 3
                println("Error: save requires input.json and output.gz")
                exit(1)
            end
            
            input_file = ARGS[2]
            output_file = ARGS[3]
            
            if !isfile(input_file)
                println("Error: Input file not found: $input_file")
                exit(1)
            end
            
            # Load JSON
            json_str = read(input_file, String)
            specimen = JSON3.read(json_str, Dict)
            
            # Save compressed
            result = save_specimen(specimen, output_file)
            println(result)
            
        elseif command == "load"
            if length(ARGS) != 3
                println("Error: load requires input.gz and output.json")
                exit(1)
            end
            
            input_file = ARGS[2]
            output_file = ARGS[3]
            
            # Load compressed
            specimen = load_specimen(input_file)
            
            # Save as JSON
            json_str = JSON3.write(specimen, indent=2)
            write(output_file, json_str)
            
            json_size = length(json_str)
            println("✓ Specimen loaded successfully!")
            println("  Output: $output_file")
            println("  Size: $json_size bytes")
            
        elseif command == "edit"
            if length(ARGS) != 2
                println("Error: edit requires specimen.gz")
                exit(1)
            end
            
            input_file = ARGS[2]
            
            # Load specimen
            specimen = load_specimen(input_file)
            
            # Edit interactively
            edited_specimen = edit_specimen_interactive(specimen)
            
            # Save back
            result = save_specimen(edited_specimen, input_file)
            println(result)
            
        elseif command == "append"
            if length(ARGS) != 2
                println("Error: append requires specimen.gz")
                exit(1)
            end
            
            input_file = ARGS[2]
            
            # Quick append mode
            quick_append_mode(input_file)
            
        elseif command == "validate"
            if length(ARGS) != 2
                println("Error: validate requires a file path")
                exit(1)
            end
            
            filepath = ARGS[2]
            
            # Determine file type
            if endswith(filepath, ".gz")
                specimen = load_specimen(filepath)
            else
                json_str = read(filepath, String)
                specimen = JSON3.read(json_str, Dict)
            end
            
            validate_specimen(specimen)
            println("✓ Specimen is valid!")
            
        else
            println("Error: Unknown command: $command")
            exit(1)
        end
        
    catch e
        if isa(e, SpecimenError)
            println("❌ Specimen Error: $(e.message)")
            exit(1)
        else
            println("❌ Error: $(e.msg)")
            exit(1)
        end
    end
end

# Run main if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end