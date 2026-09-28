#!/usr/bin/env python3
"""Freeze reviewed image silhouettes, not claims about manufacturing plates.

Input is the disposable proposal JSON from inspect_reviewed_regions.py. Only
the explicit allowlist below is accepted. Known segmentation mistakes are
replaced here; this tool never approves an arbitrary Vision result.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPROVED = {
    'cel25c-107_A', 'cel25c-109_A', 'cel25c-145_A', 'cel25c-15_A1',
    'cel25c-15_A2', 'cel25c-15_A3', 'cel25c-15_A4', 'cel25c-17_A', 'cel25c-20_A',
    'cel25c-24_A', 'cel25c-2_A', 'cel25c-4_A', 'cel25c-54_A',
    'cel25c-60_A', 'cel25c-66_A', 'cel25c-73_A', 'cel25c-76_A',
    'cel25c-86_A', 'cel25c-88_A', 'cel25c-8_A', 'cel25c-97_A',
    'cel25c-9_A', 'cel30c-1', 'cel30c-14',
}

# Manually traced normalized scan coordinates. Cleffa's chair/yarn must not be
# marked as its body. Mewtwo's energy sphere must remain in the foil background.
REPLACEMENTS = {
    'cel25c-20_A': [[
        [.279,.296],[.298,.283],[.338,.267],[.385,.252],[.42,.234],
        [.472,.216],[.504,.214],[.519,.226],[.518,.238],[.544,.239],
        [.6,.249],[.612,.263],[.605,.288],[.584,.316],[.602,.339],
        [.595,.364],[.595,.385],[.6,.393],[.596,.41],[.58,.424],
        [.56,.429],[.527,.434],[.482,.435],[.478,.44],[.447,.441],
        [.422,.436],[.408,.43],[.385,.432],[.366,.423],[.353,.406],
        [.351,.375],[.352,.344],[.321,.337],[.297,.328],[.282,.314],
    ]],
    'cel25c-54_A': [
        [[.649,.029],[.688,.03],[.713,.055],[.738,.102],[.874,.111],
         [.948,.067],[.978,.058],[.999,.069],[.999,.198],[.953,.26],
         [.897,.315],[.835,.368],[.782,.382],[.715,.358],[.653,.339],
         [.62,.321],[.604,.3],[.616,.212],[.636,.127]],
        [[.103,.119],[.192,.102],[.273,.099],[.492,.134],[.632,.183],
         [.619,.277],[.573,.282],[.451,.26],[.325,.202],[.204,.183],
         [.147,.153],[.105,.148]],
        [[.057,.337],[.121,.367],[.274,.399],[.464,.433],[.572,.461],
         [.611,.488],[.606,.516],[.584,.534],[.551,.546],[.498,.545],
         [.43,.528],[.257,.48],[.107,.422],[.074,.386]],
    ],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('proposals', type=Path)
    args = parser.parse_args()
    proposals = json.loads(args.proposals.read_text())
    originals = json.loads((ROOT / 'Sources/PokePackBar/Resources/card-art.json').read_text())['images']
    out = ROOT / 'scripts/reviewed-subject-regions.json'
    # Additional individually reviewed cohorts have their own importer. A
    # rebuild of the original cohort must not erase those registrations.
    result = json.loads(out.read_text()) if out.exists() else {}
    for cid in sorted(APPROVED):
        record = proposals[cid]
        assert record['sha256'] == originals[cid]['sha256'], cid
        contours = REPLACEMENTS.get(cid, record['subject'])
        note = 'Manually inspected scan silhouette; material assignment is separate.'
        if cid == 'cel30c-14':
            contours += [[[.727,.51],[.748,.505],[.759,.487],[.801,.468],
                          [.782,.436],[.757,.401],[.738,.381],[.799,.353],
                          [.879,.328],[.879,.355],[.805,.382],[.784,.389],
                          [.805,.433],[.808,.455],[.774,.481],[.762,.509]]]
            note += ' Missing zigzag tail added manually.'
        if cid == 'cel25c-76_A':
            note = 'Conservative protected print region includes attack lettering; NOT a body-only segmentation or emboss plate.'
        result[cid] = dict(sha256=record['sha256'], subject=contours, note=note,
                           physicalPlateVerified=False)
    out.write_text(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(',', ':')) + '\n')
    print(f'{len(result)} reviewed image registrations; physical plate NOT certified')


if __name__ == '__main__':
    main()
