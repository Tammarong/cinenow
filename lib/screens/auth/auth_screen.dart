import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_exceptions.dart';
import '../../core/utils/validators.dart';
import '../../state/booking_controller.dart';
import '../../state/preferences.dart';
import '../../state/providers.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/booking_widgets.dart';
import '../../widgets/brand.dart';
import '../../widgets/cine_button.dart';
import '../../widgets/layout.dart';

/// Sign in / create account. Pops `true` on success so a booking flow can
/// continue exactly where it left off.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.startWithSignUp = false, this.forBooking = false});

  final bool startWithSignUp;
  final bool forBooking;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late bool _signUp = widget.startWithSignUp;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _switchMode(bool signUp) {
    if (signUp == _signUp) return;
    HapticFeedback.selectionClick();
    setState(() {
      _signUp = signUp;
      _error = null;
    });
    _formKey.currentState?.reset();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);
    try {
      if (_signUp) {
        await auth.signUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          city: ref.read(locationProvider),
        );
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
      TextInput.finishAutofillContext();
      await ref.read(welcomeSeenProvider.notifier).markSeen();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(Routes.home);
      }
    } on AppException catch (e) {
      setState(() => _error = e.message);
      HapticFeedback.heavyImpact();
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = ref.watch(isDemoProvider);
    final draft = ref.watch(bookingProvider);
    final title = _signUp ? 'Create your account' : 'Welcome back';
    final subtitle = widget.forBooking
        ? 'Sign in to confirm your seats. Your selection is saved and waiting.'
        : _signUp
        ? 'Save tickets to your account and book in seconds next time.'
        : 'Sign in to see your tickets and book faster.';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.canPop() ? context.pop(false) : context.go(Routes.home),
        ),
        title: const CineNowLogo(size: 18),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xl),
          child: ContentWidth(
            maxWidth: 480,
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedSwitcher(
                      duration: Motion.medium,
                      child: Column(
                        key: ValueKey(_signUp),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(header: true, child: Text(title, style: AppText.h1)),
                          Space.gap8,
                          Text(subtitle, style: AppText.bodyMuted),
                        ],
                      ),
                    ),
                    if (widget.forBooking && draft.movie != null) ...[
                      Space.gap16,
                      BookingSummaryBar(
                        draft: draft,
                        trailing: Padding(
                          padding: const EdgeInsets.only(left: Space.xs),
                          child: Text(
                            '${draft.seats.length} seats',
                            style: AppText.label.copyWith(color: AppColors.accent),
                          ),
                        ),
                      ),
                    ],
                    Space.gap24,
                    _ModeToggle(signUp: _signUp, onChanged: _switchMode),
                    Space.gap24,
                    AnimatedSize(
                      duration: Motion.medium,
                      curve: Motion.curve,
                      alignment: Alignment.topCenter,
                      child: _signUp
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: Space.md),
                              child: AppTextField(
                                controller: _name,
                                label: 'Full name',
                                hint: 'Alex Tan',
                                icon: Icons.person_outline_rounded,
                                validator: Validators.name,
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [AutofillHints.name],
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    AppTextField(
                      controller: _email,
                      label: 'Email',
                      hint: 'you@example.com',
                      icon: Icons.alternate_email_rounded,
                      validator: Validators.email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                    ),
                    Space.gap16,
                    AppTextField(
                      controller: _password,
                      label: 'Password',
                      hint: _signUp ? 'At least 8 characters' : 'Your password',
                      icon: Icons.lock_outline_rounded,
                      obscure: true,
                      validator: _signUp ? Validators.newPassword : Validators.passwordPresent,
                      autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                      textInputAction: _signUp ? TextInputAction.next : TextInputAction.done,
                      onSubmitted: _signUp ? null : (_) => _submit(),
                      onChanged: _signUp ? (_) => setState(() {}) : null,
                    ),
                    if (_signUp) ...[
                      Space.gap8,
                      _StrengthMeter(strength: Validators.passwordStrength(_password.text)),
                      Space.gap16,
                      AppTextField(
                        controller: _confirm,
                        label: 'Confirm password',
                        hint: 'Type it once more',
                        icon: Icons.lock_reset_rounded,
                        obscure: true,
                        validator: Validators.confirmPassword(() => _password.text),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                      ),
                    ] else
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push(
                            Uri(
                              path: Routes.forgotPassword,
                              queryParameters: {if (_email.text.trim().isNotEmpty) 'email': _email.text.trim()},
                            ).toString(),
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    AnimatedSwitcher(
                      duration: Motion.medium,
                      child: _error == null
                          ? const SizedBox(height: Space.lg)
                          : Padding(
                              key: ValueKey(_error),
                              padding: const EdgeInsets.symmetric(vertical: Space.md),
                              child: _ErrorNote(message: _error!),
                            ),
                    ),
                    CineButton(label: _signUp ? 'Create account' : 'Sign in', loading: _busy, onPressed: _submit),
                    Space.gap16,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_signUp ? 'Already have an account?' : 'New to CineNow?', style: AppText.bodyMuted),
                        TextButton(
                          onPressed: () => _switchMode(!_signUp),
                          child: Text(_signUp ? 'Sign in' : 'Create one'),
                        ),
                      ],
                    ),
                    if (isDemo) ...[Space.gap8, const _DemoNote()],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.signUp, required this.onChanged});

  final bool signUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value) => Expanded(
      child: Semantics(
        button: true,
        selected: signUp == value,
        child: InkWell(
          borderRadius: Radii.pillAll,
          onTap: () => onChanged(value),
          child: SizedBox(
            height: Space.touchTarget,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: Motion.medium,
                style: AppText.bodyStrong.copyWith(
                  color: signUp == value ? AppColors.onAccent : AppColors.textSecondary,
                ),
                child: Text(label),
              ),
            ),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Radii.pillAll,
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: Motion.medium,
            curve: Motion.curveEmphasized,
            alignment: signUp ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: Space.touchTarget,
                decoration: const BoxDecoration(color: AppColors.accent, borderRadius: Radii.pillAll),
              ),
            ),
          ),
          Row(children: [tab('Sign in', false), tab('Sign up', true)]),
        ],
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.strength});

  final int strength;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (strength) {
      0 => ('Use 8+ characters with letters and a number', AppColors.textTertiary),
      1 => ('Weak — add length or a number', AppColors.error),
      2 => ('Good', AppColors.warning),
      _ => ('Strong password', AppColors.success),
    };
    return Semantics(
      liveRegion: true,
      label: 'Password strength: $label',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 1; i <= 3; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: Motion.medium,
                height: 4,
                decoration: BoxDecoration(
                  color: i <= strength ? color : AppColors.surfaceRaised,
                  borderRadius: Radii.pillAll,
                ),
              ),
            ),
            if (i < 3) const SizedBox(width: 6),
          ],
          Space.gap12,
          Text(label, style: AppText.caption.copyWith(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: AppColors.errorSoft,
          borderRadius: Radii.mdAll,
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
            Space.gap12,
            Expanded(child: Text(message, style: AppText.body)),
          ],
        ),
      ),
    ).animate().shakeX(hz: 4, amount: 3, duration: 350.ms);
  }
}

class _DemoNote extends StatelessWidget {
  const _DemoNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: Radii.mdAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, color: AppColors.warning, size: 20),
          Space.gap12,
          Expanded(
            child: Text(
              'Demo mode: accounts are simulated and remembered on this device only. '
              'Passwords are not stored or checked, and nothing is sent to Firebase.',
              style: AppText.caption.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
