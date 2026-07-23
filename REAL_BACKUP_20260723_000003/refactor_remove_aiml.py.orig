#!/usr/bin/env python3
"""
Phase 1: Remove AIMLNodeSystem and rename AIML artifacts in Main.jl.

Strategy: Read Main.jl, apply all changes, write back.
- Remove AIMLNodeSystem include/using block
- Remove AIMLNodeSystem function calls (begin_cycle!, stochastic_aiml_growth!, etc.)
- Remove /aiml* REPL commands and matchers
- Remove aiml_system from specimen save/load/display/validation
- Remove AIMLNodeSystem.reset_all!() from brain_transplant
- Remove AIMLNodeSystem.register_lobe!() from /newLobe
- Remove AIML tribe status from /status
- Remove AIML help text from command reference
- Rename generate_aiml_payload → synthesize_voice_reply
- Rename _LAST_AIML_OUTPUT → _LAST_VOICE_OUTPUT
- Rename _LAST_AIML_OUTPUT_LOCK → _LAST_VOICE_OUTPUT_LOCK
- Rename ephemeral_aiml_orchestrator → ephemeral_voice_orchestrator
- Rename AIML_DROP_TABLE → ORCHESTRATION_RULES (comments only in Main.jl, const in engine.jl)
"""

import re
import sys

def process_main_jl(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    output_lines = []
    i = 0
    changes = []

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # ── 1. Remove AIMLNodeSystem include/using block (lines ~237-241) ──
        if stripped.startswith('# GRUG: AIMLNodeSystem needed for aiml_system save/load.'):
            # Skip this block (3-4 lines)
            while i < len(lines) and not (
                lines[i].strip().startswith('# GRUG: TonalJudge') or
                (lines[i].strip() == 'end' and i > 0 and 'AIMLNodeSystem' in lines[i-2])
            ):
                if 'AIMLNodeSystem' in lines[i] or 'aiml_system' in lines[i] or lines[i].strip().startswith('# GRUG: AIMLNodeSystem'):
                    changes.append(f"L{i+1}: Removed AIMLNodeSystem include/using block")
                    i += 1
                else:
                    break
            # Also skip the 'end' line if it's the end of the if block
            if i < len(lines) and lines[i].strip() == 'end' and i > 0 and any('AIMLNodeSystem' in lines[j] for j in range(max(0,i-3), i)):
                i += 1
            continue

        # ── 2. Remove _LAST_AIML_OUTPUT / _LAST_AIML_OUTPUT_LOCK declarations ──
        # Rename them instead of removing (test harness needs them)
        if '_LAST_AIML_OUTPUT' in line and 'LOCK' not in line:
            line = line.replace('_LAST_AIML_OUTPUT', '_LAST_VOICE_OUTPUT')
            changes.append(f"L{i+1}: Renamed _LAST_AIML_OUTPUT → _LAST_VOICE_OUTPUT")
        if '_LAST_AIML_OUTPUT_LOCK' in line:
            line = line.replace('_LAST_AIML_OUTPUT_LOCK', '_LAST_VOICE_OUTPUT_LOCK')
            changes.append(f"L{i+1}: Renamed _LAST_AIML_OUTPUT_LOCK → _LAST_VOICE_OUTPUT_LOCK")

        # ── 3. Remove AIMLNodeSystem.begin_cycle!() call ──
        if 'AIMLNodeSystem.begin_cycle!()' in line:
            # Skip the 4-line block: comment, comment, comment, call
            if i >= 3:
                # Check if previous lines are the comments about this call
                j = i
                # Go back to find the start of this comment block
                while j > 0 and ('AIML cycle' in lines[j] or 'AIML node' in lines[j] or 
                               'begin_cycle' in lines[j] or '/aimlRight' in lines[j] or
                               lines[j].strip().startswith('# GRUG: Start a new AIML') or
                               lines[j].strip().startswith('# GRUG: AIML') or
                               (lines[j].strip().startswith('#') and 'cycle' in lines[j].lower() and 'aiml' in lines[j].lower())):
                    j -= 1
                # Remove lines from j+1 to i inclusive
                for k in range(j+1, i+1):
                    changes.append(f"L{k+1}: Removed AIMLNodeSystem.begin_cycle! block")
                i = i + 1
                continue
            else:
                changes.append(f"L{i+1}: Removed AIMLNodeSystem.begin_cycle!()")
                i += 1
                continue

        # ── 4. Remove AIMLNodeSystem.stochastic_aiml_growth! callbacks ──
        if 'AIMLNodeSystem.stochastic_aiml_growth!' in line:
            # Replace with a no-op lambda that returns nothing
            line = line.replace(
                'AIMLNodeSystem.stochastic_aiml_growth!(lobe_id, pattern; data_warrant=data_warrant)',
                'nothing  # GRUG: AIMLNodeSystem removed — stochastic growth callback is now no-op'
            )
            changes.append(f"L{i+1}: Replaced AIMLNodeSystem.stochastic_aiml_growth! with no-op")

        # ── 5. Remove /aiml* REPL command matchers ──
        if (stripped.startswith('m_aimlright') or stripped.startswith('m_aimlwrong') or
            stripped.startswith('m_aimlstatus') or stripped.startswith('m_aimllist') or
            stripped.startswith('m_aimladd') or stripped.startswith('m_aimlremove') or
            stripped.startswith('m_aimlcycle') or stripped.startswith('m_aimlphagy')):
            changes.append(f"L{i+1}: Removed AIML command matcher: {stripped[:30]}")
            i += 1
            continue

        # ── 6. Handle the /aimlRight handler block and all other /aiml* handlers ──
        # These are large elif blocks. We need to skip them entirely.
        # Detection: lines starting with "elseif !isnothing(m_aiml"
        if stripped.startswith('elseif !isnothing(m_aiml'):
            # Skip until the next elseif or end at same indent level
            indent_level = len(line) - len(line.lstrip())
            start_i = i
            i += 1
            while i < len(lines):
                next_stripped = lines[i].strip()
                next_indent = len(lines[i]) - len(lines[i].lstrip())
                # Stop at next elseif/end at same or lower indent, or at blank line before elseif
                if next_stripped.startswith('elseif') and next_indent <= indent_level + 4:
                    break
                if next_stripped.startswith('end') and next_indent <= indent_level:
                    break
                if next_stripped == '' and i + 1 < len(lines) and (
                    lines[i+1].strip().startswith('elseif') or lines[i+1].strip().startswith('end')
                ):
                    i += 1  # skip blank line too
                    break
                i += 1
            changes.append(f"L{start_i+1}: Removed /aiml* handler block ({i - start_i} lines)")
            continue

        # ── 7. Remove aiml_system from specimen save ──
        if 'specimen["aiml_system"]' in line and 'serialize' in line:
            changes.append(f"L{i+1}: Removed aiml_system specimen save")
            i += 1
            continue

        # ── 8. Remove aiml_system from specimen load ──
        if 'AIMLNodeSystem.deserialize_aiml_state!' in line:
            # Skip the 8-line block about restoring AIML state
            start_i = i
            # Go back to find the section header
            while start_i > 0 and '4.19 AIML' not in lines[start_i] and 'AIML NODE SYSTEM STATE' not in lines[start_i]:
                if lines[start_i].strip().startswith('#') and 'AIML' in lines[start_i]:
                    break
                start_i -= 1
            # Skip forward to end of this block
            while i < len(lines) and not (
                (lines[i].strip().startswith('#') and '4.20' in lines[i]) or
                (lines[i].strip().startswith('#') and 'SIGIL TABLE' in lines[i] and '4.20' in lines[i])
            ):
                i += 1
            changes.append(f"L{start_i+1}: Removed aiml_system specimen load block")
            continue

        # ── 9. Remove AIMLNodeSystem.reset_all!() ──
        if 'AIMLNodeSystem.reset_all!()' in line:
            changes.append(f"L{i+1}: Removed AIMLNodeSystem.reset_all!()")
            i += 1
            continue

        # ── 10. Remove AIMLNodeSystem.register_lobe!() ──
        if 'AIMLNodeSystem.register_lobe!' in line:
            line = line.replace(
                'aiml_cap = AIMLNodeSystem.register_lobe!(lobe_id_new, Lobe.LOBE_NODE_CAP)',
                '# GRUG: AIMLNodeSystem removed — no more lobe registration for scaffold tribe'
            )
            # Also fix the println that references aiml_cap
            changes.append(f"L{i+1}: Removed AIMLNodeSystem.register_lobe!()")

        # ── 11. Remove AIML tribe status from /status ──
        if 'AIMLNodeSystem.get_aiml_status_summary()' in line:
            changes.append(f"L{i+1}: Removed AIML status summary call")
            i += 1
            continue

        # ── 12. Remove AIML help text from command reference ──
        # These are box-drawing lines with /aimlRight, /aimlWrong, etc.
        if ('/aimlRight' in line or '/aimlWrong' in line or '/aimlStatus' in line or
            '/aimlAdd' in line or '/aimlRemove' in line or '/aimlCycle' in line or
            '/aimlPhagy' in line or '/aimlList' in line or 'AIML NODE SYSTEM' in line.upper()):
            if '║' in line or '│' in line:
                changes.append(f"L{i+1}: Removed AIML help text line")
                i += 1
                continue

        # ── 13. Remove aiml_system from allowed_keys ──
        if '"aiml_system"' in line and ('allowed_keys' in line or 'Set(' in line or 'for k in' in line):
            line = line.replace('"aiml_system", ', '')
            line = line.replace(', "aiml_system"', '')
            line = line.replace('"aiml_system"', '')
            changes.append(f"L{i+1}: Removed aiml_system from allowed_keys/type checks")

        # ── 14. Remove AIML display stats in specimen display ──
        if '_aiml_data' in line or '_aiml_registry' in line or '_aiml_total_nodes' in line:
            # Skip these lines
            changes.append(f"L{i+1}: Removed AIML display stats")
            i += 1
            continue
        if 'AIML nodes' in line and 'push!(lines' in line:
            changes.append(f"L{i+1}: Removed AIML nodes display line")
            i += 1
            continue

        # ── 15. Remove "AIML tribe registered" from println in /newLobe ──
        if 'AIML tribe registered' in line:
            line = line.replace('AIML tribe registered (cap=$aiml_cap).', '')
            line = line.replace('AIML tribe registered.', '')
            # Clean up the println - remove trailing space before quote
            line = re.sub(r'\s+"\)', '")', line)
            changes.append(f"L{i+1}: Removed AIML tribe registered text")

        # ── 16. Remove AIML comment lines that reference removed functionality ──
        # Keep comments that are just context/explanation, remove ones that reference
        # AIML commands or features that no longer exist
        if stripped.startswith('#') and 'AIML' in stripped:
            # Comments about removed features
            if any(phrase in stripped for phrase in [
                '/aimlRight', '/aimlWrong', 'AIML tribe', 'AIML registry',
                'AIMLNodeSystem', 'aiml_system', 'AIML executive',
                'AIML node tribe', 'AIML growth', 'AIML nodes are executive'
            ]):
                # Check if this is a standalone comment line (not inline)
                if not any(code in stripped for code in ['generate_aiml', 'AIML_DROP_TABLE', 'AIML_CONFIDENCE']):
                    changes.append(f"L{i+1}: Removed AIML comment")
                    i += 1
                    continue

        # ── 17. Remove the "AIML NODE TRIBES" header in /status ──
        if 'AIML NODE TRIBES' in line:
            changes.append(f"L{i+1}: Removed AIML NODE TRIBES header")
            i += 1
            continue

        # ── 18. Remove stochastic_aiml_growth_fn comment about AIML in AutoGrowth ──
        # (Handled separately for MitosisMode.jl and AutoGrowth.jl)

        # ── RENAME OPERATIONS ──

        # 19. Rename generate_aiml_payload → synthesize_voice_reply
        if 'generate_aiml_payload' in line:
            line = line.replace('generate_aiml_payload', 'synthesize_voice_reply')
            changes.append(f"L{i+1}: Renamed generate_aiml_payload → synthesize_voice_reply")

        # 20. Rename AIML_DROP_TABLE → ORCHESTRATION_RULES
        if 'AIML_DROP_TABLE' in line:
            line = line.replace('AIML_DROP_TABLE', 'ORCHESTRATION_RULES')
            changes.append(f"L{i+1}: Renamed AIML_DROP_TABLE → ORCHESTRATION_RULES")

        # 21. Rename ephemeral_aiml_orchestrator → ephemeral_voice_orchestrator
        if 'ephemeral_aiml_orchestrator' in line:
            line = line.replace('ephemeral_aiml_orchestrator', 'ephemeral_voice_orchestrator')
            changes.append(f"L{i+1}: Renamed ephemeral_aiml_orchestrator → ephemeral_voice_orchestrator")

        # 22. Rename _LAST_AIML_OUTPUT → _LAST_VOICE_OUTPUT (any remaining)
        if '_LAST_AIML_OUTPUT' in line:
            line = line.replace('_LAST_AIML_OUTPUT', '_LAST_VOICE_OUTPUT')
            changes.append(f"L{i+1}: Renamed _LAST_AIML_OUTPUT → _LAST_VOICE_OUTPUT")

        # 23. Rename AIML Output → Voice Output in println messages
        if 'AIML Output' in line or 'AIML Ask' in line or 'AIML [Targeted' in line:
            line = line.replace('AIML Output', 'Voice Output')
            line = line.replace('AIML Ask', 'Voice Ask')
            line = line.replace('AIML [Targeted', 'Voice [Targeted')
            changes.append(f"L{i+1}: Renamed AIML label in output message")

        # 24. Clean up "AIML" in section headers that are now about voice
        if 'DYNAMIC AIML DROP TABLE' in line:
            line = line.replace('DYNAMIC AIML DROP TABLE', 'DYNAMIC ORCHESTRATION RULES')
            changes.append(f"L{i+1}: Renamed section header")
        if 'EPHEMERAL AIML ORCHESTRATOR' in line:
            line = line.replace('EPHEMERAL AIML ORCHESTRATOR', 'EPHEMERAL VOICE ORCHESTRATOR')
            changes.append(f"L{i+1}: Renamed section header")

        output_lines.append(line)
        i += 1

    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(output_lines)

    print(f"Main.jl: {len(changes)} changes applied")
    for c in changes[:50]:
        print(f"  {c}")
    if len(changes) > 50:
        print(f"  ... and {len(changes) - 50} more")

if __name__ == '__main__':
    process_main_jl('/workspace/grugbot420/src/Main.jl')
