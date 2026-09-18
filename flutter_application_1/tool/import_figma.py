"""Compile saved Figma reference JSX to Flutter layout data and local assets.

No React or CSS is shipped in the application. The intermediate JSON contains
logical-pixel geometry, text runs, decorations and original asset filenames.
Run from the Flutter project: python3 tool/import_figma.py [--download]
"""
import concurrent.futures
import html
from html.parser import HTMLParser
import json
import pathlib
import re
import sys
import subprocess
import urllib.request
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/figma'
DEST.mkdir(parents=True, exist_ok=True)
metadata = {n.attrib['id']: n.attrib for n in ET.parse(ROOT / 'design/figma/metadata.xml').iter() if 'id' in n.attrib}
assets = {}


class Parser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = {'children': []}
        self.stack = [self.root]

    def handle_starttag(self, tag, attrs):
        node = dict(attrs)
        node.update(tag=tag, children=[])
        self.stack[-1]['children'].append(node)
        if tag not in ('img', 'br'):
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in ('img', 'br'):
            self.stack.pop()

    def handle_endtag(self, tag):
        assert self.stack[-1]['tag'] == tag, (tag, self.stack[-1])
        self.stack.pop()

    def handle_data(self, text):
        if text.strip():
            self.stack[-1]['children'].append({'tag': '#text', 'text': text.strip() if '\n' in text else text})


def color(s):
    if s.startswith('#'):
        return int('ff' + s[1:], 16)
    nums = [float(x) for x in re.findall(r'[\d.]+', s)]
    if len(nums) >= 3:
        a = round(nums[3] * 255) if len(nums) == 4 else 255
        return (a << 24) | (int(nums[0]) << 16) | (int(nums[1]) << 8) | int(nums[2])
    return {'white': 0xffffffff, 'black': 0xff000000}.get(s, 0)


def style(classes):
    out = {}
    for c in classes.split():
        m = re.fullmatch(r'(left|top|right|bottom|w|h|size)-\[(-?[\d.]+)(px|%)\]', c)
        if m:
            k, v, unit = m.groups()
            k = {'left': 'x', 'top': 'y', 'w': 'width', 'h': 'height'}.get(k, k)
            if unit == '%':
                k += 'Percent'
            out[k] = float(v)
        elif c in ('left-0', 'top-0', 'right-0', 'bottom-0'):
            out[{'left-0': 'x', 'top-0': 'y', 'right-0': 'right', 'bottom-0': 'bottom'}[c]] = 0
        elif c in ('size-full', 'w-full', 'h-full'):
            if c != 'h-full': out['widthPercent'] = 100
            if c != 'w-full': out['heightPercent'] = 100
        elif c == 'inset-0': out.update(x=0, y=0, widthPercent=100, heightPercent=100)
        elif c.startswith('inset-['):
            v = c[7:-1].split('_')
            if len(v) == 1: v *= 4
            elif len(v) == 2: v = [v[0],v[1],v[0],v[1]]
            out['insets'] = v
        elif c in ('left-1/2', 'right-1/2'):
            out['xPercent' if c == 'left-1/2' else 'rightPercent'] = 50
        elif c == 'left-1/4': out['xPercent'] = 25
        elif c == 'w-px': out['width'] = 1
        elif c == 'h-px': out['height'] = 1
        elif c.startswith('text-['):
            v = c[6:-1]
            if v.endswith('px'): out['fontSize'] = float(v[:-2])
            elif v.startswith(('#', 'rgb')): out['color'] = color(v)
        elif c in ('text-white', 'text-black'): out['color'] = color(c[5:])
        elif c in ('text-center', 'text-right'): out['align'] = c[5:]
        elif c.startswith('bg-['): out['background'] = color(c[4:-1])
        elif c == 'bg-white': out['background'] = color('white')
        elif c.startswith('rounded-['): out['radius'] = float(c[9:-3])
        elif c.startswith('rounded-b-['): out['bottomRadius'] = float(c[11:-3])
        elif c.startswith('rounded-t-['): out['topRadius'] = float(c[11:-3])
        elif c.startswith('rounded-bl-['): out['bottomLeftRadius'] = float(c[12:-3])
        elif c.startswith('rounded-br-['): out['bottomRightRadius'] = float(c[12:-3])
        elif c == 'rounded-full': out['radius'] = 1000
        elif c == 'border': out['borderWidth'] = 1
        elif c in ('border-2', 'border-3'): out['borderWidth'] = int(c[-1])
        elif c in ('border-b', 'border-t', 'border-r'): out['borderSide'] = c[-1]; out['borderWidth'] = 1
        elif c == 'border-l-4': out['borderSide'] = 'l'; out['borderWidth'] = 4
        elif c.startswith('border-['):
            v = c[8:-1]
            if v.endswith('px'): out['borderWidth'] = float(v[:-2])
            else: out['borderColor'] = color(v)
        elif c.startswith('leading-['):
            v = c[9:-1]
            if v not in ('0', 'normal'): out['lineHeight' if v.endswith('px') else 'heightFactor'] = float(v.removesuffix('px'))
        elif c.startswith('tracking-['): out['letterSpacing'] = float(c[10:-3])
        elif c.startswith('font-['): out['fontFamily'] = 'Inter' if 'Inter' in c else 'PlusJakartaSans'
        elif c in ('font-normal', 'font-medium', 'font-semibold', 'font-bold', 'font-extrabold'):
            out['weight'] = {'font-normal': 400, 'font-medium': 500, 'font-semibold': 600, 'font-bold': 700, 'font-extrabold': 800}[c]
        elif c.startswith('opacity-'): out['opacity'] = float(c[8:]) / 100
        elif c == 'overflow-clip': out['clip'] = True
        elif c == '-translate-x-1/2': out['translateX'] = -.5
        elif c == '-translate-x-full': out['translateX'] = -1
        elif c == '-translate-y-1/2': out['translateY'] = -.5
        elif c == 'justify-center': out['centerY'] = True
        elif c == 'line-through': out['strike'] = True
        elif c.startswith('drop-shadow-['):
            nums = re.match(r'drop-shadow-\[(-?[\d.]+)px_(-?[\d.]+)px_([\d.]+)px_(rgba\([^]]+\))\]', c)
            if nums: out['shadow'] = [float(nums[1]), float(nums[2]), float(nums[3]), color(nums[4])]
        elif c.startswith('shadow-['):
            nums = re.match(r'shadow-\[(-?[\d.]+)px_(-?[\d.]+)px_([\d.]+)px_([\d.]+)px_(rgba\([^]]+\))\]', c)
            if nums: out['shadow'] = [float(nums[1]), float(nums[2]), float(nums[3])/2, color(nums[5])]
    if 'size' in out: out['width'] = out['height'] = out.pop('size')
    return out


def convert(n, inherited=None):
    s = style(n.get('classname', ''))
    out = dict(s)
    if 'data-node-id' in n: out['id'] = n['data-node-id']
    st = n.get('data-style', '')
    if 'url(' in st:
        out['asset'] = st.split('url(')[1].split(')')[0].strip('"\'')
    elif 'linear-gradient' in st:
        values = re.findall(r'rgba?\([^)]+\)', st)
        if len(values) >= 2:
            out['gradient'] = [color(v) for v in values[:2]]
            out['gradientAngle'] = float(re.search(r'linear-gradient\(([\d.]+)deg', st)[1])
    if n['tag'] == 'img': out['asset'] = n['src']
    children = n['children']
    is_text = n['tag'] in ('p', 'span') or ('fontSize' in s and all(c['tag'] in ('p', 'span', '#text', 'br') and 'absolute' not in c.get('classname', '') for c in children))
    if is_text:
        runs = []
        for c in children:
            if c['tag'] == '#text': runs.append({'text': c['text']})
            elif c['tag'] == 'br': runs.append({'text': '\n'})
            else:
                child = convert(c, s)
                if c['tag'] == 'p' and runs: runs.append({'text': '\n'})
                for run in child.get('runs', []):
                    runs.append({**{k: v for k, v in child.items() if k not in ('runs', 'id')}, **run})
        out['runs'] = runs
        if 'lineHeight' not in out and 'heightFactor' not in out:
            line = next((r.get('lineHeight') for r in runs if 'lineHeight' in r), None)
            if line: out['lineHeight'] = line
    elif children:
        out['children'] = [convert(c, s) for c in children if c['tag'] != '#text']
    if 'id' in out and out['id'] in metadata:
        m = metadata[out['id']]
        out.setdefault('width', float(m['width']))
        out.setdefault('height', float(m['height']))
    return out


screens = {}
for path in sorted((ROOT / 'design/figma').glob('*.txt')):
    source = path.read_text()
    if 'export default' not in source: continue
    variables = dict(re.findall(r'const (\w+) = "(https://[^"]+)";', source))
    for name, url in variables.items():
        filename = url.rsplit('/', 1)[1]
        assets[filename] = url
        variables[name] = 'assets/figma/' + filename
    jsx = source.split('return (', 1)[1].split('\n  );', 1)[0]
    jsx = re.sub(r'style=\{\{(.*?)\}\}', lambda m: 'data-style="' + html.escape(re.sub(r'\$\{(\w+)\}', lambda x: variables[x[1]], m[1]), quote=True) + '"', jsx, flags=re.S)
    jsx = re.sub(r'src=\{(\w+)\}', lambda m: 'src="' + variables[m[1]] + '"', jsx)
    jsx = re.sub(r'\{`([^`]+)`\}', lambda m: html.escape(m[1]).replace(' ', '&#32;'), jsx)
    parser = Parser()
    parser.feed(jsx)
    node = convert(parser.root['children'][0])
    node['x'] = node['y'] = 0
    node['width'] = 390
    # The UI was designed on an 844 px device; some outer frames crop a few pixels.
    node['height'] = 844
    screens[node['id']] = node

(DEST / 'screens.json').write_text(json.dumps(screens, ensure_ascii=False, separators=(',', ':')))
(ROOT / 'design/figma/assets.json').write_text(json.dumps(assets, indent=2))
print(f'Compiled {len(screens)} screens; {len(assets)} exported assets.')

if '--download' in sys.argv:
    def download(pair):
        name, url = pair
        target = DEST / name
        if target.exists() and target.stat().st_size: return
        subprocess.run(['curl', '-fsSL', '--retry', '2', url, '-o', str(target)], check=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(download, assets.items()))
    for name, url in {
        'PlusJakartaSans.ttf': 'https://raw.githubusercontent.com/google/fonts/main/ofl/plusjakartasans/PlusJakartaSans%5Bwght%5D.ttf',
        'PlusJakartaSans-OFL.txt': 'https://raw.githubusercontent.com/google/fonts/main/ofl/plusjakartasans/OFL.txt',
    }.items():
        subprocess.run(['curl', '-fsSL', '--retry', '2', url, '-o', str(ROOT / 'fonts' / name)], check=True)
    from fontTools.ttLib import TTFont
    from fontTools.varLib.instancer import instantiateVariableFont
    for weight, name in [(400,'Regular'),(500,'Medium'),(600,'SemiBold'),(700,'Bold'),(800,'ExtraBold')]:
        font = instantiateVariableFont(TTFont(ROOT / 'fonts/PlusJakartaSans.ttf'), {'wght': weight}, inplace=True, updateFontNames=True)
        font.save(ROOT / f'fonts/PlusJakartaSans-{name}.ttf')
    print('Downloaded original assets and generated licensed static font weights.')
