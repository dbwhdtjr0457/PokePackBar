"""Disposable native contact sheets; creating them does not imply manual review."""
import argparse
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / 'Sources/PokePackBar/Resources'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--renders', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    reviewed = json.loads((RES/'reviewed-foil.json').read_text())
    cohorts = {
        'reviewed': sorted(reviewed['printings']),
        'stamps': [cid+'#fullArt' for cid in sorted(reviewed['starSheetExclusions'])],
        'cracked': [cid+'#holo' for cid in sorted(json.loads((RES/'cracked-ice-facets.json').read_text())['cards'])],
        'new-mega': [f'me1-{n}#fullArt' for n in [3,22,36,50,60,77,86,94,100,104]]
            + [f'me2-{n}#fullArt' for n in [4,13,41,56,61,84]],
        'new-marks': [f'me2pt5-{n}#{finish}' for n in [66,69,71,72]
                      for finish in ['reverseHolo','patternedReverse']],
    }
    pages = {}
    for cohort, keys in cohorts.items():
        for offset in range(0,len(keys),8):
            subset = keys[offset:offset+8]
            files = [args.renders/(key.replace('#','-')+'.jpg') for key in subset]
            if not all(file.exists() for file in files):
                continue
            sheet = Image.new('RGB',(960,1440),'#101014')
            for panel,file in enumerate(files):
                with Image.open(file) as image:
                    sheet.paste(image.crop((0,0,480,360)),(panel%2*480,panel//2*360))
            filename = f'{cohort}-{offset//8:02d}.jpg'
            sheet.save(args.output/filename,quality=95)
            pages[filename] = subset
    (args.output/'sheets.json').write_text(json.dumps(pages,indent=2))
    print(f'{len(pages)} sheets generated; NOT manual approval')


if __name__ == '__main__':
    main()
