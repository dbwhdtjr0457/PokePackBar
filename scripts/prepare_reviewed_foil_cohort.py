#!/usr/bin/env python3
"""Convert the manually reviewed cohort to explicit, reproducible recipes.

Photograph-guided fan centres below are approximate scan-space registrations,
not recovered cutting-sheet coordinates. No rarity-wide application occurs.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# Approximate visible centres from each linked specimen, reviewed 2026-09-28.
FANS = {
    23: [[.32,.72,.29],[.83,.725,.25]],
    24: [[.29,.73,.27],[.78,.71,.28],[.54,.41,.35]],
    25: [[.32,.76,.29],[.82,.72,.27]],
    27: [[.28,.735,.28],[.82,.72,.26]],
    28: [[.34,.73,.29],[.80,.73,.28]],
    29: [[.14,.51,.27],[.14,.78,.28]],
    30: [[.40,.32,.38],[.035,.655,.34],[.91,.65,.34]],
    31: [[.39,.565,.23],[.27,.915,.30],[.80,.86,.28],[.89,.56,.23]],
    32: [[.22,.615,.31],[.85,.73,.29]],
    33: [[.49,.325,.36],[.49,.62,.27],[.51,.925,.25]],
    34: [[.51,.365,.34],[.10,.65,.28],[.84,.67,.27]],
    37: [[.23,.835,.25],[.90,.675,.30]],
    38: [[.24,.73,.30],[.80,.69,.27]],
    39: [[.29,.66,.29],[.90,.73,.25],[.31,.99,.25]],
    41: [[.15,.78,.30],[.95,.77,.22],[.17,.44,.28],[.86,.14,.25]],
    42: [[.19,.87,.27],[.96,.76,.25]],
    44: [[.28,.935,.29],[.82,.71,.27]],
    45: [[.34,.355,.25],[.34,.60,.24],[.24,.87,.24],[.88,.22,.26],[.85,.76,.30]],
    46: [[.24,.68,.28],[.84,.64,.26]],
    47: [[.33,.725,.29],[.83,.75,.29]],
    48: [[.09,.415,.30],[.04,.685,.29],[.36,.96,.29]],
    49: [[.06,.42,.28],[.49,.37,.26],[.89,.35,.28],[.78,.06,.28]],
    50: [[.27,.395,.32],[.37,.22,.30],[.77,.11,.30]],
    52: [[.08,.64,.29],[.87,.65,.28]],
}
SILVER = {'107_A','109_A','113_A','114_A','145_A','54_A','60_A','76_A','88_A','93_A','97_A'}
FULL = {'113_A','114_A','54_A','60_A','76_A','97_A'}
# Panels read directly from each original; EX/LV.X rules are not picture boxes.
RULES = {
    '109_A': [[.076,.822,.922,.884]],
    '145_A': [[.08,.803,.918,.866]],
    '54_A': [[.48,.85,.917,.935]],
    '60_A': [[.057,.902,.947,.96]],
    '76_A': [[.48,.849,.905,.935]],
    '88_A': [[.053,.835,.886,.864]],
    '97_A': [[.478,.906,.91,.961]],
}
MATTE = {
    '54_A': [[.057,.561,.949,.845]],
    '60_A': [[.062,.71,.935,.873]],
    '76_A': [[.061,.699,.95,.848]],
    '97_A': [[.057,.535,.95,.905]],
}
STAMP_CENTRES = {
    '107_A': [.86,.477], '109_A': [.13,.413], '113_A': [.87,.518],
    '114_A': [.87,.511], '145_A': [.13,.451], '15_A1': [.88,.518],
    '15_A2': [.867,.534], '15_A3': [.879,.507], '15_A4': [.876,.479], '17_A': [.869,.465],
    '20_A': [.856,.49], '24_A': [.861,.50], '2_A': [.866,.511],
    '4_A': [.868,.51], '54_A': [.136,.49], '60_A': [.886,.491],
    '66_A': [.865,.511], '73_A': [.867,.541], '76_A': [.141,.556],
    '86_A': [.87,.487], '88_A': [.869,.467], '8_A': [.867,.511],
    '93_A': [.868,.47], '97_A': [.866,.481], '9_A': [.131,.469],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('observations', type=Path)
    args = parser.parse_args()
    records = json.loads(args.observations.read_text())
    subjects = json.loads((ROOT / 'scripts/reviewed-subject-regions.json').read_text())
    result = {}
    for row in records:
        cid = row['cardID']
        if row['status'] == 'photo_insufficient' and cid != 'cel25c-15_A2':
            continue
        recipe = dict(finish=row['finish'], referenceURLs=[row['page'], *row['photos']],
                      evidenceStatus=row['status'], observedDifference=row['observations'],
                      reconstruction='Photo-guided procedural approximation. Scan registration is not verification of the factory emboss or foil plate.')
        if cid == 'cel25c-15_A2':
            recipe.update(referenceURLs=[
                'https://www.ebay.co.uk/itm/137608971799',
                'https://i.ebayimg.com/images/g/yo4AAeSwj-Vqexar/s-l1600.webp',
                'https://i.ebayimg.com/images/g/zGwAAeSwDjZqexar/s-l1600.webp'],
                evidenceStatus='additional_front_and_oblique_photos_background_compared',
                observedDifference='Additional front/oblique photographs show fine background fragments distinct from faces, not large white squares over the characters. Exact micro-emboss remains unresolved.')
        if cid.startswith('cel30-'):
            number = int(cid.split('-')[1])
            recipe.update(style='pikachu30', fans=[dict(x=x,y=y,radius=r,phase=round(i*.47+.13,3))
                                                   for i,(x,y,r) in enumerate(FANS.get(number, []))],
                          preserveUnresolvedInterior=number not in FANS,
                          preserveLowerInterior=number in {49,50},
                          preserveArtwork=number == 29,
                          grainInArtwork=number not in {26,35,36,40,43,49,50,51})
        elif cid.startswith('cel25c-'):
            short = cid.split('-')[1]
            recipe.update(style='classic25', silverRim=short in SILVER,
                          stampCentre=STAMP_CENTRES[short],
                          fullArt=short in FULL, subject=cid in subjects,
                          subjectEtching=short not in {'15_A2','76_A','4_A','109_A','145_A','54_A','60_A','73_A','86_A','97_A'},
                          paperEtching=short in {'20_A','8_A'},
                          ruleBoxes=RULES.get(short, []), mattePanels=MATTE.get(short, []))
        elif cid in {'cel30c-1','cel30c-14'}:
            recipe.update(style='classic30', subject=True, subjectEtching=True,
                          stampCentre=[.871,.517] if cid == 'cel30c-1' else [.139,.488],
                          goldStars=cid == 'cel30c-14')
        else:
            raise ValueError(cid)
        result[cid] = recipe
    (ROOT / 'scripts/reviewed-foil-recipes.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(f'{len(result)} explicit recipes; unresolved regions remain labelled, not factory-certified')


if __name__ == '__main__':
    main()
