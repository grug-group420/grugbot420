#!/usr/bin/env python3
"""Remove /antiAnswer and /addAntiMatch commands. Drop comments everywhere antimatch nodes were referenced."""

import re

def process_file(path, replacements):
    with open(path, 'r') as f:
        content = f.read()
    for old, new in replacements:
        content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)
    print(f"  Processed: {path}")

# ═══════════════════════════════════════════════════════════════
# Main.jl — remove commands, update help, update strain text
# ═══════════════════════════════════════════════════════════════
main_replacements = [
    # Strain response: remove /antiAnswer mention
    ('Or /antiAnswer to suppress. (strain=',
     '(strain='),
    
    # Comment about /answer and /antiAnswer → just /answer
    ('# This stores the mission text that caused the question so /answer and /antiAnswer',
     '# This stores the mission text that caused the question so /answer'),
    ('#   strain → ask question → user answers (/answer or /antiAnswer) → strain resolved',
     '#   strain → ask question → user answers (/answer) → strain resolved'),
    ('# /answer and /antiAnswer can reference what caused the question.',
     '# /answer can reference what caused the question.'),
    ('# GRUG: Store the mission text so /answer and /antiAnswer can reference it.',
     '# GRUG: Store the mission text so /answer can reference it.'),
    ('# the user to use /answer or /antiAnswer. This is the hippocampal ask step:',
     '# the user to use /answer. This is the hippocampal ask step:'),

    # Help text: remove /addAntiMatch and /antiAnswer lines
    ('         : /addAntiMatch <pattern> [NONJITTER]  (anti-match confidence drain node)\n', ''),
    ('         : /antiAnswer [@lobe_id] [:mode] <text> (suppress strain — modes: alert, multi, json)\n', ''),
    ('         : /antiAnswer to resolve. Modes shape how answers are stored:\n', ''),
    ('         : /antiAnswer modes: alert (default), multi, json\n', ''),

    # Help table rows
    ('║  /addAntiMatch <pattern>    Anti-match confidence drain node  ║\n', 
     '║  /addAntiMatch <pattern>    REMOVED — antimatch nodes deleted ║\n'),
    ('║  /antiAnswer [@lobe] [:mode] <text> Suppress strain (modes: alert/multi/json) ║\n',
     '║  /antiAnswer [@lobe] [:mode] <text> REMOVED — antimatch nodes deleted        ║\n'),
    
    # Second help table
    ('║  /antiAnswer [@lobe] [:mode] <text> Suppress strain         ║\n',
     '║  /antiAnswer [@lobe] [:mode] <text> REMOVED                  ║\n'),
    
    # Command overview line
    ('║         /addRelRelation /addAntiMatch /newLobe /nameLobe     ║\n',
     '║         /addRelRelation /newLobe /nameLobe                   ║\n'),
]

process_file('/workspace/grugbot420_repo/src/Main.jl', main_replacements)

# ═══════════════════════════════════════════════════════════════
# Main.jl — remove the /addAntiMatch regex matcher line
# ═══════════════════════════════════════════════════════════════
with open('/workspace/grugbot420_repo/src/Main.jl', 'r') as f:
    lines = f.readlines()

out_lines = []
skip_mode = None  # None, 'addAntiMatch', 'antiAnswer'
i = 0
while i < len(lines):
    line = lines[i]
    
    # Skip the regex matcher line for /addAntiMatch
    if 'm_addantimatch=' in line and 'match(r"^/addAntiMatch' in line:
        # Replace with a comment
        out_lines.append('            # GRUG v8.26h: /addAntiMatch REMOVED — antimatch nodes are no longer a thing.\n')
        i += 1
        continue
    
    # Skip the regex matcher line for /antiAnswer
    if 'm_antianswer=' in line and 'match(r"^/antiAnswer' in line:
        out_lines.append('            # GRUG v8.26h: /antiAnswer REMOVED — antimatch nodes are no longer a thing.\n')
        i += 1
        continue
    
    # Remove the entire /addAntiMatch handler block
    if 'elseif !isnothing(m_addantimatch)' in line:
        # Find the end of this block — next elseif or end at same indent
        out_lines.append('            # GRUG v8.26h: /addAntiMatch handler REMOVED — antimatch nodes are no longer a thing.\n')
        # Skip until next elseif/end at same indent level
        j = i + 1
        depth = 0
        while j < len(lines):
            stripped = lines[j].strip()
            # Count depth changes
            if stripped.startswith('elseif') and depth == 0:
                break
            if stripped.startswith('end') and depth == 0:
                break
            if stripped == 'else' and depth == 0:
                break
            # Track nesting
            depth += lines[j].count(' begin') + lines[j].count(' if ') - lines[j].count(' end')
            j += 1
        i = j
        continue
    
    # Remove the entire /antiAnswer handler block  
    if 'elseif !isnothing(m_antianswer)' in line:
        out_lines.append('            # GRUG v8.26h: /antiAnswer handler REMOVED — antimatch nodes are no longer a thing.\n')
        j = i + 1
        depth = 0
        while j < len(lines):
            stripped = lines[j].strip()
            if stripped.startswith('elseif') and depth == 0:
                break
            if stripped.startswith('end') and depth == 0:
                break
            if stripped == 'else' and depth == 0:
                break
            depth += lines[j].count(' begin') + lines[j].count(' if ') - lines[j].count(' end')
            j += 1
        i = j
        continue
    
    out_lines.append(line)
    i += 1

with open('/workspace/grugbot420_repo/src/Main.jl', 'w') as f:
    f.writelines(out_lines)
print("  Processed: Main.jl (handler removal)")

# ═══════════════════════════════════════════════════════════════
# engine.jl — add removal comments at key antimatch references
# ═══════════════════════════════════════════════════════════════
engine_replacements = [
    # Node struct field comment
    ('# GRUG v7.49: Is this node an anti-match node? (pattern-activated confidence drain,\n    # never enters vote pool, no strength dynamics, no stage competition)\n    is_antimatch_node::Bool\n# ⚠️ REMINDER: ANTIMATCH NODES WERE REMOVED. This field is dead/legacy only.',
     '# GRUG v8.26h: is_antimatch_node field is DEAD/LEGACY. Antimatch nodes were removed.\n    # /addAntiMatch and /antiAnswer commands deleted. This field remains for specimen compat.\n    is_antimatch_node::Bool'),

    # Vote struct field  
    ('    antimatch::Bool\n    # ---- v7.23 multipart fields',
     '    antimatch::Bool  # GRUG v8.26h: LEGACY — antimatch nodes removed. Field kept for compat.\n    # ---- v7.23 multipart fields'),

    # create_node signature comment
    ('#If is_antimatch_node=true, node is an anti-match: pattern-activated but vote-silent,',
     '# GRUG v8.26h: is_antimatch_node is LEGACY/DEAD. Antimatch nodes removed.\n#If is_antimatch_node=true, node is an anti-match: pattern-activated but vote-silent,'),
]
process_file('/workspace/grugbot420_repo/src/engine.jl', engine_replacements)

# ═══════════════════════════════════════════════════════════════
# VoteOrchestrator.jl — comment the anti_match_score field
# ═══════════════════════════════════════════════════════════════
vo_replacements = [
    ('const VOTE_W_ANTI_MATCH_PENALTY = 0.00   # antimatch removed — penalty unused, zeroed',
     'const VOTE_W_ANTI_MATCH_PENALTY = 0.00   # GRUG v8.26h: antimatch nodes removed. Penalty dead/zero.'),
    ('  anti_match_score     in [0,1] — 1.0 if anti-match detected (stance violator)',
     '  anti_match_score     in [0,1] — LEGACY: was 1.0 if anti-match detected. Antimatch nodes removed v8.26h.'),
    ('    anti_match_score::Float64',
     '    anti_match_score::Float64  # GRUG v8.26h: LEGACY — antimatch nodes removed, score always 0.0'),
]
process_file('/workspace/grugbot420_repo/src/VoteOrchestrator.jl', vo_replacements)

# ═══════════════════════════════════════════════════════════════
# AutoGrowth.jl — comment antimatch growth type
# ═══════════════════════════════════════════════════════════════
ag_replacements = [
    ('growth_type::Symbol          # :match, :time, :aiml, :antimatch, :sigil, :thesaurus, :lobe_whitelist, :flashcard',
     'growth_type::Symbol          # :match, :time, :aiml, :antimatch(DEAD), :sigil, :thesaurus, :lobe_whitelist, :flashcard'),
    ('growth_type::String         # "match", "time", "aiml", "antimatch", "sigil", "thesaurus", "lobe_whitelist", "flashcard"',
     'growth_type::String         # "match", "time", "aiml", "antimatch"(DEAD), "sigil", "thesaurus", "lobe_whitelist", "flashcard"'),
    ('    #   - :antimatch nodes get anti-relations (inverse triples)',
     '    #   - :antimatch nodes — REMOVED v8.26h. Antimatch nodes no longer exist.'),
]
process_file('/workspace/grugbot420_repo/src/AutoGrowth.jl', ag_replacements)

# ═══════════════════════════════════════════════════════════════
# ChatterMode.jl — comment the antimatch skip
# ═══════════════════════════════════════════════════════════════
cm_replacements = [
    ('node.is_antimatch_node && continue  # GRUG v7.39: antimatch nodes drain confidence, don\'t participate in steal+remix',
     '# GRUG v8.26h: antimatch nodes removed. is_antimatch_node is always false for new nodes.  # node.is_antimatch_node && continue'),
]
process_file('/workspace/grugbot420_repo/src/ChatterMode.jl', cm_replacements)

# ═══════════════════════════════════════════════════════════════
# MitosisMode.jl — comment antimatch references
# ═══════════════════════════════════════════════════════════════
mm_replacements = [
    ('        # AIML nodes (backward-compat) and antimatch nodes are ALWAYS singletons — no latching.',
     '        # AIML nodes (backward-compat) and antimatch nodes (REMOVED v8.26h) are ALWAYS singletons — no latching.'),
    ('        # GRUG: First — node type branch. AIML (backward-compat) and antimatch = always singleton.',
     '        # GRUG: First — node type branch. AIML (backward-compat) and antimatch (REMOVED v8.26h) = always singleton.'),
]
process_file('/workspace/grugbot420_repo/src/MitosisMode.jl', mm_replacements)

# ═══════════════════════════════════════════════════════════════
# EphemeralMLP.jl — comment antimatch feature
# ═══════════════════════════════════════════════════════════════
emlp_replacements = [
    ('provides an /answer or /antiAnswer — resolving the structural deficit that',
     'provides an /answer — resolving the structural deficit that'),
    ('  6. Fraction of votes with antimatch=true',
     '  6. Fraction of votes with antimatch=true (LEGACY v8.26h — always 0 now)'),
]
process_file('/workspace/grugbot420_repo/src/EphemeralMLP.jl', emlp_replacements)

# ═══════════════════════════════════════════════════════════════
# EphemeralAutomaton.jl — comment anti_match_detected
# ═══════════════════════════════════════════════════════════════
ea_replacements = [
    ('    anti_match_detected::Bool = false,',
     '    anti_match_detected::Bool = false,  # GRUG v8.26h: LEGACY — antimatch nodes removed'),
]
process_file('/workspace/grugbot420_repo/src/EphemeralAutomaton.jl', ea_replacements)

# ═══════════════════════════════════════════════════════════════
# Update all the REMINDER banners across all files
# ═══════════════════════════════════════════════════════════════
import glob
for jl_file in glob.glob('/workspace/grugbot420_repo/src/*.jl'):
    with open(jl_file, 'r') as f:
        content = f.read()
    original = content
    # Update the antimatch banner to mention v8.26h removal
    content = content.replace(
        '║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║\n║     antimatch logic. That entire concept was deprecated and deleted.          ║\n║     If you find yourself writing antimatch code, STOP — you are              ║',
        '║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║\n║     antimatch logic. That entire concept was deprecated and deleted.          ║\n║     /addAntiMatch and /antiAnswer removed v8.26h. If you find yourself        ║'
    )
    if content != original:
        with open(jl_file, 'w') as f:
            f.write(content)
        print(f"  Updated banner: {jl_file}")

print("\nDone! All /antiAnswer and /addAntiMatch references updated.")
