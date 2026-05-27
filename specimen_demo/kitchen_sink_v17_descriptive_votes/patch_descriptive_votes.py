#!/usr/bin/env python3
"""Patch v16 seed into v17 noun-description vote pools.

Core correction from user:
  `what is fire?` should return votes like `fire hot and burns wood`.

So the action_packet for a noun node is not merely mood prose and not a generic
`explain` command. It is the answer menu: direct noun-description candidates.
"""
import json
import re
from pathlib import Path

PATH = Path('specimen_seed.txt')

PATCHES = {
    'fire': {
        'action_packet': ' | '.join([
            'fire hot and burns wood[cold, wet, stone]^4',
            'fire bright and makes smoke[dark, clean, silent]^3',
            'fire warms tribe and cooks meat[freeze, raw, alone]^4',
            'fire dangerous because it bites skin[safe, gentle, harmless]^3',
            'fire eats dry grass and grows fast[starves, wet, slow]^3',
            'fire is light that moves and needs food[still, self-fed, dark]^2',
            'fire scares wolf but must stay in ring[attracts-wolf, loose, wild]^3',
            'fire starts from spark wood air and patience[instant, water, no-air]^2',
            'fire friend when tended enemy when ignored[always-friend, safe-ignored, tame]^2',
            'fire small sun tribe carries in cave[moon, cold, empty]^1',
            'what is fire: fire hot light that eats wood[water, cold, stone]^3',
        ]),
        'drop': ['what is fire','describe fire','tell me about fire','fire meaning','fire definition','flame','ember','blaze','heat','burn'],
        'system_prompt': 'Grug describe fire directly.',
    },
    'rock': {
        'action_packet': ' | '.join([
            'rock hard earth that holds shape[soft, liquid, drifting]^4',
            'rock heavy and useful for tool wall and hammer[light, useless, weak]^4',
            'rock comes from mountain and keeps old memory[young, forgetful, sky]^3',
            'rock breaks wood and protects cave[fragile, bends, exposes]^3',
            'rock can cut when sharp and crush when heavy[dull, harmless, feather]^3',
            'rock patient because it changes slow[fast, restless, soft]^2',
            'rock is sleeping mountain piece in grug hand[awake, cloud, water]^2',
            'small rock throw big rock build[only-small, only-big, no-use]^2',
            'rock under foot can help or trip grug[smooth, certain, harmless]^2',
            'what is rock: rock hard stone from earth[water, soft, fire]^3',
        ]),
        'drop': ['what is rock','what are rocks','describe rock','describe rocks','tell me about rock','tell me about rocks','rock meaning','rock definition','stone','boulder','pebble','mountain'],
        'system_prompt': 'Grug describe rock directly.',
    },
    'water': {
        'action_packet': ' | '.join([
            'water wet and gives drink[dry, poison, empty]^4',
            'water flows downhill and fills bowl[uphill, fixed, scattered]^3',
            'water cleans wound and cools fire[dirty, burns, poison]^3',
            'water feeds fish plant and tribe[starves, barren, hostile]^4',
            'water soft in hand but strong in river[hard, weak, still]^3',
            'water can save thirst or pull grug under[only-safe, shallow, harmless]^3',
            'water falls as rain and runs as river[fire, dust, stone]^2',
            'what is water: water wet life drink[fire, dry, dead]^3',
        ]),
        'drop': ['what is water','describe water','tell me about water','water meaning','water definition','liquid','drink','stream','river','rain'],
        'system_prompt': 'Grug describe water directly.',
    },
    'wolf': {
        'action_packet': ' | '.join([
            'wolf fur teeth and hungry eyes[plant, soft, blind]^4',
            'wolf hunts in pack and listens to pack[alone, scattered, deaf]^4',
            'wolf fast predator that smells fear[slow, prey, dull-nose]^3',
            'wolf fears fire and loud tribe[brave-fire, silence, alone]^3',
            'wolf dangerous near dark edge of camp[harmless, daylight-only, tame]^3',
            'wolf teaches hunter patience and tracks[impatient, random, lost]^2',
            'wolf is hunger with legs and song[full, still, silent]^2',
            'what is wolf: wolf pack hunter with teeth[food, plant, friend]^3',
        ]),
        'drop': ['what is wolf','describe wolf','tell me about wolf','wolf meaning','wolf definition','predator','beast','fang','howl','pack'],
        'system_prompt': 'Grug describe wolf directly.',
    },
    'food': {
        'action_packet': ' | '.join([
            'food fills belly and gives strength[empty, weak, poison]^4',
            'food is meat root fruit and berry[stone, smoke, hunger]^3',
            'food keeps tribe alive tomorrow[starves, kills, yesterday]^4',
            'food shared tastes better than food alone[hoarded, bitter, selfish]^3',
            'food can heal hunger or hurt belly if rotten[fresh-only, safe-rotten, stone]^3',
            'food is earth changed into body strength[sky-only, useless, separate]^2',
            'what is food: food thing tribe eats to live[rock, poison, empty]^3',
        ]),
        'drop': ['what is food','describe food','tell me about food','food meaning','food definition','meal','meat','fruit','root','berry'],
        'system_prompt': 'Grug describe food directly.',
    },
}


def patch_line(line: str) -> str:
    m = re.match(r'^/grow\s+(\S+)\s+(\{.*\})\s*$', line.rstrip('\n'))
    if not m:
        return line
    lobe, payload = m.group(1), m.group(2)
    obj = json.loads(payload)
    pat = obj.get('pattern')

    # The old explanation pattern `tell me` is too broad: it beats exact
    # noun-description aliases for `tell me about fire/rocks`. Keep a generic
    # share-story node, but remove the noun-question surface from its pattern.
    if lobe == 'explanation' and pat == 'tell me':
        obj['pattern'] = 'share story'
        obj['drop_table'] = ['share with me', 'let me know', 'explain to me']
        obj.setdefault('data', {})['system_prompt'] = 'Grug share general story.'
        obj['data']['vote_role'] = 'generic_share_non_noun_question'
        obj['data']['initial_strength'] = 1.0
        return f"/grow {lobe} {json.dumps(obj, ensure_ascii=False, separators=(',', ':'))}\n"

    if lobe != 'knowledge' or pat not in PATCHES:
        return line
    p = PATCHES[pat]
    obj['action_packet'] = p['action_packet']
    obj['drop_table'] = p['drop']
    obj.setdefault('data', {})['system_prompt'] = p['system_prompt']
    # Keep existing NONJITTER/strength on fire/wolf from v16; add to rock/water/food too.
    rr = obj['data'].setdefault('required_relations', [])
    if 'NONJITTER' not in rr:
        rr.append('NONJITTER')
    # Direct noun descriptions are confidence lock-ins: keep >=9 so engine
    # does not soften/remove NONJITTER during scan.
    obj['data']['initial_strength'] = 9.0
    # Add a clear role flag for future diagnostics.
    obj['data']['vote_role'] = 'direct_noun_description'
    return f"/grow {lobe} {json.dumps(obj, ensure_ascii=False, separators=(',', ':'))}\n"


ALIASES = {
    'fire': ['what is fire', 'describe fire', 'tell me about fire'],
    'rock': ['what is rock', 'what are rocks', 'describe rock', 'describe rocks', 'tell me about rock', 'tell me about rocks'],
    'water': ['what is water', 'describe water', 'tell me about water'],
    'wolf': ['what is wolf', 'describe wolf', 'tell me about wolf'],
    'food': ['what is food', 'describe food', 'tell me about food'],
}

# Put exact noun-question aliases in the lobes that previously stole these
# queries. This is intentionally config-only: no engine rule changes. If the
# lobe curve wakes explanation for `tell me about fire`, explanation now has
# the exact direct-answer node; if identity wakes for repeated `what is fire`,
# identity now has the exact direct-answer node too.
PRE_ANCHOR_ALIAS_LOBES = ['knowledge', 'explanation']
POST_ANCHOR_ALIAS_LOBES = ['identity']


def aux_triples_for(noun: str, phrase: str):
    triples = []
    if phrase.startswith('what is '):
        triples.append(['what', 'is', noun])
    elif phrase.startswith('what are '):
        triples.append(['what', 'are', noun])
    elif phrase.startswith('tell me about '):
        triples.append(['tell', 'about', noun])
    elif phrase.startswith('describe '):
        triples.append(['describe', 'targets', noun])
    triples.append([noun, 'is', 'described'])
    return triples


def make_alias_nodes(alias_lobes=None) -> str:
    if alias_lobes is None:
        alias_lobes = PRE_ANCHOR_ALIAS_LOBES + POST_ANCHOR_ALIAS_LOBES
    chunks = []
    chunks.append('')
    chunks.append('# ============================================================================')
    chunks.append('# V17 NOUN-DESCRIPTION ALIAS NODES — exact question surfaces')
    chunks.append('# ============================================================================')
    chunks.append('# Drop tables alone do not always beat exact generic patterns like `tell me`.')
    chunks.append('# These alias nodes make common noun questions exact patterns whose votes are')
    chunks.append('# direct noun-answer candidates: `fire hot and burns wood`, etc.')
    chunks.append('# Aliases are mirrored into active lobes so exact noun answers win')
    chunks.append('# inside whichever lobe the stochastic lobe curve wakes.')
    for noun, phrases in ALIASES.items():
        base = PATCHES[noun]
        for phrase in phrases:
            for lobe in alias_lobes:
                # `me` is a stopword and the built-in generic `tell me`
                # node is strong. For tell-me-about aliases, use a tighter
                # content pattern (`tell about fire`) while keeping the exact
                # user surface in drop_table.
                pattern = phrase.replace('tell me about ', 'tell about ')
                obj = {
                    'pattern': pattern,
                    'action_packet': base['action_packet'],
                    'data': {
                        'system_prompt': base['system_prompt'],
                        'frame_hints': ['exploratory', 'plain'],
                        'voice_register': 'plain',
                        'noun_anchors': [noun, phrase, pattern],
                        'wants_context': False,
                        'aux_triples': aux_triples_for(noun, phrase),
                        'required_relations': ['NONJITTER'],
                        'initial_strength': 10.0,
                        'vote_role': 'direct_noun_description_alias',
                        'alias_lobe': lobe,
                    },
                    'drop_table': [phrase, pattern, noun] + base['drop'],
                }
                chunks.append('/grow ' + lobe + ' ' + json.dumps(obj, ensure_ascii=False, separators=(',', ':')))

    # v7.21c-5: no duplicate tell-about lock-ins. `tell me about <noun>` is
    # handled by core relation extraction plus raw confidence ranking; config
    # should not compensate for side-process weighting.
    return '\n'.join(chunks) + '\n'


def main():
    lines = PATH.read_text().splitlines(keepends=True)
    out = []
    patched = []
    for line in lines:
        new = patch_line(line)
        if new != line:
            m = re.search(r'"pattern":"([^"]+)"', new)
            patched.append(m.group(1) if m else '?')
        out.append(new)
    text = ''.join(out)
    # Insert knowledge/explanation aliases before anchor lobes. Insert identity
    # aliases *after* /newLobe identity exists; otherwise /grow identity is rejected.
    marker = '# ANCHOR LOBES'
    pre_alias = make_alias_nodes(PRE_ANCHOR_ALIAS_LOBES)
    if marker in text:
        text = text.replace(marker, pre_alias + marker)
    else:
        text += pre_alias

    identity_marker = '/newLobe core_rules'
    post_alias = make_alias_nodes(POST_ANCHOR_ALIAS_LOBES)
    if identity_marker in text:
        text = text.replace(identity_marker, post_alias + identity_marker)
    else:
        text += post_alias
    PATH.write_text(text)
    print('patched:', ', '.join(patched))
    print('aliases:', sum(len(v) for v in ALIASES.values()) * (len(PRE_ANCHOR_ALIAS_LOBES) + len(POST_ANCHOR_ALIAS_LOBES)))

if __name__ == '__main__':
    main()
