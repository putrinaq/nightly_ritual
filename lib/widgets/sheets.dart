import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'controls.dart';
import 'shell.dart';

/// Opens a frosted bottom sheet. The sheet rises on an iOS-style drawer
/// curve and leaves faster than it arrives.
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x99020306),
    elevation: 0,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 420),
      reverseDuration: Duration(milliseconds: 240),
      curve: Motion.drawer,
    ),
    builder: builder,
  );
}

/// The sheet body: frosted material, a grab handle, optional title, and
/// keyboard-aware padding.
class GlassSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final bool scrollable;

  const GlassSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final bottom = keyboard > 0 ? keyboard + 16 : mq.padding.bottom + 24;

    final body = Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: AppType.heading),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: AppType.secondary),
            ],
            const SizedBox(height: 24),
          ],
          child,
        ],
      ),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.inkSheet.withValues(alpha: 0.82),
            border: Border(top: BorderSide(color: AppColors.white(0.12))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 18),
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.white(0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Flexible(
                child: scrollable ? SingleChildScrollView(child: body) : body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks before a destructive, hard-to-undo action. Resolves true to proceed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showGlassSheet<bool>(
    context,
    builder: (ctx) => GlassSheet(
      title: title,
      subtitle: message,
      child: Column(
        children: [
          SecondaryButton(
            label: confirmLabel,
            color: AppColors.danger,
            onPressed: () => Navigator.pop(ctx, true),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextAction(label: 'Cancel', onPressed: () => Navigator.pop(ctx, false)),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Lightweight status message. Replaces any message already showing.
void showToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final nav = ShellInsets.navOf(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        // Float above the glass nav bar rather than under it.
        margin: EdgeInsets.fromLTRB(16, 0, 16, nav > 0 ? nav : 12),
        duration: const Duration(seconds: 4),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
}
