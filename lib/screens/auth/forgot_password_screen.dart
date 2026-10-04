import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_exceptions.dart';
import '../../core/utils/validators.dart';
import '../../state/providers.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/cine_button.dart';
import '../../widgets/layout.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on AppException catch (e) {
      // Don't reveal whether an account exists for this address.
      if (e.code == 'user-not-found') {
        if (mounted) setState(() => _sent = true);
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = ref.watch(isDemoProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xl),
          child: ContentWidth(
            maxWidth: 480,
            child: AnimatedSwitcher(duration: Motion.slow, child: _sent ? _sentView(isDemo) : _formView()),
          ),
        ),
      ),
    );
  }

  Widget _formView() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text('Reset your password', style: AppText.h1)),
          Space.gap8,
          Text(
            'Enter the email you signed up with and we\'ll send you a link to choose a new password.',
            style: AppText.bodyMuted,
          ),
          Space.gap32,
          AppTextField(
            controller: _email,
            label: 'Email',
            hint: 'you@example.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            autofocus: widget.initialEmail == null,
          ),
          if (_error != null) ...[Space.gap16, Text(_error!, style: AppText.body.copyWith(color: AppColors.error))],
          Space.gap32,
          CineButton(label: 'Send reset link', icon: Icons.send_rounded, loading: _busy, onPressed: _send),
        ],
      ),
    );
  }

  Widget _sentView(bool isDemo) {
    return Column(
      key: const ValueKey('sent'),
      children: [
        Space.gap32,
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
          child: const Icon(Icons.mark_email_read_rounded, size: 44, color: AppColors.success),
        ).animate().scale(begin: const Offset(0.6, 0.6), curve: Motion.curveBounce, duration: Motion.emphasized),
        Space.gap24,
        Text('Check your inbox', style: AppText.h1, textAlign: TextAlign.center),
        Space.gap8,
        Text(
          isDemo
              ? 'Demo mode: no email is actually sent. In the live app, a reset link goes to ${_email.text.trim()}.'
              : 'If an account exists for ${_email.text.trim()}, a reset link is on its way. '
                    'It can take a minute — check your spam folder too.',
          style: AppText.bodyMuted,
          textAlign: TextAlign.center,
        ),
        Space.gap32,
        CineButton(label: 'Back to sign in', onPressed: () => context.pop()),
        Space.gap8,
        CineButton.ghost(label: 'Use a different email', onPressed: () => setState(() => _sent = false)),
      ],
    );
  }
}
