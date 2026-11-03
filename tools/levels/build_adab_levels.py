#!/usr/bin/env python3
"""
يجهّز المستويات من الأول للخامس (الآداب): كل مستوى خريطة جبال، وكل جبل قسم من أقسام
«أحاديث الآداب للأطفال» (tools/levels/adab_kids.txt)، وكل قسم نهر بكل أحاديثه.
تقسيم الأقسام على المستويات مكتوب في الملف نفسه (سطور «== »).

النصوص والراوي والمصدر وسطر «نتعلم» بيتاخدوا من الملف زي ما هما.
اللي بيتعمل هنا: تقسيم الملف، عنوان قصير لكل حديث (من سطر «نتعلم»)، ولعبة الكلمة الناقصة من نص الحديث.

التشغيل:
  python3 tools/levels/build_adab_levels.py
الناتج:
  apps/admin_app/assets/adab_levels.json  (المدير بيستورده من لوحة التحكم)
"""
import json
import random
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/bukhari'))
import build_bukhari as bk  # noqa: E402  (نفس تنظيف الكلمات)

DOC = Path(__file__).resolve().parent / 'adab_kids.txt'
OUT = ROOT / 'apps/admin_app/assets/adab_levels.json'

# شكل كل جبل: إيموجي + لون (برقم القسم في الملف: 1 = الطعام، 2 = الاستئذان، ...)
LOOK = [('🍽️', '#FF8A3D'), ('🚪', '#4FA8F0'), ('🛣️', '#3CC7A8'), ('🕌', '#0E7C74'), ('👕', '#F27BA6'), ('🌙', '#7558D6'),
        ('👋', '#F5B82E'), ('❤️', '#E8573A'), ('💬', '#9B7BEA'), ('🧼', '#4FB3E8'), ('🐱', '#8FBF5A')]
FEMALE = {'عائشة', 'أم سلمة'}
# كلمات ما تنفعش تبقى الكلمة الناقصة (عامة قوي)
WEAK = {'احدكم', 'واليوم', 'الاخر', 'تعالي', 'الرجل'}

LEVEL_EN = ['Level 1', 'Level 2', 'Level 3', 'Level 4', 'Level 5', 'Level 6', 'Level 7']


def parse():
    """بيرجّع (الوصف، المستويات) وكل مستوى فيه أقسامه."""
    desc, levels, cur = '', [], None
    lines = [l.strip() for l in DOC.read_text(encoding='utf-8').splitlines()]
    lines = [l for l in lines if l and not l.startswith('#')]
    i = 0
    while i < len(lines):
        l = lines[i]
        if l.startswith('@desc '):
            # تحت سطر مستوى = كلام المستوى ده، وغير كده الكلام العام
            if levels and not levels[-1]['cats']:
                levels[-1]['desc'] = l[6:].strip()
            else:
                desc = l[6:].strip()
            i += 1
        elif l.startswith('== '):
            name, _, title = l[3:].partition(':')
            levels.append({'name': name.strip(), 'title': title.strip(), 'cats': [], 'desc': ''})
            i += 1
        elif re.match(r'^\d+\.\s', l):
            # رقم القسم ثابت (منه الـ id) حتى لو القسم اتنقل لمستوى تاني
            cur = {'num': int(l.split('.')[0]), 'title': re.sub(r'^\d+\.\s*', '', l), 'note': '', 'items': []}
            levels[-1]['cats'].append(cur)
            i += 1
        elif l.startswith('ومن القرآن'):
            cur['note'] = l
            i += 1
        else:
            text, ref, learn = lines[i], lines[i + 1], lines[i + 2]
            assert ' — ' in ref, f'سطر الراوي — المصدر غلط: {ref}'
            narrator, source = [x.strip() for x in ref.split(' — ', 1)]
            mission = ''
            if i + 3 < len(lines) and lines[i + 3].startswith('مهمة:'):
                mission = lines[i + 3][5:].strip()
                i += 1
            cur['items'].append({'text': text, 'narrator': narrator, 'source': source, 'learn': learn, 'mission': mission})
            i += 3
    return desc, levels


def narrator_gen(name):
    """«عن أبي هريرة رضي الله عنه» للمشاركة."""
    gen = re.sub(r'(^|\s)أبو(\s)', r'\1أبي\2', name)
    if name in FEMALE:
        return f'{gen} رضي الله عنها'
    if name.startswith('ابن ') or name.startswith('عبد الله بن عمرو'):
        return f'{gen} رضي الله عنهما'
    return f'{gen} رضي الله عنه'


def tokens(text):
    return [t for t in re.sub(r'[«»"]', ' ', text).split() if bk.PUNCT.sub('', t)]


def game_for(text, hid, pool):
    """الكلمة الناقصة: أطول كلمة مهمة في أول الحديث (من كلام النبي ﷺ لو موجود بين «»)."""
    quoted = re.findall(r'«([^»]+)»', text)
    core = max(quoted, key=len) if quoted and len(max(quoted, key=len).split()) >= 3 else text
    toks = tokens(core)
    cands = [k for k, t in enumerate(toks[:14]) if len(bk.norm_word(t)) >= 4 and bk.norm_word(t) not in bk.STOP and bk.norm_word(t) not in WEAK and 'ﷺ' not in t]
    if not cands:
        return {'before': '', 'answer': '', 'after': '', 'options': []}
    i = max(cands, key=lambda k: (len(bk.norm_word(toks[k])), -k))
    answer = bk.PUNCT.sub('', toks[i])
    target = bk.norm_word(answer)
    near = {bk.norm_word(t) for t in toks[max(0, i - 3):i + 4]}
    rnd = random.Random(hid)
    options = [w for w in pool.get(len(target), []) + pool.get(len(target) + 1, []) if bk.norm_word(w) not in near]
    rnd.shuffle(options)
    picked = []
    for w in options:
        if bk.norm_word(w) not in {bk.norm_word(p) for p in picked}:
            picked.append(w)
        if len(picked) == 2:
            break
    opts = [answer, *picked]
    rnd.shuffle(opts)
    return {'before': ' '.join(toks[max(0, i - 3):i]), 'answer': answer, 'after': ' '.join(toks[i + 1:i + 4]), 'options': opts}


def short_title(learn, n=30):
    t = re.split(r'[،؛:]', learn)[0].strip()
    return t if len(t) <= n else t[:n].rsplit(' ', 1)[0] + '…'


def main():
    desc, lvls = parse()
    cats = [c for lv in lvls for c in lv['cats']]
    pool = defaultdict(list)
    for c in cats:
        for it in c['items']:
            for t in tokens(it['text']):
                w = bk.PUNCT.sub('', t)
                n = bk.norm_word(w)
                if len(n) >= 4 and n not in bk.STOP and 'ﷺ' not in w:
                    pool[len(n)].append(w)
    for k in pool:
        pool[k] = sorted(set(pool[k]))

    parents, levels, hadiths = [], [], []
    for li, lv in enumerate(lvls):
        pid = f'adab_l{li + 1}'
        first = lv['cats'][0]['num']
        parents.append({
            'id': pid, 'tabId': 'levels', 'nameAr': lv['name'], 'nameEn': LEVEL_EN[li], 'ageAr': lv['title'], 'ageEn': '',
            'color': LOOK[(first - 1) % len(LOOK)][1], 'order': li + 1, 'style': 'mountains', 'icon': '⛰️', 'descAr': lv['desc'] or desc,
        })
        for c in lv['cats']:
            c['parent'] = pid
    for c in cats:
        ci = c['num'] - 1
        lid = f'adab_c{ci + 1:02d}'
        ids = []
        for k, it in enumerate(c['items']):
            hid = f'{lid}_{k + 1:02d}'
            ids.append(hid)
            text = it['text']
            # «...» من الأول للآخر = كلام النبي ﷺ: بيتعرض تحت «قال رسول الله ﷺ». غير كده بيتعرض زي ما هو.
            saying = text.startswith('«') and text.endswith('»') and text.count('«') == 1
            hadiths.append({
                'id': hid,
                'tabId': 'levels',
                'levelId': lid,
                'order': k + 1,
                'titleAr': short_title(it['learn']),
                'titleEn': '',
                'text': text[1:-1].strip() if saying else text,
                'narratorAr': it['narrator'],
                'narratorGenAr': narrator_gen(it['narrator']),
                'sourceAr': f"رواه {it['source']}",
                'isnadInText': not saying,
                'explainAr': it['learn'],
                'missionAr': it['mission'],
                'game': game_for(text, hid, pool),
            })
        icon, color = LOOK[ci % len(LOOK)]
        levels.append({
            'id': lid, 'tabId': 'levels', 'parentId': c['parent'], 'nameAr': c['title'], 'nameEn': '', 'ageAr': '', 'ageEn': '',
            'color': color, 'icon': icon, 'descAr': c['note'], 'order': [x['num'] for x in cats if x['parent'] == c['parent']].index(c['num']) + 1, 'hadithIds': ids,
        })

    out = {
        'source': 'أحاديث الآداب للأطفال — @fatma ali',
        'parents': parents,
        'levels': levels,
        'hadiths': hadiths,
    }
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding='utf-8')
    for p in parents:
        kids = [l for l in levels if l['parentId'] == p['id']]
        print(f"{p['ageAr']}: {p['nameAr']} — " + ' · '.join(f"{l['icon']} {l['nameAr']} ({len(l['hadithIds'])})" for l in sorted(kids, key=lambda x: x['order'])))
    no_game = [h['id'] for h in hadiths if not h['game']['answer']]
    print(f'{len(hadiths)} حديث في {len(levels)} قسم · من غير لعبة: {no_game or "مفيش"}')
    print(f'wrote {OUT}')


if __name__ == '__main__':
    main()
