"""Bundle network marks with transparent outer canvas removed."""
import hashlib, json, re, urllib.request
from pathlib import Path
from svgpathtools import svg2paths
ROOT=Path(__file__).resolve().parents[1]
COMMIT='6dd023ae32415ed7b01bf809f15a25613a52098c'
DEST=ROOT/'assets/wallet/networks'
sources=[]
for name in ('amex','discover','unionpay','jcb','diners'):
    url=f'https://raw.githubusercontent.com/aaronfagan/svg-credit-card-payment-icons/{COMMIT}/logo/{name}.svg'
    data=urllib.request.urlopen(url,timeout=30).read()
    original=ROOT/'tool/design_src/network_logos'/f'{name}.svg'
    original.parent.mkdir(parents=True,exist_ok=True)
    original.write_bytes(data)
    paths,attrs=svg2paths(str(original))
    boxes=[p.bbox() for p in paths if p]
    xmin=min(b[0] for b in boxes); xmax=max(b[1] for b in boxes)
    ymin=min(b[2] for b in boxes); ymax=max(b[3] for b in boxes)
    view=f'{xmin-1:.3f} {ymin-1:.3f} {xmax-xmin+2:.3f} {ymax-ymin+2:.3f}'
    svg=re.sub(r'viewBox="[^"]+"', f'viewBox="{view}"', data.decode())
    svg=re.sub(r'width="[^"]+"', f'width="{xmax-xmin+2:.3f}"', svg, count=1)
    svg=re.sub(r'height="[^"]+"', f'height="{ymax-ymin+2:.3f}"', svg, count=1)
    bundled=svg.encode()
    (DEST/f'{name}.svg').write_bytes(bundled)
    sources.append(dict(name=name,url=url,sha256=hashlib.sha256(data).hexdigest(),
        bundledSha256=hashlib.sha256(bundled).hexdigest(),viewBox=view,
        changes='Crop transparent outer canvas; no path geometry changes.'))
(ROOT/'tool/design_src/network_logos/sources.json').write_text(json.dumps(sources,indent=2)+'\n')
print('\n'.join(f"{x['name']}: {x['viewBox']}" for x in sources))
