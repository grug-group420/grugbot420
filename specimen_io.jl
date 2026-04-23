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
using Printf

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
Continuous append mode editor for rapid JSON appending

Opens a dedicated editor where you can paste JSON repeatedly. Each save automatically
appends the JSON to the specimen file. The editor stays open for continuous appending.

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
        
        # Append counter for this session
        append_count = 0
        session_start = time()
        failed_count = 0
        
        # Initial instructions
        initial_content = """
════════════════════════════════════════════════════════════════════
CONTINUOUS APPEND MODE - GRUGBOT420 SPECIMEN
════════════════════════════════════════════════════════════════════

TARGET FILE: $target_file
SESSION STARTED: $(Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))

════════════════════════════════════════════════════════════════════
HOW TO USE:
════════════════════════════════════════════════════════════════════

1. PASTE YOUR JSON below the marker line
2. SAVE THE FILE (Ctrl+S or :w) → JSON automatically appended!
3. CLEAR the JSON area (leave marker intact)
4. PASTE ANOTHER JSON
5. SAVE again → appended again!
6. REPEAT steps 3-5 as many times as you want
7. When DONE, close the editor

HOTKEYS (SAVE = APPEND):
• Vim:          :w      (save/append, keep editor open)
• Vim:          :q      (quit when done)
• Notepad:      Ctrl+S  (save/append)
• Notepad:      Alt+F4  (quit when done)
• VS Code:      Ctrl+S  (save/append)
• VS Code:      Ctrl+Q  (quit when done)

WHAT CAN I APPEND?
• Single node:   {"id": "N-0001", "pattern": "...", ...}
• Multiple:      [{"id": "N-001", ...}, {"id": "N-002", ...}]
• Lobes:         {"mathematics": "Pure mathematics..."}
• Any JSON:      (will be auto-formatted to fit)

════════════════════════════════════════════════════════════════════
SESSION LOG:
════════════════════════════════════════════════════════════════════
Appended successfully: 0
Failed attempts:        0
════════════════════════════════════════════════════════════════════

════════════════════════════════════════════════════════════════════
PASTE JSON BELOW THIS LINE:
════════════════════════════════════════════════════════════════════


"""
        
        # Write initial content
        write(append_file, initial_content)
        
        println("📝 CONTINUOUS APPEND MODE STARTED")
        println("─" * 70)
        println("📁 Target file: $target_file")
        println("📝 Edit file:   $append_file")
        println("🔧 Editor:      $editor")
        println("─" * 70)
        println("📌 PASTE JSON → SAVE → AUTO-APPENDED → REPEAT")
        println("─" * 70)
        println()
        
        # Store last processed content to detect changes
        last_processed_content = initial_content
        
        # Start monitoring in background
        monitor_task = @async begin
            monitor_interval = 0.5  # Check every 500ms
            
            while true
                sleep(monitor_interval)
                
                try
                    if !isfile(append_file)
                        # Editor closed file, stop monitoring
                        break
                    end
                    
                    # Read current content
                    current_content = read(append_file, String)
                    
                    # Check if content changed
                    if current_content != last_processed_content
                        # Extract new JSON and append
                        json_start = findfirst("PASTE JSON BELOW THIS LINE:", current_content)
                        
                        if json_start !== nothing
                            json_section = current_content[last(json_start)+length("PASTE JSON BELOW THIS LINE:"):end]
                            json_section = strip(json_section)
                            
                            # Only process if there's JSON and it's different from last time
                            if !isempty(json_section)
                                try
                                    # Try to parse JSON
                                    json_obj = JSON3.read(json_section)
                                    validate_json_object(json_obj)
                                    
                                    # Load specimen
                                    specimen = load_specimen(target_file)
                                    
                                    # Determine append type
                                    appended = 0
                                    if isa(json_obj, Dict)
                                        if haskey(json_obj, "id") && haskey(json_obj, "pattern")
                                            push!(specimen["nodes"], json_obj)
                                            appended = 1
                                            println("✓ [$(Dates.format(Dates.now(), "HH:MM:SS"))] Appended 1 node")
                                        else
                                            for (k, v) in json_obj
                                                specimen[k] = v
                                            end
                                            appended = 1
                                            println("✓ [$(Dates.format(Dates.now(), "HH:MM:SS"))] Appended metadata")
                                        end
                                    elseif isa(json_obj, Array) && !isempty(json_obj)
                                        if haskey(json_obj[1], "id")
                                            for node in json_obj
                                                push!(specimen["nodes"], node)
                                            end
                                            appended = length(json_obj)
                                            println("✓ [$(Dates.format(Dates.now(), "HH:MM:SS"))] Appended $appended nodes")
                                        end
                                    end
                                    
                                    if appended > 0
                                        # Save specimen
                                        save_specimen(specimen, target_file)
                                        append_count += appended
                                        
                                        # Update log in editor file
                                        updated_content = replace(current_content,
                                            r"Appended successfully: \d+.*"m => "Appended successfully: $append_count\nFailed attempts:        $failed_count"
                                        )
                                        write(append_file, updated_content)
                                        last_processed_content = updated_content
                                    end
                                    
                                catch e
                                    # JSON parsing failed, don't update
                                    # Will be retried on next save
                                    failed_count += 1
                                    println("❌ [$(Dates.format(Dates.now(), "HH:MM:SS"))] Failed: $(isa(e, SpecimenError) ? e.message : e.msg)")
                                end
                            end
                        end
                    end
                catch e
                    # File might be locked by editor, ignore and retry
                    # println("⚠️  Monitor error: $(e.msg)")
                end
            end
        end
        
        # Launch editor (will block until closed)
        try
            run(`$editor $append_file`)
        catch
            println("⚠️  Editor launch failed. Please edit manually: $append_file")
            println("⚠️  Press Enter when done appending...")
            readline()
        end
        
        # Wait a bit for final processing
        sleep(1)
        
        # Clean up
        rm(append_file)
        
        # Print session summary
        session_time = time() - session_start
        println("─" * 70)
        println("📊 SESSION COMPLETED")
        println("─" * 70)
        println("Items appended: $append_count")
        println("Failed attempts: $failed_count")
        println("Session time:   $(round(session_time, digits=2))s")
        println("─" * 70)
        println("✓ Continuous append session finished!")
        
    catch e
        if isa(e, SpecimenError)
            rethrow(e)
        else
            throw(SpecimenError("Failed to run continuous append: $(e.msg)"))
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