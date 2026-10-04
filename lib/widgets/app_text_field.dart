import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// Labelled text field with consistent styling, inline validation and an
/// optional show/hide toggle for passwords.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.validator,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.obscure = false,
    this.onSubmitted,
    this.onChanged,
    this.focusNode,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscure;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  // The keyboard's "next" action should jump to the next field, not stop
  // on (and toggle) the show/hide button.
  final _toggleFocus = FocusNode(skipTraversal: true);

  @override
  void dispose() {
    _toggleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Space.xxs, bottom: Space.xs),
          child: Text(widget.label, style: AppText.label.copyWith(color: AppColors.textPrimary)),
        ),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          obscureText: _hidden,
          enableSuggestions: !widget.obscure,
          autocorrect: !widget.obscure && widget.keyboardType != TextInputType.emailAddress,
          textCapitalization: widget.textCapitalization,
          onFieldSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          // No nagging before the first submit; once an error shows, it
          // clears live as the user fixes it.
          autovalidateMode: AutovalidateMode.onUserInteractionIfError,
          style: AppText.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 22),
            suffixIcon: widget.obscure
                ? IconButton(
                    focusNode: _toggleFocus,
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
