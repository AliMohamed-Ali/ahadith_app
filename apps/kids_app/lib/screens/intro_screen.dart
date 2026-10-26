import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';

import '../l10n.dart';
import '../widgets/common.dart';
import '../widgets/fanoos.dart';
import '../theme.dart';

/// "تعرّف على الحديث": صفحات قصيرة يشرحها فانوس.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _Slide {
  const _Slide(this.icon, this.color, this.titleAr, this.titleEn, this.bodyAr, this.bodyEn);
  final IconData icon;
  final Color color;
  final String titleAr, titleEn, bodyAr, bodyEn;
}

const _slides = <_Slide>[
  _Slide(Icons.chat_bubble_rounded, AppColors.teal, 'يعني إيه حديث؟', 'What is a hadith?',
      'الحديث هو كلام النبي محمد ﷺ، أو شيء فعله، أو شيء رآه ورضي عنه. نتعلمه عشان نعيش زي ما علّمنا النبي ﷺ.',
      'A hadith is what Prophet Muhammad ﷺ said, did, or saw and approved. We learn it to live the way he taught us.'),
  _Slide(Icons.people_alt_rounded, Color(0xFF7558D6), 'مين الرواة؟', 'Who are the narrators?',
      'الراوي هو الشخص اللي سمع الحديث ونقله لغيره. أول راوٍ غالبًا صحابي، يعني واحد من أصحاب النبي ﷺ اللي شافوه وآمنوا بيه، زي أبي هريرة وعائشة رضي الله عنهما.',
      'A narrator is someone who heard the hadith and passed it on. The first narrator is usually a Companion — someone who met the Prophet ﷺ and believed in him, like Abu Hurayrah and Aishah.'),
  _Slide(Icons.link_rounded, AppColors.coral, 'السند والمتن', 'Chain and text',
      'السند هو سلسلة الرواة اللي نقلوا الحديث واحد ورا التاني. والمتن هو كلام الحديث نفسه.',
      'The isnad is the chain of narrators who passed the hadith one after another. The matn is the words of the hadith itself.'),
  _Slide(Icons.handshake_rounded, AppColors.goldDark, 'يعني إيه متفق عليه؟', 'What does "agreed upon" mean?',
      'لما نقول "متفق عليه" يعني الإمام البخاري والإمام مسلم الاتنين كتبوا الحديث ده في كتبهم، ودول أصح كتب الحديث.',
      '"Agreed upon" means both Imam Bukhari and Imam Muslim recorded this hadith in their books, the most authentic hadith books.'),
  _Slide(Icons.menu_book_rounded, AppColors.navy, 'كتب الحديث', 'Hadith books',
      'العلماء جمعوا الأحاديث في كتب، زي صحيح البخاري وصحيح مسلم. والإمام النووي جمع أربعين حديثًا مهمين اسمهم "الأربعون النووية".',
      'Scholars collected hadiths in books, like Sahih al-Bukhari and Sahih Muslim. Imam an-Nawawi gathered forty important ones called "The Forty Nawawi".'),
];

class _IntroScreenState extends State<IntroScreen> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final last = _page == _slides.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context, 'introTitle'))),
      body: Column(children: [
        Expanded(
          child: PageView.builder(
            controller: _pc,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final s = _slides[i];
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Fanoos(size: 90, mood: FanoosMood.talk),
                    const SizedBox(width: 14),
                    RiseIn(
                      key: ValueKey('ic$i'),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                        child: Icon(s.icon, color: Colors.white, size: 48),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  RiseIn(
                    key: ValueKey('card$i'),
                    delay: 120,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: cardBox(shadow: s.color.withOpacity(.4)),
                      child: Column(children: [
                        Text(ar ? s.titleAr : s.titleEn, textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: s.color)),
                        const SizedBox(height: 10),
                        Text(ar ? s.bodyAr : s.bodyEn, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, height: 1.7)),
                        const SizedBox(height: 14),
                        CopyShareRow(text: '${ar ? s.titleAr : s.titleEn}\n${ar ? s.bodyAr : s.bodyEn}', share: false),
                      ]),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < _slides.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.all(4),
              width: i == _page ? 26 : 10,
              height: 10,
              decoration: BoxDecoration(color: i == _page ? AppColors.teal : AppColors.mintLine, borderRadius: BorderRadius.circular(6)),
            ),
        ]),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: () => last ? Navigator.pop(context) : _pc.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic),
              child: Text(S.of(context, last ? 'introDone' : 'next')),
            ),
          ),
        ),
      ]),
    );
  }
}
