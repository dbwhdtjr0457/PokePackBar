"""Freeze the 30 individually inspected official references (2026-09-28).

JP reference materials are reconstructed on EN source geometry. Static scans
do not certify factory emboss maps, language equivalence, or angular BRDF.
The proposal allowlist below was inspected before this importer was authored.
"""
import argparse
import json
from pathlib import Path

from build_reviewed_foil import raster, polygons, rect
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OBSERVATIONS = {
    1: 'Gold fragmented outer rim; confetti behind Charizard, fine lines on body; attack panel not confetti.',
    2: 'Delcatty and foreground flowers differ from confetti in blue background; silver description panel stays smooth.',
    3: 'Background flecks and fine body lines; printed diagonal lower panel is not a second all-face foil plate.',
    4: 'Genesect body has fine curved lines; lightning/background and irregular frame contain fragments; green attack panel is smooth.',
    5: 'Misty and ribbon are protected from background confetti; metallic trainer frame differs from gold outer rim.',
    6: 'Tyranitar line texture distinct from red fractured background; dark lower attacks are not confetti.',
    7: 'Sneasel body lines differ from star/confetti background; dark lower panel is smooth.',
    8: 'Both Pokemon have fine line texture; background and blue GX strip have fragments; retain yellow tag framing.',
    9: 'Landscape BREAK: gold body and water rings differ from silver/confetti gaps; heading and rule box are printed.',
    10: 'Uxie body lines; sparse stars and dense background fragments; purple attacks are smooth.',
    11: 'Crobat wings/body exclude background confetti; trainer portrait and lower attacks stay printed.',
    12: 'Amazing paint splash continues below picture frame; Raikou body has lines, yellow paper is not confetti.',
    13: 'Buzzwole body lines; confetti continues behind attacks and GX strip; gold rim follows angular layout.',
    14: 'Pikachu body/tail have fine lines; background confetti and stars; cream attacks remain smooth.',
    15: 'Jigglypuff body lines, pink confetti background, silver lower paper distinct; trainer portrait stays printed.',
    16: 'Rayquaza gloss/body separate from background confetti; lower brown attacks mainly smooth; rule tab foil.',
    17: 'Solgaleo lines; full-art fragments around body and GX strip; printed white bottom bars protected.',
    18: 'Gengar body fine lines, eyes and background visibly fragmented; purple attacks remain smooth.',
    19: 'LEGEND upper half: Darkrai silhouette distinct from scattered blue background fragments; landscape source rotates.',
    20: 'LEGEND lower half: Cresselia/ribbons have lines; fragments continue behind attacks; landscape source rotates.',
    21: 'N: fragments visibly cross hat/clothing and full background, so no universal subject cutout.',
    22: 'Palkia body line texture; red background fragments; cyan attack panel smooth; LV.X rule tab foil.',
    23: 'Mega Gardevoir: body lines, background fragments, attack lettering and both rule tabs reflective; pink attack panel smoother.',
    24: 'Shining Celebi: pink background has confetti unlike original Neo subject-only printing; green lower paper distinct.',
    25: 'Scizor body lines; blue background fragments; diagonal printed lower panel not confetti.',
    26: 'Mew VMAX: confetti visibly crosses pink body as well as background; do not exclude all Pokemon silhouettes.',
    27: 'Arceus body lines; background and VSTAR power strip fragmented; white bottom and name bars distinct.',
    28: 'Zacian and sword have fine lines; background fragments; black V-rule footer is not confetti.',
    29: 'Lugia body lines, picture and lower silver panel fragments; wide e-reader gold margin differs from narrow rims.',
    30: 'Magikarp illustration has distributed fragments/stars across full art; use fine low-strength lines without invented body plate.',
}
FULL = {4,8,9,13,16,17,19,20,21,23,26,27,28,30}
NO_SUBJECT = {21,26,30}
CENTRES = {1:(.88,.49),2:(.88,.43),3:(.88,.43),4:(.88,.49),5:(.88,.53),6:(.88,.43),
    7:(.13,.49),8:(.88,.50),9:(.69,.08),10:(.88,.48),11:(.88,.34),12:(.88,.46),
    13:(.88,.44),14:(.14,.49),15:(.88,.46),16:(.13,.48),17:(.88,.45),18:(.13,.48),
    19:(.68,.08),20:(.92,.48),21:(.88,.55),22:(.88,.48),23:(.13,.53),24:(.88,.49),
    25:(.88,.43),26:(.88,.53),27:(.13,.48),28:(.88,.55),29:(.13,.48),30:(.88,.55)}
MATTE = {4:[[.055,.548,.94,.833]], 9:[[.04,.056,.135,.946]],
    16:[[.05,.535,.95,.86]],23:[[.05,.686,.95,.835]],28:[[.06,.90,.95,.976]],
    27:[[.065,.876,.935,.969]],17:[[.06,.866,.94,.902]],8:[[.06,.872,.94,.911]]}
RULES = {4:[[.49,.844,.93,.917]],16:[[.49,.873,.94,.94]],22:[[.084,.815,.94,.877]],
    23:[[.12,.623,.88,.672],[.49,.875,.93,.94]]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('references', type=Path)
    parser.add_argument('proposals', type=Path)
    args = parser.parse_args()
    references = json.loads(args.references.read_text())
    proposed = json.loads(args.proposals.read_text())
    subjects_path = ROOT/'scripts/reviewed-subject-regions.json'
    subjects = json.loads(subjects_path.read_text())
    for n in range(1,31):
        cid = f'cel30c-{n}'
        if n in NO_SUBJECT or n in {1,14}:
            continue
        value = proposed[cid]
        mask = raster(value['subject'],(1400,1000))
        # BREAK's proposal included the entire heading. This is not body foil.
        if n == 9:
            mask[:, :145] = 0
        # Full-art foreground proposals include small pieces of printed bars.
        if n in {8,13,17,27,28}:
            mask[round(1400*({8:.72,13:.72,17:.75,27:.70,28:.87}[n])):] = 0
        subjects[cid] = dict(sha256=value['sha256'], subject=polygons(mask),
            note='Individually inspected source silhouette; conservative foreground protection, not a recovered emboss plate.',
            physicalPlateVerified=False)
    subjects_path.write_text(json.dumps(subjects,sort_keys=True,separators=(',',':'))+'\n')
    additions = {}
    for n, note in OBSERVATIONS.items():
        cid = f'cel30c-{n}'
        ref = references[cid]
        recipe = dict(style='classic30',finish='celebrationsClassic', referenceURLs=[ref['page'],*ref['photos']],
            evidenceStatus='individual_official_JP_static_reference_compared_to_EN_source', observedDifference=note,
            reconstruction='Observed region/material reconstruction on EN scan geometry; JP static image is not proof of identical language plates or measured angular response.',
            fullArt=n in FULL, subject=n not in NO_SUBJECT, subjectEtching=n not in {3,16,21,26,30},
            stampCentre=CENTRES[n], goldStars=True, backgroundStars=True,
            mattePanels=MATTE.get(n,[]),ruleBoxes=RULES.get(n,[]))
        if n in {21,26,30}:
            recipe['fullArtEtching'] = True
        if n == 29:
            recipe['extraFoilBoxes'] = [[.16,.505,.948,.918]]
        if n == 12:
            recipe['artExtension'] = [[[.081,.448],[.928,.448],[.83,.499],[.68,.541],
                [.465,.587],[.295,.59],[.528,.556],[.191,.58],[.49,.525],[.17,.54],[.345,.493],[.09,.52]]]
        additions[cid] = recipe
    (ROOT/'scripts/reviewed-classic30-recipes.json').write_text(json.dumps(additions,ensure_ascii=False,indent=2)+'\n')
    print('30 individually inspected Classic30 recipes; 25 new silhouette registrations; factory plates not certified')


if __name__ == '__main__':
    main()
