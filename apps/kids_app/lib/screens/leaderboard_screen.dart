import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../data/cities.dart';
import '../l10n.dart';
import '../state/progress_store.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/fanoos.dart';
import '../widgets/parent_gate.dart';
import '../theme.dart';

enum _Scope { area, city, country }

/// لوحة الشرف: ترتيب الطفل بين أصحابه في نفس المحافظة/الحي.
/// بموافقة الأهل فقط، وبالاسم الأول والشخصية الكرتونية والنجوم فقط (بدون صور أو موقع دقيق).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  /// يحذف الطفل من لوحة الشرف (عند الإخفاء أو مسح البيانات).
  static Future<void> removeMe(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await context.read<ContentRepository>().removeLeader(uid);
    } catch (_) {}
  }

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  _Scope _scope = _Scope.city;
  Stream<List<LeaderEntry>>? _stream;
  String _streamKey = '';
  String? _syncedKey;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _sync(ProgressStore p, RewardsConfig cfg) async {
    final uid = _uid;
    final prof = p.profile;
    if (uid == null || prof == null || prof.city < 0) return;
    final repo = context.read<ContentRepository>();
    final entry = LeaderEntry(
      uid: uid,
      nickname: prof.name.split(' ').first,
      avatar: prof.avatar,
      city: prof.city,
      area: prof.area,
      stars: p.normalStars(cfg),
      royal: p.royalStars(cfg),
    );
    final key = '${p.showMe}|${entry.nickname}|${entry.avatar}|${entry.city}|${entry.area}|${entry.stars}|${entry.royal}';
    if (key == _syncedKey) return;
    _syncedKey = key;
    try {
      if (p.showMe) {
        await repo.upsertLeader(entry);
      } else {
        await repo.removeLeader(uid);
      }
    } catch (e) {
      debugPrint('leaderboard sync failed: $e');
    }
  }

  Stream<List<LeaderEntry>> _streamFor(KidProfile prof) {
    final key = '${_scope.name}|${prof.city}|${prof.area}';
    if (_stream == null || key != _streamKey) {
      _streamKey = key;
      final repo = context.read<ContentRepository>();
      _stream = switch (_scope) {
        _Scope.country => repo.leaderboard(),
        _Scope.city => repo.leaderboard(city: prof.city),
        _Scope.area => repo.leaderboard(city: prof.city, area: prof.area),
      };
    }
    return _stream!;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProgressStore>();
    final cfg = context.watch<AppConfig>().rewards;
    final prof = p.profile;
    Widget body;
    if (prof == null || prof.city < 0) {
      body = _Message(icon: Icons.face_rounded, text: S.of(context, 'boardNeedProfile'));
    } else if (!p.locOk) {
      body = _Consent(onOk: () async {
        final ok = await showParentGate(context, body: S.of(context, 'gateBoard'));
        if (ok) p.setLocOk(true);
      });
    } else {
      _sync(p, cfg);
      body = _board(context, p, prof);
    }
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context, 'leaderboard')), backgroundColor: AppColors.goldDark),
      body: body,
    );
  }

  Widget _board(BuildContext context, ProgressStore p, KidProfile prof) {
    final ar = S.ar(context);
    final scopes = [
      if (prof.area.isNotEmpty) _Scope.area,
      _Scope.city,
      _Scope.country,
    ];
    if (!scopes.contains(_scope)) _scope = _Scope.city;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: SegmentedButton<_Scope>(
          showSelectedIcon: false,
          segments: [
            for (final s in scopes)
              ButtonSegment(
                value: s,
                label: Text(switch (s) {
                  _Scope.area => prof.area,
                  _Scope.city => cityName(prof.city, ar),
                  _Scope.country => S.of(context, 'everyone'),
                }, overflow: TextOverflow.ellipsis),
              ),
          ],
          selected: {_scope},
          onSelectionChanged: (s) => setState(() => _scope = s.first),
        ),
      ),
      SwitchListTile(
        title: Text(S.of(context, 'showOnBoard')),
        value: p.showMe,
        onChanged: (v) => p.setShowMe(v),
      ),
      Expanded(
        child: StreamBuilder<List<LeaderEntry>>(
          stream: _streamFor(prof),
          builder: (context, snap) {
            if (snap.hasError) return _Message(icon: Icons.cloud_off_rounded, text: S.of(context, 'loadError'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final list = snap.data!;
            if (list.isEmpty) return _Message(icon: Icons.emoji_events_rounded, text: S.of(context, 'boardEmpty'));
            final top = list.take(3).toList();
            final rest = list.skip(3).toList();
            return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              _Podium(top: top, me: _uid),
              const SizedBox(height: 10),
              for (var i = 0; i < rest.length; i++) _Row(rank: i + 4, e: rest[i], me: rest[i].uid == _uid),
              const SizedBox(height: 10),
              Text(S.of(context, 'boardPrivacy'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ]);
          },
        ),
      ),
    ]);
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top, required this.me});
  final List<LeaderEntry> top;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    // الترتيب البصري: الثاني - الأول - الثالث
    final order = [if (top.length > 1) 1, 0, if (top.length > 2) 2];
    const heights = [120.0, 90.0, 70.0];
    const colors = [AppColors.gold, Color(0xFFC9D3DE), Color(0xFFE0A872)];
    return Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
      for (final i in order)
        Expanded(
          child: RiseIn(
            delay: i * 120,
            child: Column(children: [
              if (i == 0) const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 34),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: top[i].uid == me ? AppColors.teal : Colors.transparent, width: 3)),
                child: AvatarView(avatarKey: top[i].avatar, size: i == 0 ? 70 : 56),
              ),
              Text(top[i].nickname, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              StarPill(count: top[i].stars, dense: true),
              const SizedBox(height: 4),
              Container(
                height: heights[i],
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: colors[i], borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                alignment: Alignment.center,
                child: Text(arNum(i + 1, arabic: ar), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ]),
          ),
        ),
    ]);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.e, required this.me});
  final int rank;
  final LeaderEntry e;
  final bool me;
  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: cardBox(color: me ? const Color(0xFFD6F3EC) : Colors.white, radius: 18),
      child: Row(children: [
        SizedBox(width: 34, child: Text(arNum(rank, arabic: ar), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        AvatarView(avatarKey: e.avatar, size: 42),
        const SizedBox(width: 10),
        Expanded(child: Text(me ? '${e.nickname} (${S.of(context, 'you')})' : e.nickname, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
        StarPill(count: e.stars, dense: true),
        const SizedBox(width: 4),
        StarPill(count: e.royal, royal: true, dense: true),
      ]),
    );
  }
}

class _Consent extends StatelessWidget {
  const _Consent({required this.onOk});
  final VoidCallback onOk;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [
        const Center(child: Fanoos(size: 100, mood: FanoosMood.talk)),
        const SizedBox(height: 14),
        Text(S.of(context, 'boardIntro'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, height: 1.6)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: cardBox(radius: 20),
          child: Text(S.of(context, 'boardWhatShared'), style: const TextStyle(fontSize: 16, height: 1.7)),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: onOk,
          icon: const Icon(Icons.lock_open_rounded),
          label: Text(S.of(context, 'parentsAgree')),
        ),
      ]);
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 64, color: AppColors.muted),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
          ]),
        ),
      );
}
