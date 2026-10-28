#!/usr/bin/env python3
"""
يجهّز صحيح البخاري للأطفال من مدوّنة LK Hadith Corpus (جامعة ليدز وجامعة الملك سعود)،
وجزء البخاري فيها مراجَع يدويًا والسند مفصول عن المتن:
https://github.com/ShathaTm/LK-Hadith-Corpus

اللي بيعمله:
  1. يشيل المكرر (نفس المتن بأسانيد مختلفة) ويسيب أول مرة جه فيها الحديث.
  2. يعلّم الأحاديث اللي محتاجة مراجعة قبل ما تظهر لطفل (كتب معينة + كلمات معينة).
  3. يوزّع الأحاديث على الأعمار من 4 لـ 12: القصير والسهل للصغير.
  4. يقسّم كل سن لدروس، كل درس 10 أحاديث بترتيب البخاري.
  5. يعمل لعبة "الكلمة الناقصة" من نص الحديث نفسه (من غير أي كلام من عندنا).

التشغيل:
  python3 tools/bukhari/build_bukhari.py
الناتج:
  apps/admin_app/assets/bukhari_kids.json  (المدير بيستورده من لوحة التحكم)
"""
import csv
import json
import random
import re
import sys
import urllib.request
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CACHE = Path(__file__).resolve().parent / '.cache'
OUT = ROOT / 'apps/admin_app/assets/bukhari_kids.json'
SRC = 'https://raw.githubusercontent.com/ShathaTm/LK-Hadith-Corpus/master/Bukhari/Chapter{}.csv'

AGES = list(range(4, 13))
# نصيب كل سن (الصغير أقل)
AGE_WEIGHTS = [.45, .6, .75, .9, 1.0, 1.15, 1.3, 1.4, 1.45]
LESSON = 10
AR_DIGITS = str.maketrans('0123456789', '٠١٢٣٤٥٦٧٨٩')

# كتب كاملة محتاجة مراجعة قبل ما تظهر لطفل
REVIEW_BOOKS = {5, 6, 67, 68, 86, 87, 88, 89, 90}
# كلمات لو موجودة في المتن يتعلّم الحديث "محتاج مراجعة" (بعد شيل التشكيل)
REVIEW_WORDS = ['جامع', 'الجماع', 'يجامع', 'الزنا', 'زني', 'يزني', 'الحيض', 'حائض', 'المني', 'فرج', 'عوره', 'الرجم', 'رجم', 'نكح', 'ينكح', 'جنابه', 'جنب', 'ثدي', 'الخنزير', 'السكران', 'لواط']
# كتب أسهل للصغار، وكتب فقهية أصعب
EASY_BOOKS = {1, 2, 3, 59, 60, 61, 62, 70, 75, 78, 79, 80, 81, 82}
HARD_BOOKS = {25, 26, 27, 28, *range(34, 51), 52, 53, 54, 55, 57, 58, 64, 65, 85, 93, 95, 96}

STOP = set('''الله رسول النبي صلي عليه وسلم قال فقال قالت يقول سمعت كان كانت الذي التي الذين هذا هذه ذلك تلك فلما ثم حتي اذا اذ قد لقد علي عن من الي في ان انه انها ولا لا ما لم لن او ام بل هو هي هم انت انا نحن كل بعض عند مع بين يا ايها رضي عنهما عنها عنه وهو وهي فان وان قيل'''.split())

DIAC = re.compile(r'[ؐ-ًؚ-ٰٟۖ-ۭـ]')
PUNCT = re.compile(r'[،,.؛;:؟?!«»"()\[\]\-ـ‏‎]')


def norm_word(w):
    w = DIAC.sub('', w)
    w = PUNCT.sub('', w)
    w = re.sub('[إأآا]', 'ا', w).replace('ى', 'ي').replace('ة', 'ه')
    return w


def norm_words(text):
    t = DIAC.sub('', text).replace('صلى الله عليه وسلم', ' ')
    t = re.sub('[إأآا]', 'ا', t).replace('ى', 'ي').replace('ة', 'ه')
    t = re.sub(r'[^ء-ي\s]', ' ', t)
    return t.split()


def clean_text(t):
    t = t.replace('‏', ' ').replace('صلى الله عليه وسلم', 'ﷺ')
    t = re.sub(r'\s+', ' ', t).strip()
    return re.sub(r'\s+([،.؟!:])', r'\1', t)


def fetch():
    CACHE.mkdir(exist_ok=True)
    rows = []
    for i in range(1, 98):
        f = CACHE / f'Chapter{i}.csv'
        if not f.exists():
            print(f'downloading book {i}…', file=sys.stderr)
            urllib.request.urlretrieve(SRC.format(i), f)
        with open(f, encoding='utf-8-sig') as fh:
            section = ''
            for r in csv.DictReader(fh):
                if r['Section_Arabic'].strip() not in ('', 'nan'):
                    section = r['Section_Arabic'].strip()
                label = re.sub(r'\.0$', '', r['Hadith_number'].strip())
                rows.append({
                    'book': i,
                    'bookAr': r['Chapter_Arabic'].strip(),
                    'bookEn': r['Chapter_English'].strip(),
                    'section': section,
                    # بعض الأرقام مدموجة زي "408-409": ناخد الأول للترتيب ونسيب الكامل للعرض
                    'no': int(re.match(r'\d+', label).group()),
                    'label': label,
                    'isnad': r['Arabic_Isnad'].strip(),
                    'matn': r['Arabic_Matn'].strip(),
                    'en': r['English_Matn'].strip(),
                })
    rows.sort(key=lambda r: r['no'])
    # فيه أرقام قليلة عليها أكتر من رواية: الأولى bk0220 والتانية bk0220b وهكذا
    seen = defaultdict(int)
    for r in rows:
        k = seen[r['no']]
        seen[r['no']] += 1
        r['key'] = f"bk{r['no']:04d}" + ('' if k == 0 else chr(97 + k))
    return rows


def dedupe(rows):
    """يجمّع الأحاديث المكررة (نفس المتن تقريبًا). بيرجّع لكل حديث رقم المجموعة."""
    words = [set(norm_words(r['matn'])) for r in rows]
    df = defaultdict(int)
    for ws in words:
        for w in ws:
            df[w] += 1
    index = defaultdict(list)
    for i, ws in enumerate(words):
        for w in ws:
            if df[w] < 150 and len(w) > 2:
                index[w].append(i)
    parent = list(range(len(rows)))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for i, ws in enumerate(words):
        # متن قصير جدًا زي "مثله" أو "نحوه" = تكرار للي قبله
        if len(ws) < 4 and i > 0:
            parent[find(i)] = find(i - 1)
            continue
        shared = defaultdict(int)
        for w in ws:
            if df[w] < 150 and len(w) > 2:
                for j in index[w]:
                    if j < i:
                        shared[j] += 1
        for j, n in shared.items():
            if n < 2:
                continue
            a, b = ws, words[j]
            inter = len(a & b)
            jac = inter / len(a | b)
            cont = inter / min(len(a), len(b))
            # الحدود دي بتطلّع حوالي 2600 حديث، قريب من عدد أحاديث البخاري من غير تكرار عند العلماء (حوالي 2602)
            if jac >= .35 or (cont >= .6 and min(len(a), len(b)) >= 5):
                parent[find(i)] = find(j)
    return [find(i) for i in range(len(rows))]


def needs_review(r):
    if r['book'] in REVIEW_BOOKS:
        return True
    ws = set(norm_words(r['matn']))
    return any(w in ws or ('و' + w) in ws or ('ف' + w) in ws for w in REVIEW_WORDS)


def difficulty(r):
    n = len(norm_words(r['matn']))
    f = .75 if r['book'] in EASY_BOOKS else (1.35 if r['book'] in HARD_BOOKS else 1)
    return n * f


def make_game(text, no, pool):
    """الكلمة الناقصة: كلمة من الحديث + 3 كلمات قبلها و3 بعدها + اختيارين غلط."""
    rnd = random.Random(no)
    seg = text
    # كلام النبي ﷺ في المدوّنة بيبقى بين علامات RLM (ساعات معاها ")
    m = re.search(r'\u200f\s*"?\s*\u200f(.+?)(\u200f|$)', text)
    if m and len(m.group(1).split()) >= 6:
        seg = m.group(1)
    toks = clean_text(seg).split()
    cands = [i for i, t in enumerate(toks[:15]) if len(norm_word(t)) >= 4 and norm_word(t) not in STOP and 'ﷺ' not in t]
    if not cands:
        cands = [i for i, t in enumerate(toks) if len(norm_word(t)) >= 4 and norm_word(t) not in STOP and 'ﷺ' not in t]
    if not cands:
        return None
    i = rnd.choice(cands)
    answer = PUNCT.sub('', toks[i])
    before = ' '.join(toks[max(0, i - 3):i])
    after = ' '.join(toks[i + 1:i + 4])
    near = {norm_word(t) for t in toks[max(0, i - 3):i + 4]}
    an = norm_word(answer)
    options = [w for w in pool.get(len(an), []) if norm_word(w) != an and norm_word(w) not in near]
    rnd.shuffle(options)
    picked = []
    for w in options:
        if norm_word(w) not in {norm_word(p) for p in picked}:
            picked.append(w)
        if len(picked) == 2:
            break
    if len(picked) < 2:
        return None
    opts = [answer, *picked]
    rnd.shuffle(opts)
    return {'before': before, 'answer': answer, 'after': after, 'options': opts}


def short_title(s, n=70):
    s = clean_text(s)
    if len(s) <= n:
        return s
    cut = s[:n].rsplit(' ', 1)[0]
    return cut + '…'


def main():
    rows = fetch()
    groups = dedupe(rows)
    members = defaultdict(list)
    for r, g in zip(rows, groups):
        members[g].append(r)

    keep = []
    for g, ms in members.items():
        # أول رواية مناسبة ومش مجرد جزء صغير، وإلا أول واحدة
        ok = [m for m in ms if not needs_review(m)] or ms
        rep = next((m for m in ok if len(norm_words(m['matn'])) >= 6), ok[0])
        rep = dict(rep, repeats=sorted({m['label'] for m in ms if m is not rep}), review=needs_review(rep))
        keep.append(rep)
    keep.sort(key=lambda r: r['no'])

    # مخزن كلمات للاختيارات الغلط، متقسم بطول الكلمة
    pool = defaultdict(list)
    for r in keep:
        for t in clean_text(r['matn']).split()[:20]:
            w = PUNCT.sub('', t)
            n = norm_word(w)
            if len(n) >= 4 and n not in STOP and 'ﷺ' not in w:
                pool[len(n)].append(w)
    for k in pool:
        pool[k] = sorted(set(pool[k]))

    # توزيع على الأعمار حسب الصعوبة
    ordered = sorted(keep, key=difficulty)
    total = len(ordered)
    bounds, acc = [], 0
    for wgt in AGE_WEIGHTS:
        acc += wgt
        bounds.append(round(total * acc / sum(AGE_WEIGHTS)))
    age_of = {}
    start = 0
    for age, end in zip(AGES, bounds):
        for r in ordered[start:end]:
            # المحتاج مراجعة ميظهرش لأقل من 10 سنين حتى لو اتوافق عليه
            age_of[r['key']] = max(age, 10) if r['review'] else age
        start = end

    hadiths, levels = [], []
    stats = {}
    for age in AGES:
        items = sorted([r for r in keep if age_of[r['key']] == age], key=lambda r: r['no'])
        chunks = [items[i:i + LESSON] for i in range(0, len(items), LESSON)]
        if len(chunks) > 1 and len(chunks[-1]) < 4:
            chunks[-2].extend(chunks.pop())
        stats[age] = {'hadiths': len(items), 'lessons': len(chunks), 'review': sum(r['review'] for r in items)}
        for u, chunk in enumerate(chunks, 1):
            lid = f'bk_a{age:02d}_u{u:03d}'
            ids = [r['key'] for r in chunk]
            levels.append({
                'id': lid,
                'tabId': 'bukhari',
                'nameAr': f'الدرس {str(u).translate(AR_DIGITS)}',
                'nameEn': f'Lesson {u}',
                'ageAr': chunk[0]['bookAr'],
                'ageEn': chunk[0]['bookEn'],
                'color': '#9B7BEA',
                'order': age * 1000 + u,
                'ageYear': age,
                'hadithIds': ids,
            })
            for k, r in enumerate(chunk):
                game = make_game(r['matn'], r['no'], pool)
                hadiths.append({
                    'id': r['key'],
                    'tabId': 'bukhari',
                    'levelId': lid,
                    'order': k + 1,
                    'ageYear': age,
                    'bukhariNo': r['no'],
                    'status': 'review' if r['review'] else 'auto',
                    'repeats': r['repeats'],
                    'titleAr': short_title(r['section']) or r['bookAr'],
                    'titleEn': '',
                    'text': clean_text(r['matn']),
                    'isnadAr': clean_text(r['isnad']),
                    'translationEn': r['en'],
                    'sourceAr': f"صحيح البخاري، {r['bookAr']}، رقم {r['label']}",
                    'sourceEn': f"Sahih al-Bukhari, {r['bookEn']}, no. {r['label']}",
                    'isnadInText': True,
                    'game': game or {'before': '', 'answer': '', 'after': '', 'options': []},
                })

    out = {
        'source': 'LK Hadith Corpus (University of Leeds & King Saud University) — https://github.com/ShathaTm/LK-Hadith-Corpus',
        'tab': {'id': 'bukhari', 'nameAr': 'صحيح البخاري', 'nameEn': 'Sahih al-Bukhari', 'type': 'hadith', 'mode': 'ages', 'place': 'home', 'color': '#7558D6', 'visible': True, 'order': 4, 'system': True},
        'stats': stats,
        'levels': levels,
        'hadiths': hadiths,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(f'source rows: {len(rows)}  unique: {len(keep)}  review: {sum(r["review"] for r in keep)}  no game: {sum(1 for h in hadiths if not h["game"]["answer"])}')
    for age, s in stats.items():
        print(f'  age {age:2d}: {s["hadiths"]:4d} hadiths, {s["lessons"]:3d} lessons, {s["review"]:3d} need review')
    print(f'wrote {OUT} ({OUT.stat().st_size // 1024} KB)')


if __name__ == '__main__':
    main()
