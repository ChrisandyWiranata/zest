import 'package:flutter/material.dart';

import '../../features/auth/models/app_user.dart';
import '../../features/users/services/progress_sync.dart';
import '../theme/app_colors.dart';
import '../widgets/motion.dart';

/// Navigator kiri untuk layout lebar: logo, menu, dan kartu akun.
/// Statis (tanpa animasi) agar aman untuk `pumpAndSettle`.
class ZestSidebar extends StatelessWidget {
  const ZestSidebar({
    super.key,
    required this.user,
    required this.selectedIndex,
    required this.onSelect,
    this.sync,
    this.showSettings = false,
  });

  final AppUser? user;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ProgressSync? sync;
  final bool showSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('zest-sidebar'),
      width: 248,
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(
          right: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 22, 22, 0),
              child: _ZestLogo(),
            ),
            const SizedBox(height: 28),
            _NavItem(
              key: const Key('side-nav-beranda'),
              icon: Icons.home_outlined,
              iconSelected: Icons.home_rounded,
              label: 'Beranda',
              active: selectedIndex == 0,
              onTap: () => onSelect(0),
            ),
            _NavItem(
              key: const Key('side-nav-profil'),
              icon: Icons.person_outline_rounded,
              iconSelected: Icons.person_rounded,
              label: 'Profil',
              active: selectedIndex == 1,
              onTap: () => onSelect(1),
            ),
            if (showSettings)
              _NavItem(
                key: const Key('side-nav-pengaturan'),
                icon: Icons.settings_outlined,
                iconSelected: Icons.settings_rounded,
                label: 'Pengaturan',
                active: selectedIndex == 2,
                onTap: () => onSelect(2),
              ),
            const Spacer(),
            if (sync != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                child: _SyncPill(sync: sync!),
              ),
            if (user != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: _UserCard(user: user!, onTap: () => onSelect(1)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZestLogo extends StatelessWidget {
  const _ZestLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(6),
          child: Image.asset('assets/icon/logo-zest.png'),
        ),
        const SizedBox(width: 12),
        const Text(
          'Zest',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.iconSelected,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData iconSelected;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: PressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(active ? iconSelected : icon, size: 20, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? AppColors.text : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap});

  final AppUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName.isEmpty ? user.email : user.displayName;
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.accent.withValues(alpha: 0.16),
              backgroundImage: user.hasPhoto
                  ? NetworkImage(user.photoUrl)
                  : null,
              child: user.hasPhoto
                  ? null
                  : Text(
                      user.initial,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.accent,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.sync});

  final ProgressSync sync;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: sync.status,
      builder: (context, status, _) {
        final (icon, color, label) = switch (status) {
          SyncStatus.syncing => (
            Icons.sync_rounded,
            AppColors.accent,
            'Menyinkronkan…',
          ),
          SyncStatus.synced => (
            Icons.cloud_done_outlined,
            AppColors.hafal,
            'Sinkron',
          ),
          SyncStatus.error => (
            Icons.error_outline_rounded,
            AppColors.belum,
            'Sinkron gagal',
          ),
          SyncStatus.pending => (
            Icons.cloud_upload_outlined,
            AppColors.textMuted,
            'Menunggu sinkron',
          ),
          SyncStatus.idle => (
            Icons.cloud_outlined,
            AppColors.textMuted,
            'Belum sinkron',
          ),
        };
        return Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }
}
