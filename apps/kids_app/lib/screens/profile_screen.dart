import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/cities.dart';
import '../l10n.dart';
import '../state/progress_store.dart';
import '../widgets/animated_dropdown.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/parent_gate.dart';
import '../theme.dart';
import 'leaderboard_screen.dart';

/// ملف الطفل — محفوظ على الجهاز فقط (الصورة لا تُرفع أبدًا).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _area = TextEditingController();
  int _age = 6;
  int _city = -1;
  String _avatar = 'cat';
  String _photo = '';
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _fill(context.read<ProgressStore>().profile);
  }

  void _fill(KidProfile? p) {
    _name.text = p?.name ?? '';
    _area.text = p?.area ?? '';
    _age = p?.age ?? 6;
    _city = p?.city ?? -1;
    _avatar = p?.avatar ?? 'cat';
    _photo = p?.photoPath ?? '';
    _editing = p == null;
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 600, maxHeight: 600, imageQuality: 80, preferredCameraDevice: CameraDevice.front);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      final path = await context.read<ProgressStore>().storePhoto(bytes);
      setState(() => _photo = path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context, 'photoError'))));
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(S.of(context, 'nameRequired'))));
      return;
    }
    context.read<ProgressStore>().saveProfile(KidProfile(
          name: name.length > 20 ? name.substring(0, 20) : name,
          age: _age,
          avatar: _avatar,
          city: _city,
          area: _area.text.trim().length > 30 ? _area.text.trim().substring(0, 30) : _area.text.trim(),
          photoPath: _photo,
        ));
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(S.of(context, 'profileSaved'))));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProgressStore>();
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        Text(S.of(context, 'profileTitle'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _editing ? _form(context) : _summary(context, p),
        const SizedBox(height: 18),
        _settings(context, p),
      ]),
    );
  }

  Widget _summary(BuildContext context, ProgressStore p) {
    final ar = S.ar(context);
    final cfg = context.watch<AppConfig>().rewards;
    final prof = p.profile!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardBox(radius: 30),
      child: Column(children: [
        ProfileFace(profile: prof, size: 110),
        const SizedBox(height: 8),
        Text(prof.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        Text(
          [S.of(context, 'ageYears', {'n': arNum(prof.age, arabic: ar)}), if (prof.city >= 0) cityName(prof.city, ar), if (prof.area.isNotEmpty) prof.area].join(' · '),
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [StarPill(count: p.normalStars(cfg)), StarPill(count: p.royalStars(cfg), royal: true)]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _fill(p.profile);
              _editing = true;
            }),
            icon: const Icon(Icons.edit_rounded),
            label: Text(S.of(context, 'edit')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.navy, minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
            icon: const Icon(Icons.emoji_events_rounded),
            label: Text(S.of(context, 'leaderboard')),
          ),
        ]),
      ]),
    );
  }

  Widget _form(BuildContext context) {
    final ar = S.ar(context);
    final previewProfile = KidProfile(name: _name.text, avatar: _avatar, photoPath: _photo);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardBox(radius: 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: ProfileFace(profile: previewProfile, size: 110)),
        const SizedBox(height: 10),
        if (!kIsWeb)
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            FilledButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_rounded), label: Text(S.of(context, 'takePhoto'))),
            OutlinedButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_rounded), label: Text(S.of(context, 'fromGallery'))),
            if (_photo.isNotEmpty)
              TextButton.icon(onPressed: () => setState(() => _photo = ''), icon: const Icon(Icons.delete_outline_rounded), label: Text(S.of(context, 'removePhoto'))),
          ]),
        const SizedBox(height: 6),
        Text(S.of(context, 'photoPrivate'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 14),
        Text(S.of(context, 'orAvatar'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        SizedBox(
          height: 70,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final a in avatars)
              GestureDetector(
                onTap: () => setState(() => _avatar = a.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _avatar == a.key ? AppColors.teal : Colors.transparent, width: 3)),
                  child: AvatarView(avatarKey: a.key, size: 56),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: S.of(context, 'kidName'), filled: true, fillColor: AppColors.mint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
        ),
        const SizedBox(height: 6),
        Text(S.of(context, 'age'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        AnimatedDropdown<int>(
          items: [for (var a = 3; a <= 12; a++) a],
          value: _age,
          icon: Icons.cake_rounded,
          labelOf: (a) => S.of(context, 'ageYears', {'n': arNum(a, arabic: ar)}),
          onChanged: (a) => setState(() => _age = a),
        ),
        const SizedBox(height: 12),
        Text(S.of(context, 'city'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        AnimatedDropdown<int>(
          items: [for (var i = 0; i < citiesAr.length; i++) i],
          value: _city < 0 ? null : _city,
          icon: Icons.location_city_rounded,
          placeholder: S.of(context, 'chooseCity'),
          maxListHeight: 300,
          labelOf: (i) => cityName(i, ar),
          onChanged: (i) => setState(() => _city = i),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _area,
          maxLength: 30,
          decoration: InputDecoration(labelText: S.of(context, 'areaOptional'), filled: true, fillColor: AppColors.mint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
        ),
        const SizedBox(height: 8),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)), onPressed: _save, child: Text(S.of(context, 'save'))),
        if (context.read<ProgressStore>().profile != null)
          TextButton(onPressed: () => setState(() => _editing = false), child: Text(S.of(context, 'cancel'))),
      ]),
    );
  }

  Widget _settings(BuildContext context, ProgressStore p) {
    return Container(
      decoration: cardBox(radius: 24),
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.translate_rounded, color: AppColors.teal),
          title: Text(S.of(context, 'language')),
          trailing: SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'ar', label: Text('عربي')), ButtonSegment(value: 'en', label: Text('English'))],
            selected: {p.lang},
            showSelectedIcon: false,
            onSelectionChanged: (s) => p.setLang(s.first),
          ),
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.emoji_events_rounded, color: AppColors.goldDark),
          title: Text(S.of(context, 'showOnBoard')),
          subtitle: Text(S.of(context, 'showOnBoardSub')),
          value: p.locOk && p.showMe,
          onChanged: (v) async {
            if (v && !p.locOk) {
              final ok = await showParentGate(context, body: S.of(context, 'gateBoard'));
              if (ok) p.setLocOk(true);
            } else {
              p.setShowMe(v);
              if (!v) LeaderboardScreen.removeMe(context);
            }
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.share_rounded, color: AppColors.teal),
          title: Text(S.of(context, 'shareApp')),
          onTap: () => shareText(context, S.of(context, 'shareAppText')),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
          title: Text(S.of(context, 'deleteAll'), style: const TextStyle(color: AppColors.danger)),
          onTap: () async {
            final ok = await showParentGate(context, body: S.of(context, 'gateDelete'));
            if (!ok || !context.mounted) return;
            await LeaderboardScreen.removeMe(context);
            await p.deleteEverything();
            if (mounted) setState(() => _fill(null));
          },
        ),
      ]),
    );
  }
}
