import 'package:flutter/material.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/motion.dart';
import '../../auth/models/app_user.dart';
import '../../categories/services/categories_service.dart';
import '../../progress/services/xp_store.dart';
import '../../settings/services/settings_store.dart' show SettingsStore;
import '../../users/services/progress_sync.dart';
import '../../videos/services/video_progress_store.dart';
import '../../vocab/services/srs_scheduler.dart';
import '../../vocab/services/srs_store.dart';

/// Ringkasan akun: identitas, statistik progres, status sinkron, dan keluar.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.user,
    required this.categoriesService,
    required this.srsStore,
    required this.xpStore,
    required this.videoProgressStore,
    required this.onLogout,
    this.sync,
    this.settings,
  });

  final AppUser user;
  final CategoriesService categoriesService;
  final SrsStore srsStore;
  final XpStore xpStore;
  final VideoProgressStore videoProgressStore;
  final ProgressSync? sync;
  final SettingsStore? settings;
  final VoidCallback onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<ProfileStats> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() => setState(() => _future = _load());

  Future<ProfileStats> _load() async {
    final xp = await widget.xpStore.load();
    final categories = await widget.categoriesService.getCategories();
    final matureDays = widget.settings?.value.matureDays ?? kMatureInterval;
    var mastered = 0;
    for (final c in categories) {
      final states = await widget.srsStore.loadAll(c.name);
      mastered += states.values
          .where((s) => isMature(s, matureDays: matureDays))
          .length;
    }
    final watched = await widget.videoProgressStore.countWatched();
    return ProfileStats(xp: xp, mastered: mastered, watched: watched);
  }

  Future<void> _syncNow() async {
    final sync = widget.sync;
    if (sync == null) return;
    await sync.pushAll(
      xpStore: widget.xpStore,
      srsStore: widget.srsStore,
      videoProgressStore: widget.videoProgressStore,
      getCategories: () => widget.categoriesService.getCategories().then(
        (cats) => cats.map((c) => c.name),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Keluar akun?'),
        content: const Text(
          'Progres tetap aman tersimpan di akun. Kamu bisa masuk lagi kapan saja.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<ProfileStats>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(message: '${snapshot.error}', onRetry: _reload);
          }
          final stats = snapshot.data ?? ProfileStats.empty();
          final user = widget.user;
          final content = ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            children: [
              _ProfileHeader(user: user),
              const SizedBox(height: 22),
              if (widget.sync != null) ...[
                _SyncCard(sync: widget.sync!, onSyncNow: _syncNow),
                const SizedBox(height: 12),
              ],
              _StatsGrid(
                stats: stats,
                columns: AdaptiveLayout.isWide(context) ? 3 : 2,
              ),
              const SizedBox(height: 20),
              _AccountCard(user: user, onLogout: _confirmLogout),
            ],
          );
          return AdaptiveLayout.isWide(context)
              ? CenteredPane(child: content)
              : content;
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName.isEmpty ? user.email : user.displayName;
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
          ),
          child: user.hasPhoto
              ? ClipOval(child: Image.network(user.photoUrl, fit: BoxFit.cover))
              : Center(
                  child: Text(
                    user.initial,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 14),
        Text(
          name,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          'Masuk lewat Google',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.sync, this.onSyncNow});

  final ProgressSync sync;
  final VoidCallback? onSyncNow;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: sync.status,
      builder: (context, status, _) {
        final syncedAt = sync.lastSyncAt;
        final (icon, color, label) = switch (status) {
          SyncStatus.syncing => (
            Icons.sync_rounded,
            AppColors.accent,
            'Menyinkronkan…',
          ),
          SyncStatus.error => (
            Icons.error_outline_rounded,
            AppColors.belum,
            'Gagal sinkron — coba lagi',
          ),
          SyncStatus.pending => (
            Icons.cloud_upload_outlined,
            AppColors.textMuted,
            'Menunggu sinkron…',
          ),
          SyncStatus.idle => (
            Icons.cloud_outlined,
            AppColors.textMuted,
            syncedAt == null ? 'Belum tersinkron' : _formatSync(syncedAt),
          ),
          SyncStatus.synced => (
            Icons.cloud_done_outlined,
            AppColors.hafal,
            syncedAt == null ? 'Sinkron' : _formatSync(syncedAt),
          ),
        };
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: status == SyncStatus.syncing
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: color,
                            ),
                          )
                        : Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sinkronisasi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: status == SyncStatus.syncing
                        ? null
                        : () => sync.flush(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Sekarang'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                ],
              ),
              if (onSyncNow != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: status == SyncStatus.syncing ? null : onSyncNow,
                    icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                    label: const Text('Sinkronkan progres'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, this.columns = 2});

  final ProfileStats stats;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.bolt_rounded, '${stats.xp.total}', 'XP total'),
      (Icons.military_tech_rounded, '${stats.xp.level}', 'Level'),
      (Icons.local_fire_department_rounded, '${stats.xp.streak}', 'Streak'),
      (Icons.bolt_rounded, '${stats.xp.todayXp}', 'XP hari ini'),
      (Icons.style_rounded, '${stats.mastered}', 'Kata hafal'),
      (Icons.videocam_rounded, '${stats.watched}', 'Video ditonton'),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 96,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (icon, value, label) = items[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedCounter(
                    value: int.tryParse(value) ?? 0,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                      height: 1,
                    ),
                  ),
                  if (i == 3) ...[
                    const SizedBox(width: 3),
                    const Text(
                      'XP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.alternate_email_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
            title: const Text(
              'Akun Google',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              user.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(
              Icons.logout_rounded,
              size: 20,
              color: AppColors.belum,
            ),
            title: const Text(
              'Keluar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.belum,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textHint,
            ),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

String _formatSync(int epochSeconds) {
  final t = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return 'Tersinkron ${t.day}/${t.month} $hh:$mm';
}

class ProfileStats {
  const ProfileStats({
    required this.xp,
    required this.mastered,
    required this.watched,
  });

  final XpInfo xp;
  final int mastered;
  final int watched;

  static ProfileStats empty() => const ProfileStats(
    xp: XpInfo(total: 0, streak: 0, todayXp: 0, level: 1),
    mastered: 0,
    watched: 0,
  );
}
