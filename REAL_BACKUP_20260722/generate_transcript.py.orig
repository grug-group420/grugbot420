#!/usr/bin/env python3
"""
Generate chat_transcript.md — human-readable conversation log from run 1.
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
            results.append({'input': name, 'status': 'ERROR', 'reply': '[crashed]'})
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
            results.append({'input': name, 'status': 'OK', 'reply': reply})
        elif ask_marker in content:
            idx = content.index(ask_marker) + len(ask_marker)
            scaffold = content[idx:].strip()
            end_line = '========================================='
            if end_line in scaffold:
                scaffold = scaffold[:scaffold.index(end_line)].strip()
            results.append({'input': name, 'status': 'ASK', 'reply': scaffold.strip()})
        else:
            results.append({'input': name, 'status': 'NO_SCAFFOLD', 'reply': '[no output]'})
    return results

def main():
    base = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'specimens')
    results = extract_replies(os.path.join(base, 'all_missions_raw.txt'))
    
    md = []
    md.append('# GrugBot420 Chat Transcript — Dynamic AIML v7.38')
    md.append('')
    md.append(f'**Date**: {datetime.now().strftime("%Y-%m-%d %H:%M UTC")}')
    md.append(f'**Specimen**: comprehensive_specimen.json (25 nodes, voice_variants enabled)')
    md.append(f'**Dynamic features**: Domain thesaurus (90+ entries), voice variants (2-3 per node), light thesaurus touch (rate=0.30, threshold=2+), swap rate=0.35')
    md.append('')
    md.append('---')
    md.append('')
    
    for i, r in enumerate(results, 1):
        # Clean up the reply for readability
        reply = r['reply'].strip()
        # Remove telemetry noise
        reply = re.sub(r'\s{2,}', ' ', reply)
        
        md.append(f'**You**: {r["input"]}')
        md.append('')
        md.append(f'**Grug**: {reply}')
        md.append('')
        md.append('---')
        md.append('')
    
    outpath = os.path.join(base, 'chat_transcript.md')
    with open(outpath, 'w') as f:
        f.write('\n'.join(md))
    print(f'Transcript written to {outpath}')

if __name__ == '__main__':
    main()
