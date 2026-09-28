"""Register source-visible angular regions, never overlay a random shard grid.

Segmentation follows the currently shipped photograph. Hidden/overprinted
facets cannot be recovered; derived phase is an optical approximation, not
a measured normal map. Diagnostics must be visually checked before packaging.
"""
import argparse
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT/'Sources/PokePackBar/Resources'
IDS = [f'ex5-{n}' for n in [97,98,99]] + [f'ex6-{n}' for n in [114,115,116]] + [f'pl2-RT{n}' for n in range(1,7)]
OUT = RES/'cracked-ice-facets.json'


def build(output=None):
    originals = json.loads((RES/'card-art.json').read_text())['images']
    geometry = json.loads((RES/'foil-geometry.json').read_text())['cards']
    result = {}
    for cid in IDS:
        entry = originals[cid]
        path = ROOT/'local-assets/CardArt'/entry['file']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256']
        source = Image.open(path).convert('RGB')
        source.thumbnail((720,1000))
        rgb = np.array(source)
        h,w = rgb.shape[:2]
        y,x = np.mgrid[:h,:w]
        box = geometry[cid]['art']
        x1,y1,x2,y2 = box
        artwork = (x > x1*w)&(x < x2*w)&(y > y1*h)&(y < y2*h)
        if cid.startswith('pl2-'):
            # These are reverse-like shards OUTSIDE the image, not ex borders.
            allowed = ~artwork & (x > .026*w)&(x < .973*w)&(y > .015*h)&(y < .983*h)
        else:
            # The blue rules stock is translucent on these ex printings: the
            # photographed shards continue through it, not just the art/rim.
            allowed = np.ones((h,w), dtype=bool)
        # Smooth printing dots, while preserving the large hard angular edges.
        smooth = cv2.pyrMeanShiftFiltering(cv2.medianBlur(rgb,5), 7, 18)
        quantized = (smooth.astype(np.int32)//32)
        labels = quantized[:,:,0]*64 + quantized[:,:,1]*8 + quantized[:,:,2]
        labels[~allowed] = -1
        gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
        # Printed black characters do not become tiny glass facets. Keeping
        # them out of the final polygons also prevents white text washout.
        printed_ink = gray < 65
        shapes = []
        for label in np.unique(labels[labels >= 0]):
            mask = (labels == label).astype('uint8')*255
            mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((3,3),np.uint8))
            contours,_ = cv2.findContours(mask,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
            for c in contours:
                area = cv2.contourArea(c)
                if not w*h*.00045 < area < w*h*.012:
                    continue
                hull_area = cv2.contourArea(cv2.convexHull(c))
                if area/max(1,hull_area) < .84:
                    continue
                simple = cv2.approxPolyDP(c, max(.8,cv2.arcLength(c,True)*.017),True).reshape(-1,2)
                if not 3 <= len(simple) <= 8:
                    continue
                _,_,cw,ch = cv2.boundingRect(c)
                if max(cw,ch)/max(1,min(cw,ch)) > 6:
                    continue
                if 4*np.pi*area/max(1,cv2.arcLength(c,True)**2) > .84:
                    continue
                centre = np.mean(simple,axis=0).astype(int)
                px,py = centre/[w,h]
                if cid.startswith('pl2-') and cid != 'pl2-RT6':
                    # Rounded silver art captions and circular Energy icons.
                    if y2 < py < y2+.028 or (.03 < px < .28 and .62 < py < .71):
                        continue
                    if .89 < py < .97 and .045 < px < .93:
                        continue
                if cid.startswith('ex') and (.032 < px < .964):
                    if .025 < py < y1 or y2 < py < y2+.043:
                        continue
                # Reject solid ink silhouettes with no source-visible shard
                # boundary (yellow Zapdos face/claw and Moltres body).
                if cid == 'ex6-116' and .30 < px < .59 and .30 < py < .40:
                    continue
                if cid == 'ex6-115' and .42 < px < .63 and .245 < py < .39:
                    continue
                color = smooth[centre[1],centre[0]]
                hsv = cv2.cvtColor(np.uint8([[color]]),cv2.COLOR_RGB2HSV)[0,0]
                # One stable phase per contiguous face: it cannot swim or
                # become random noise when pointer position changes.
                phase = (float(hsv[0])/180*6.283185 + centre[0]/w*.73 + centre[1]/h*.37)%6.283185
                facet_mask = np.zeros((h,w), np.uint8)
                cv2.fillPoly(facet_mask,[simple.astype('int32')],255)
                facet_mask[printed_ink | ~allowed] = 0
                clipped,_ = cv2.findContours(facet_mask,cv2.RETR_TREE,cv2.CHAIN_APPROX_SIMPLE)
                regions = [[[round(float(px)/w,6),round(float(py)/h,6)] for px,py in cv2.approxPolyDP(part,.5,True).reshape(-1,2)]
                           for part in clipped if cv2.contourArea(part) >= 4]
                regions = [region for region in regions if len(region) >= 3]
                if not regions:
                    continue
                shapes.append(dict(points=[[round(float(px)/w,6),round(float(py)/h,6)] for px,py in simple],
                                   regions=regions,phase=round(phase,6)))
        # Do not force noisy/curved components into a per-card quota.
        assert len(shapes) >= 12, (cid,len(shapes))
        result[cid] = dict(sha256=entry['sha256'],width=entry['width'],height=entry['height'],
            sourceURL=entry['sourceURL'], coverage='outsideArt' if cid.startswith('pl2-') else 'fullCard',
            art=box, physicalNormalsVerified=False, facets=shapes)
        if output:
            output.mkdir(parents=True,exist_ok=True)
            preview = source.copy()
            draw = ImageDraw.Draw(preview)
            for face in shapes:
                points=[(round(px*w),round(py*h)) for px,py in face['points']]
                draw.line(points+[points[0]],fill='#ff00ff',width=1)
            pair = Image.new('RGB',(w*2,h),'white');pair.paste(source);pair.paste(preview,(w,0))
            pair.save(output/f'{cid}.jpg',quality=94)
        print(cid,len(shapes))
    return dict(version=1,cards=result)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify',action='store_true')
    parser.add_argument('--diagnostics',type=Path)
    args=parser.parse_args()
    data=build(args.diagnostics)
    if args.verify:
        assert data == json.loads(OUT.read_text()),'Stale cracked-ice facets'
    else:
        OUT.write_text(json.dumps(data,sort_keys=True,separators=(',',':'))+'\n')
    print('PASS 12 source-bound facet sets; inferred optics, NOT factory normals')


if __name__ == '__main__':
    main()
