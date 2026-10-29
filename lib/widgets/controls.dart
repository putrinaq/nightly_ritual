import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass.dart';
import 'motion.dart';

/// The one filled button style: candlelight with ink text.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = AnimatedSwitcher(
      duration: Motion.fast,
      switchInCurve: Motion.easeOut,
      child: loading
          ? const SizedBox(
              key: ValueKey('loading'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent),
            )
          : Row(
              key: ValueKey(label),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppType.bodyStrong.copyWith(
                    color: AppColors.onAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, size: 18, color: AppColors.onAccent),
                ],
              ],
            ),
    );

    return Pressable(
      onTap: loading ? null : onPressed,
      haptic: true,
      child: Container(
        height: 56,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md + 2),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0D7AA), AppColors.accent, AppColors.accentDeep],
            stops: [0, 0.45, 1],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: content,
      ),
    );
  }
}

/// Glass button for secondary actions.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.text;
    return Pressable(
      onTap: onPressed,
      child: Glass(
        radius: AppRadius.md + 2,
        fill: 0.05,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: c),
                const SizedBox(width: 8),
              ],
              Text(label, style: AppType.bodyStrong.copyWith(color: c)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 44pt round glass button holding a single icon.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final Color? color;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.size = 44,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      scale: 0.92,
      semanticLabel: semanticLabel,
      child: Glass(
        radius: size / 2,
        fill: 0.05,
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Small glass pill for "add" style header actions.
class PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const PillButton({
    super.key,
    required this.label,
    this.icon = Icons.add_rounded,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      haptic: true,
      child: Glass(
        radius: 999,
        fill: 0.06,
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(label, style: AppType.bodyStrong.copyWith(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

/// Text-only tertiary action.
class TextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const TextAction({
    super.key,
    required this.label,
    this.onPressed,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(label, style: AppType.bodyStrong.copyWith(color: color, fontSize: 14)),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;
  final String? trailing;
  const FieldLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        children: [
          Text(text, style: AppType.caption.copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          if (trailing != null) Text(trailing!, style: AppType.caption),
        ],
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool serif;
  final Widget? prefix;

  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.errorText,
    this.onSubmitted,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.serif = false,
    this.prefix,
  });

  OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md - 2),
        borderSide: BorderSide(color: c, width: w),
      );

  @override
  Widget build(BuildContext context) {
    final textStyle = serif
        ? AppType.heading.copyWith(fontSize: 22, height: 1.3)
        : AppType.body;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: 1,
      maxLength: maxLength,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization:
          keyboardType == TextInputType.url ? TextCapitalization.none : TextCapitalization.sentences,
      style: textStyle,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: textStyle.copyWith(color: AppColors.textTertiary),
        counterText: '',
        errorText: errorText,
        errorStyle: AppType.caption.copyWith(color: AppColors.danger),
        filled: true,
        fillColor: AppColors.white(0.04),
        prefixIcon: prefix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: _border(AppColors.hairline),
        enabledBorder: _border(AppColors.white(0.09)),
        focusedBorder: _border(AppColors.accent.withValues(alpha: 0.7), 1.2),
        errorBorder: _border(AppColors.danger.withValues(alpha: 0.6)),
        focusedErrorBorder: _border(AppColors.danger, 1.2),
      ),
    );
  }
}

/// Toggleable chip used for quick tags and selections.
class ChoiceChipX extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  const ChoiceChipX({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.easeOut,
        padding: EdgeInsets.fromLTRB(12, 8, trailingIcon == null ? 12 : 8, 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentTint(0.14) : AppColors.white(0.04),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? AppColors.accent.withValues(alpha: 0.45) : AppColors.white(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.secondary.copyWith(
                  fontSize: 13,
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 4),
              Icon(trailingIcon, size: 14, color: selected ? AppColors.accent : AppColors.textTertiary),
            ],
          ],
        ),
      ),
    );
  }
}

/// Quiet, non-interactive tag.
class TagLabel extends StatelessWidget {
  final String text;
  const TagLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppType.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

/// A small leading icon tile used in rows.
class RowIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  const RowIcon(this.icon, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.white(0.05),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
    );
  }
}

/// Composed empty state: a quiet mark, one line saying what's missing, one
/// line saying how to fix it, and an optional action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Glass(
            radius: 22,
            child: SizedBox.square(
              dimension: 64,
              child: Icon(icon, color: AppColors.accent, size: 26),
            ),
          ),
          const SizedBox(height: 20),
          Text(title, style: AppType.heading, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, style: AppType.secondary, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 24),
            PillButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Page header: serif title, optional subtitle, optional trailing action.
class PageHeader extends StatelessWidget {
  final String title;
  final Widget? subtitle;
  final Widget? trailing;

  const PageHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.title),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                DefaultTextStyle(style: AppType.secondary, child: subtitle!),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}
