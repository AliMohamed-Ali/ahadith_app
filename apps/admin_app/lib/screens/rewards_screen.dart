import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../ui.dart';

/// إعدادات النجوم العادية والملكية ومستويات فانوس ومتجره.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  late final repo = context.read<ContentRepository>();
  AppConfig? _cfg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    AppConfig c;
    try {
      c = await repo.config().first;
    } catch (_) {
      c = const AppConfig();
    }
    if (mounted) setState(() => _cfg = c);
  }

  RewardsConfig get r => _cfg!.rewards;
  void _setR(RewardsConfig n) => setState(() => _cfg = AppConfig(rewards: n, shop: _cfg!.shop));
  void _setShop(List<ShopItem> s) => setState(() => _cfg = AppConfig(rewards: r, shop: s));

  @override
  Widget build(BuildContext context) {
    if (_cfg == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('النجوم والجوائز')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: () => run(context, () => repo.saveConfig(_cfg!)), child: const Text('حفظ الإعدادات')),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        FormSection(title: 'النجوم العادية', icon: Icons.star_rounded, color: AppColors.goldDark, children: [
          _Stepper(label: 'نجوم لكل لعبة يكسبها الطفل', value: r.perGame, onChanged: (v) => _setR(r.copyWith(perGame: v))),
          _Stepper(label: 'نجوم لكل سؤال «عرفتها»', value: r.perKnow, onChanged: (v) => _setR(r.copyWith(perKnow: v))),
        ]),
        FormSection(title: 'النجوم الملكية 👑', icon: Icons.workspace_premium_rounded, color: AppColors.royal, children: [
          _Rule(label: 'نجمة لكل مستوى يخلّصه', rule: r.level, onChanged: (x) => _setR(r.copyWith(level: x))),
          _Rule(label: 'نجمة لكل كام حديث من التبويبات المفتوحة', rule: r.openTabs, withN: true, onChanged: (x) => _setR(r.copyWith(openTabs: x))),
          _Rule(label: 'نجمة لكل قسم أسئلة يخلّصه', rule: r.section, onChanged: (x) => _setR(r.copyWith(section: x))),
          _Rule(label: 'نجمة لكل مهمة يأكدها الأهل', rule: r.mission, onChanged: (x) => _setR(r.copyWith(mission: x))),
          _Rule(label: 'نجمة لكل شجرة مثمرة (بعد كام مراجعة)', rule: r.tree, withN: true, onChanged: (x) => _setR(r.copyWith(tree: x))),
        ]),
        FormSection(title: 'مستويات فانوس', icon: Icons.emoji_objects_rounded, children: [
          const Text('عدد النجوم المطلوبة لكل مستوى، مفصولة بفاصلة (أول رقم لازم يكون 0).', style: TextStyle(color: Colors.black54)),
          TextFormField(
            initialValue: r.fanoosLevels.join(', '),
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'مثلًا: 0, 3, 6, 10, 16'),
            onChanged: (v) {
              final nums = v.split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toList()..sort();
              if (nums.isNotEmpty && nums.first == 0) _setR(r.copyWith(fanoosLevels: nums));
            },
          ),
        ]),
        FormSection(title: 'متجر فانوس', icon: Icons.storefront_rounded, color: AppColors.coral, children: [
          const Text('السعر = عدد النجوم اللي الطفل لازم يوصلها عشان يفتح العنصر (مش بيتخصم من نجومه).', style: TextStyle(color: Colors.black54)),
          for (var i = 0; i < _cfg!.shop.length; i++) _shopRow(i),
          OutlinedButton.icon(onPressed: _addItem, icon: const Icon(Icons.add_rounded), label: const Text('لون جديد')),
        ]),
      ]),
    );
  }

  Widget _shopRow(int i) {
    final s = _cfg!.shop[i];
    return Row(children: [
      CircleAvatar(radius: 16, backgroundColor: hexColor(s.hex), child: s.kind == 'accessory' ? const Icon(Icons.auto_awesome, size: 16, color: Colors.white) : null),
      const SizedBox(width: 8),
      Expanded(child: Text(s.nameAr, style: const TextStyle(fontWeight: FontWeight.w700))),
      SegmentedButton<String>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: const [ButtonSegment(value: 'normal', label: Text('عادية')), ButtonSegment(value: 'royal', label: Text('ملكية'))],
        selected: {s.currency},
        onSelectionChanged: (v) => _setShop([..._cfg!.shop]..[i] = s.copyWith(currency: v.first)),
      ),
      const SizedBox(width: 6),
      SizedBox(
        width: 60,
        child: TextFormField(
          initialValue: '${s.price}',
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(isDense: true),
          onChanged: (v) {
            final n = int.tryParse(v.trim());
            if (n != null && n >= 0) _setShop([..._cfg!.shop]..[i] = s.copyWith(price: n));
          },
        ),
      ),
      if (s.kind == 'color' && s.id != 'gold')
        IconButton(visualDensity: VisualDensity.compact, color: AppColors.danger, onPressed: () => _setShop([..._cfg!.shop]..removeAt(i)), icon: const Icon(Icons.close_rounded)),
    ]);
  }

  Future<void> _addItem() async {
    final ar = TextEditingController();
    final en = TextEditingController();
    var hex = '#4FA8F0';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('لون جديد لفانوس'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TF(ar, 'الاسم بالعربي'),
              const SizedBox(height: 8),
              TF(en, 'الاسم بالإنجليزي', ltr: true),
              const SizedBox(height: 8),
              ColorField(value: hex, onChanged: (v) => setS(() => hex = v)),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('إضافة'))],
        ),
      ),
    );
    if (ok != true || ar.text.trim().isEmpty) return;
    _setShop([..._cfg!.shop, ShopItem(id: 'c${DateTime.now().millisecondsSinceEpoch}', nameAr: ar.text.trim(), nameEn: en.text.trim(), hex: hex, price: 5)]);
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onChanged, this.min = 0});
  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label)),
        IconButton(onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
        Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        IconButton(onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add_circle_outline_rounded)),
      ]);
}

class _Rule extends StatelessWidget {
  const _Rule({required this.label, required this.rule, required this.onChanged, this.withN = false});
  final String label;
  final RoyalRule rule;
  final bool withN;
  final ValueChanged<RoyalRule> onChanged;
  @override
  Widget build(BuildContext context) => Column(children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(label), value: rule.on, onChanged: (v) => onChanged(RoyalRule(on: v, n: rule.n))),
        if (withN && rule.on) _Stepper(label: '   العدد', value: rule.n, min: 1, onChanged: (v) => onChanged(RoyalRule(on: rule.on, n: v))),
      ]);
}
