import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_exceptions.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/user_profile.dart';
import '../../state/preferences.dart';
import '../../state/providers.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/brand.dart';
import '../../widgets/cine_button.dart';
import '../../widgets/layout.dart';
import '../../widgets/state_views.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider).value;
    final reservations = ref.watch(reservationsProvider).value ?? const [];
    final city = ref.watch(locationProvider);

    final upcoming = reservations.where((r) => r.isUpcoming()).length;
    final watched = reservations.length - upcoming;
    final seats = reservations.fold<int>(0, (sum, r) => sum + r.seats.length);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xl),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(header: true, child: Text('Profile', style: AppText.h1)),
                  Space.gap24,
                  if (user == null)
                    const _GuestCard()
                  else ...[
                    _IdentityCard(
                      name: profile?.displayName.isNotEmpty == true ? profile!.displayName : user.bestName,
                      email: user.email,
                      memberSince: profile?.createdAt,
                    ),
                    Space.gap16,
                    Row(
                      children: [
                        Expanded(
                          child: _Stat(value: '$upcoming', label: 'Upcoming'),
                        ),
                        Space.gap12,
                        Expanded(
                          child: _Stat(value: '$watched', label: 'Watched'),
                        ),
                        Space.gap12,
                        Expanded(
                          child: _Stat(value: '$seats', label: 'Seats booked'),
                        ),
                      ],
                    ),
                  ],
                  Space.gap24,
                  _SectionLabel('Account'),
                  _SettingsGroup(
                    children: [
                      if (user != null)
                        _SettingsTile(
                          icon: Icons.badge_outlined,
                          title: 'Edit name',
                          subtitle: profile?.displayName ?? user.bestName,
                          onTap: () => _editName(context, ref, user.uid, profile),
                        ),
                      _SettingsTile(
                        icon: Icons.location_on_outlined,
                        title: 'Preferred location',
                        subtitle: city,
                        onTap: () => _pickCity(context, ref, user?.uid, profile),
                      ),
                      _SettingsTile(
                        icon: Icons.confirmation_number_outlined,
                        title: 'My tickets',
                        subtitle: user == null ? 'Sign in to see your tickets' : '$upcoming upcoming',
                        onTap: () => context.go(Routes.tickets),
                      ),
                    ],
                  ),
                  Space.gap24,
                  _SectionLabel('App'),
                  _SettingsGroup(
                    children: [
                      _SettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: 'About CineNow',
                        subtitle: ref.watch(backendStatusProvider).mode.label,
                        onTap: () => _showAbout(context, ref),
                      ),
                    ],
                  ),
                  if (user != null) ...[
                    Space.gap32,
                    CineButton.secondary(
                      label: 'Sign out',
                      icon: Icons.logout_rounded,
                      onPressed: () => _confirmSignOut(context, ref),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your tickets stay safe in your account. Sign back in any time to see them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              minimumSize: const Size(0, Space.touchTarget),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authServiceProvider).signOut();
    HapticFeedback.mediumImpact();
    if (context.mounted) showAppSnack(context, 'Signed out. See you at the movies!', icon: Icons.waving_hand_rounded);
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String uid, UserProfile? profile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _EditNameSheet(uid: uid, profile: profile),
    );
  }

  Future<void> _pickCity(BuildContext context, WidgetRef ref, String? uid, UserProfile? profile) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final selected = ref.watch(locationProvider);
          final cities = ref.watch(configProvider).value?.cities ?? const ['Bangkok', 'Nonthaburi'];
          return Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preferred location', style: AppText.h2),
                const SizedBox(height: 4),
                Text('Cinemas in this city are listed first.', style: AppText.bodyMuted),
                Space.gap16,
                RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (value) async {
                    if (value == null) return;
                    HapticFeedback.selectionClick();
                    await ref.read(locationProvider.notifier).set(value);
                    if (uid != null && profile != null) {
                      try {
                        await ref.read(profileServiceProvider).updateProfile(uid, city: value);
                      } catch (_) {}
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      for (final c in cities)
                        RadioListTile<String>(
                          value: c,
                          title: Text(c, style: AppText.bodyStrong),
                          activeColor: AppColors.accent,
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAbout(BuildContext context, WidgetRef ref) {
    final status = ref.read(backendStatusProvider);
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CineNowLogo(size: 22),
            Space.gap16,
            Text(
              'A cinematic movie reservation demo built with Flutter, Firebase Authentication and '
              'Firebase Realtime Database.',
              style: AppText.bodyMuted,
            ),
            Space.gap16,
            _AboutRow(
              icon: status.mode.isDemo ? Icons.science_outlined : Icons.cloud_done_outlined,
              color: status.mode.isDemo ? AppColors.warning : AppColors.success,
              title: 'Data source: ${status.mode.label}',
              body: status.mode.isDemo
                  ? 'Using bundled sample data. Accounts and reservations stay on this device and are never sent to Firebase.'
                        '${status.reason != null ? '\nReason: ${status.reason}' : ''}'
                  : 'Movies, showtimes and seat availability sync live. Seats are booked with an atomic write, '
                        'so two people can never reserve the same seat.',
            ),
            const _AboutRow(
              icon: Icons.payments_outlined,
              color: AppColors.textSecondary,
              title: 'No real payments',
              body: 'Reservations are demo bookings. QR codes are decorative and not valid for entry.',
            ),
            const _AboutRow(
              icon: Icons.image_outlined,
              color: AppColors.textSecondary,
              title: 'Film data & images',
              body:
                  'Posters, backdrops and cast photos are provided by TMDB. This product uses the TMDB API '
                  'but is not endorsed or certified by TMDB. Cinemas are fictional.',
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestCard extends ConsumerWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SurfaceCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceRaised,
              border: Border.all(color: AppColors.outline),
            ),
            child: const Icon(Icons.person_outline_rounded, size: 36, color: AppColors.textSecondary),
          ),
          Space.gap16,
          Text('You\'re browsing as a guest', style: AppText.h3, textAlign: TextAlign.center),
          Space.gap8,
          Text(
            'Sign in to keep your tickets in one place and book faster.',
            style: AppText.bodyMuted,
            textAlign: TextAlign.center,
          ),
          Space.gap24,
          CineButton(label: 'Sign in', onPressed: () => context.push(Routes.signIn())),
          Space.gap8,
          CineButton.ghost(label: 'Create an account', onPressed: () => context.push(Routes.signUp())),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.name, required this.email, required this.memberSince});

  final String name;
  final String email;
  final DateTime? memberSince;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        borderRadius: Radii.xlAll,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1C1A), AppColors.surface],
        ),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(colors: [AppColors.accent, AppColors.gold, AppColors.accent]),
            ),
            child: CircleAvatar(
              backgroundColor: AppColors.surfaceRaised,
              child: Text(Fmt.initials(name), style: AppText.h2.copyWith(color: AppColors.accent)),
            ),
          ),
          Space.gap16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(email, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (memberSince != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Member since ${Fmt.monthYear(memberSince!)}',
                    style: AppText.label.copyWith(color: AppColors.accent),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.xs),
        child: Column(
          children: [
            Text(value, style: AppText.h1),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppText.caption,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: Space.xxs, bottom: Space.xs),
    child: Text(text.toUpperCase(), style: AppText.label.copyWith(letterSpacing: 1)),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Radii.lgAll,
        border: Border.all(color: AppColors.outlineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const Divider(indent: 64),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, required this.onTap, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: AppColors.surfaceRaised, borderRadius: Radii.smAll),
                  child: Icon(icon, size: 20, color: AppColors.textPrimary),
                ),
                Space.gap16,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.bodyStrong),
                      if (subtitle != null)
                        Text(subtitle!, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.icon, required this.color, required this.title, required this.body});

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          Space.gap12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyStrong),
                const SizedBox(height: 2),
                Text(body, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditNameSheet extends ConsumerStatefulWidget {
  const _EditNameSheet({required this.uid, required this.profile});

  final String uid;
  final UserProfile? profile;

  @override
  ConsumerState<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends ConsumerState<_EditNameSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.profile?.displayName ?? ref.read(currentUserProvider)?.displayName,
  );
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final name = _name.text.trim();
    final user = ref.read(currentUserProvider);
    try {
      await ref.read(authServiceProvider).updateDisplayName(name);
      final profiles = ref.read(profileServiceProvider);
      if (widget.profile == null && user != null) {
        await profiles.saveProfile(
          UserProfile(
            uid: widget.uid,
            displayName: name,
            email: user.email,
            createdAt: DateTime.now(),
            city: ref.read(locationProvider),
          ),
        );
      } else {
        await profiles.updateProfile(widget.uid, displayName: name);
      }
      if (!mounted) return;
      Navigator.pop(context);
      showAppSnack(context, 'Name updated.', icon: Icons.check_rounded);
    } on AppException catch (e) {
      if (mounted) showAppSnack(context, e.message, icon: Icons.error_outline_rounded);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Couldn\'t save your name. Please try again.', icon: Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit name', style: AppText.h2),
            Space.gap16,
            AppTextField(
              controller: _name,
              label: 'Full name',
              icon: Icons.person_outline_rounded,
              validator: Validators.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              autofocus: true,
            ),
            Space.gap24,
            CineButton(label: 'Save', loading: _busy, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
