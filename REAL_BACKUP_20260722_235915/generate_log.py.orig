#!/usr/bin/env python3
"""
Generate test_run_log.md from parsed mission results.
Includes run1 and run2 comparison to demonstrate dynamic output.
"""
import re
import os
from datetime import datetime

def extract_replies(filepath):
    with open(filepath) as f:
        text = f.read()
    blocks = re.split(r'===MISSION_START:(.*?)===', text)
    results = []
    for i in range(1, len(blocks), 2):
        name = blocks[i]
        content = blocks[i+1] if i+1 < len(blocks) else ''
        end = f'===MISSION_END:{name}==='
        if end in content:
            content = content[:content.index(end)]
        
        if '!!!MISSION_ERROR:' in content:
            err = re.search(r'!!!MISSION_ERROR: (.*)', content)
            results.append({
                'input': name,
                'status': 'ERROR',
                'reply': f'[Mission crashed: {err.group(1).strip() if err else "Unknown"}]',
                'scaffold': '',
            })
            continue
        
        marker = '\U0001f916 AIML Output Scaffold:'
        ask_marker = '\U0001f916 AIML Ask Question:'
        
        if marker in content:
            idx = content.index(marker) + len(marker)
            scaffold = content[idx:].strip()
            end_line = '========================================='
            if end_line in scaffold:
                scaffold = scaffold[:scaffold.index(end_line)].strip()
            tel = '--- DEBUG TELEMETRY'
            reply = scaffold
            if tel in scaffold:
                reply = scaffold[:scaffold.index(tel)].strip()
            results.append({
                'input': name,
                'status': 'OK',
                'reply': reply,
                'scaffold': scaffold,
            })
        elif ask_marker in content:
            idx = content.index(ask_marker) + len(ask_marker)
            scaffold = content[idx:].strip()
            end_line = '========================================='
            if end_line in scaffold:
                scaffold = scaffold[:scaffold.index(end_line)].strip()
            results.append({
                'input': name,
                'status': 'ASK',
                'reply': scaffold.strip(),
                'scaffold': scaffold.strip(),
            })
        else:
            results.append({
                'input': name,
                'status': 'NO_SCAFFOLD',
                'reply': '[No AIML output captured]',
                'scaffold': '',
            })
    return results

def main():
    base = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'specimens')
    run1 = extract_replies(os.path.join(base, 'all_missions_raw.txt'))
    run2 = extract_replies(os.path.join(base, 'all_missions_raw_run2.txt'))
    
    md = []
    md.append('# GrugBot420 Specimen Test Run Log — Dynamic AIML v7.38')
    md.append('')
    md.append(f'**Date**: {datetime.now().strftime("%Y-%m-%d %H:%M UTC")}')
    md.append(f'**Specimen**: comprehensive_specimen.json (25 nodes)')
    md.append(f'**Runs**: 2 runs compared to verify dynamic output')
    md.append('')
    md.append('## Changes in v7.38')
    md.append('')
    md.append('- **Domain synonyms added to Thesaurus.jl**: ~90 new entries covering math (derivative, integral, theorem, compute, function, slope, equation, solve, number, triangle, geometry, mathematics), survival (survive, danger, flee, hide, concealment, stealth, fight, courage, defend, alert, warning, caution, watch), emotion (sadness, anxiety, grief, comfort, validate, feelings, pain, worry, breathe, safe, alone), creativity (imagine, create, poetry, story, weave, beauty, beautiful, explore, wonder, write), philosophy (contemplate, consciousness, meaning, existence, sacred, permanent, truth, will, determinism, choose, choice, agency, aware, awareness, feel, real, valid), perception (see, sunset, horizon, orange, purple, stretch, describe, capture), and misc vocabulary (acknowledge, preserve, engage, perhaps, must, wisdom, chaos, language, soul, capacity, absence, despite, quality, inverse, accumulate, rate, change, measure, fact, careful, justified, weakness, information)')
    md.append('- **Voice variants added to all 25 specimen nodes**: Each node now has 2-3 alternative prose expressions that convey the same knowledge in different sentence structures and word choices')
    md.append('- **LIGHT_TOUCH threshold lowered**: Changed from 3+ synonyms required to 2+ synonyms required. This allows domain-specific words with exactly 2 high-quality synonyms to be eligible for swap')
    md.append('- **LIGHT_TOUCH_RATE increased**: Changed from 0.15 (15% chance per eligible word) to 0.30 (30% chance). Produces visibly different prose while preserving author voice')
    md.append('- **SWAP_RATE increased**: Changed from 0.25 (25% for mechanical claims) to 0.35 (35%). More synonym variation in SUPPORT clauses and relational triples')
    md.append('')
    
    md.append('## Run 1 Results (25 missions)')
    md.append('')
    ok = sum(1 for r in run1 if r['status'] == 'OK')
    ask = sum(1 for r in run1 if r['status'] == 'ASK')
    err = sum(1 for r in run1 if r['status'] == 'ERROR')
    md.append(f'**Summary**: {ok} OK, {ask} ASK, {err} ERROR')
    md.append('')
    
    for r in run1:
        reply = r['reply'].replace('\n', '  \n')
        md.append(f'### [{r["status"]}] "{r["input"]}"')
        md.append('')
        md.append(f'> {reply}')
        md.append('')
    
    md.append('---')
    md.append('')
    md.append('## Run 2 Results (8-mission subset for comparison)')
    md.append('')
    
    # Build lookup for run2
    run2_map = {r['input']: r for r in run2}
    
    for r in run1:
        if r['input'] in run2_map:
            r2 = run2_map[r['input']]
            same = r['reply'] == r2['reply']
            status = 'IDENTICAL' if same else 'DYNAMIC'
            md.append(f'### {status}: "{r["input"]}"')
            md.append('')
            md.append(f'**Run 1**: {r["reply"][:200].replace(chr(10), " ")}')
            md.append('')
            md.append(f'**Run 2**: {r2["reply"][:200].replace(chr(10), " ")}')
            md.append('')
    
    md.append('---')
    md.append('')
    md.append('## Dynamic Output Verification')
    md.append('')
    total_compared = sum(1 for r in run1 if r['input'] in run2_map)
    dynamic_count = sum(1 for r in run1 if r['input'] in run2_map and r['reply'] != run2_map[r['input']]['reply'])
    md.append(f'**Compared missions**: {total_compared}')
    md.append(f'**Dynamic (different across runs)**: {dynamic_count}/{total_compared}')
    md.append(f'**Static (identical across runs)**: {total_compared - dynamic_count}/{total_compared}')
    md.append('')
    if dynamic_count == total_compared:
        md.append('**Result: ALL outputs are unique across runs. Dynamic AIML is working.**')
    else:
        md.append(f'**Result: {dynamic_count}/{total_compared} outputs are dynamic. {(total_compared-dynamic_count)} remain static.**')
    md.append('')
    
    outpath = os.path.join(base, 'test_run_log.md')
    with open(outpath, 'w') as f:
        f.write('\n'.join(md))
    print(f'Log written to {outpath}')

if __name__ == '__main__':
    main()
