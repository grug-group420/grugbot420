#!/usr/bin/env python3
"""
Patch relational_patterns in the v758 specimen.
- Dereference sigil tokens (&n, &op, &word) in triple subjects/objects
- Replace circular/generic triples with meaningful ones based on node topic
"""

import json
import re
import copy

# ── SIGIL DEREFERENCE MAP ──
# For triple tokens like &n, &op, &word, &doAction, &rest
SIGIL_TOKEN_CONCRETE = {
    '&n': 'number',
    '&op': 'operation',
    '&word': 'word',
    '&doAction': 'action',
    '&rest': 'rest',
    '&temporal': 'time',
    '&causal': 'cause',
    '&emotional': 'feeling',
    '&spatial': 'place',
    '&similarity': 'likeness',
    '&possessive': 'possession',
}

# ── TOPIC KNOWLEDGE MAP ──
# Maps topic keywords to meaningful (subject, relation, object) triples
TOPIC_KNOWLEDGE = {
    'macroeconomics': ('economy', 'shapes', 'nations'),
    'mushroom': ('fungus', 'grows', 'forest floor'),
    'tesseract': ('shape', 'extends', 'dimension'),
    'peloponnesian': ('war', 'shapes', 'history'),
    'syntax': ('structure', 'organizes', 'language'),
    'dangerous': ('danger', 'demands', 'caution'),
    'essential': ('necessity', 'drives', 'survival'),
    'blue': ('color', 'reveals', 'light'),
    'courage': ('bravery', 'follows', 'fear'),
    'hunting': ('need', 'drives', 'the hunt'),
    'fire': ('flame', 'provides', 'warmth'),
    'water': ('liquid', 'sustains', 'life'),
    'shelter': ('structure', 'protects', 'the clan'),
    'food': ('nourishment', 'fuels', 'the body'),
    'rock': ('stone', 'serves', 'as tool'),
    'grug': ('grug', 'knows', 'the world'),
    'plus': ('addition', 'combines', 'quantities'),
    'minus': ('subtraction', 'reduces', 'quantities'),
    'times': ('multiplication', 'repeats', 'addition'),
    'divided': ('division', 'splits', 'wholes'),
}

def dereference_sigil_token(token):
    """Dereference a sigil token like &n, &word, &op to a concrete value."""
    if token in SIGIL_TOKEN_CONCRETE:
        return SIGIL_TOKEN_CONCRETE[token]
    if token.startswith('&'):
        return token[1:] + ' concept'
    return token

def make_meaningful_triple(pattern, system_prompt, noun_anchors):
    """Generate a meaningful triple based on the node's pattern/topic."""
    # Extract topic from pattern or system_prompt
    pat_words = pattern.lower().split() if pattern else []
    question_words = {'what', 'how', 'why', 'when', 'where', 'who', 'which', 'is', 'are', 
                      'do', 'does', 'tell', 'me', 'about', 'describe', 'the', 'a', 'an',
                      'and', 'or', 'but', 'for', 'grug', 'hits', 'makes', 'of', 'that',
                      'this', 'it', 'in', 'on', 'to', 'be', 'was', 'were', 'been', 'being'}
    topic_words = [w for w in pat_words if w not in question_words and len(w) > 2]
    
    # Try to find topic in knowledge map
    for tw in topic_words:
        if tw in TOPIC_KNOWLEDGE:
            return TOPIC_KNOWLEDGE[tw]
    
    # Try noun_anchors
    if noun_anchors and len(noun_anchors) >= 2:
        na0, na1 = str(noun_anchors[0]), str(noun_anchors[1])
        # Clean up noun anchors
        if na0 and na1 and na0 not in question_words and na1 not in question_words:
            return (na0, 'connects to', na1)
    
    # Try extracting from system_prompt
    sp = system_prompt or ''
    # Look for "X comes before Y", "X leads to Y", "X sits near Y" etc
    m = re.match(r'Grug\.\s+(\w+)\s+(comes before|leads to|feels toward|sits near|is like|has)\s+(\w[\w\s]*?)\.', sp)
    if m:
        return (m.group(1).lower(), m.group(2), m.group(3).strip().lower())
    
    # Fallback: use first meaningful topic word
    topic = topic_words[0] if topic_words else 'knowledge'
    if topic in TOPIC_KNOWLEDGE:
        return TOPIC_KNOWLEDGE[topic]
    return (topic, 'connects to', 'understanding')


def is_circular_triple(subj, pred, obj, pattern):
    """Check if a triple is circular/generic (just rearranged pattern keywords)."""
    question_words = {'what', 'how', 'why', 'when', 'where', 'who', 'which', 'is', 'are',
                      'do', 'does', 'tell', 'me', 'about', 'describe', 'define', 'and',
                      'targets', 'that', 'this', 'the', 'a', 'an'}
    
    # Subject is a question word → circular
    if subj.lower() in question_words:
        return True
    # Object is a question word → circular
    if obj.lower() in question_words:
        return True
    # Subject == object → circular
    if subj.lower() == obj.lower():
        return True
    # Pred is a generic copula → circular
    generic_preds = {'is', 'are', 'targets', 'about', 'of'}
    if pred.lower() in generic_preds and subj.lower() in question_words:
        return True
    
    return False


def patch_relational_patterns(input_path, output_path):
    """Patch all relational_patterns in the specimen."""
    with open(input_path) as f:
        data = json.load(f)
    
    nodes = data.get('nodes', [])
    print(f"Loaded {len(nodes)} nodes from {input_path}")
    
    stats = {
        'total_triples': 0,
        'sigil_derefed': 0,
        'circular_replaced': 0,
        'good_kept': 0,
    }
    
    for n in nodes:
        nid = n.get('id', '?')
        rp = n.get('relational_patterns', [])
        pattern = n.get('pattern', '')
        sp = n.get('json_data', {}).get('system_prompt', '')
        na = n.get('json_data', {}).get('noun_anchors', [])
        
        if not rp:
            continue
        
        new_rp = []
        for triple in rp:
            if isinstance(triple, dict):
                subj = triple.get('subject', '')
                pred = triple.get('relation', '')
                obj = triple.get('object', '')
            elif isinstance(triple, (list, tuple)) and len(triple) >= 3:
                subj, pred, obj = triple[0], triple[1], triple[2]
            else:
                new_rp.append(triple)
                continue
            
            stats['total_triples'] += 1
            had_sigil = '&' in subj or '&' in pred or '&' in obj
            
            # Step 1: Dereference sigils
            if had_sigil:
                subj = dereference_sigil_token(subj)
                pred = dereference_sigil_token(pred) if pred.startswith('&') else pred
                obj = dereference_sigil_token(obj)
                stats['sigil_derefed'] += 1
            
            # Step 2: Check if circular/generic
            if is_circular_triple(subj, pred, obj, pattern):
                # Replace with meaningful triple
                new_s, new_r, new_o = make_meaningful_triple(pattern, sp, na)
                new_rp.append({'subject': new_s, 'relation': new_r, 'object': new_o})
                stats['circular_replaced'] += 1
                print(f"  {nid}: ({subj}, {pred}, {obj}) → ({new_s}, {new_r}, {new_o})")
            else:
                # Good triple, keep it (with dereferenced sigils if any)
                new_rp.append({'subject': subj, 'relation': pred, 'object': obj})
                stats['good_kept'] += 1
        
        n['relational_patterns'] = new_rp
    
    data['nodes'] = nodes
    
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"\nPatching complete!")
    print(f"  Total triples processed: {stats['total_triples']}")
    print(f"  Sigils dereferenced: {stats['sigil_derefed']}")
    print(f"  Circular triples replaced: {stats['circular_replaced']}")
    print(f"  Good triples kept: {stats['good_kept']}")
    print(f"Saved to: {output_path}")
    
    # Verification
    print("\n--- Verification ---")
    sigils_remaining = 0
    circular_remaining = 0
    for n in nodes:
        nid = n.get('id', '?')
        rp = n.get('relational_patterns', [])
        for triple in rp:
            if isinstance(triple, dict):
                s, p, o = triple.get('subject', ''), triple.get('relation', ''), triple.get('object', '')
            else:
                continue
            if '&' in s or '&' in p or '&' in o:
                sigils_remaining += 1
                print(f"  WARNING: Sigil in triple {nid}: ({s}, {p}, {o})")
            question_words = {'what', 'how', 'why', 'when', 'where', 'who', 'which', 'is', 'are',
                              'do', 'does', 'tell', 'me', 'about', 'describe', 'define', 'and', 'targets'}
            if s.lower() in question_words or o.lower() in question_words:
                circular_remaining += 1
                print(f"  WARNING: Circular triple {nid}: ({s}, {p}, {o})")
    print(f"Sigils remaining in triples: {sigils_remaining}")
    print(f"Circular triples remaining: {circular_remaining}")


if __name__ == '__main__':
    input_path = '/workspace/grugbot420/comprehensive_specimen_v758_patched.json'
    output_path = '/workspace/grugbot420/comprehensive_specimen_v758_patched.json'
    patch_relational_patterns(input_path, output_path)
