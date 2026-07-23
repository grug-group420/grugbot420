# DoD-compliant input validator
module InputValidator
    export validate_input, sanitize_input
    
    function validate_input(input::String, pattern::Regex)
        # IAW SI-3: Malicious code protection
        return occursin(pattern, input)
    end
    
    function sanitize_input(input::String)
        # Remove dangerous characters
        return replace(input, r"[<>\"';&|]" => "")
    end
end
