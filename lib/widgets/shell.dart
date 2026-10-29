import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'glass.dart';

/// How much of the bottom of the screen the floating nav bar covers, so
/// scrolling content can run underneath it and still end clear of it.
class ShellInsets extends InheritedWidget {
  /// Clearance from the very bottom of the screen, safe area included.
  final double bottom;

  /// Clearance above the safe area — what floating toasts need to skip.
  final double nav;

  const ShellInsets({
    super.key,
    required this.bottom,
    required this.nav,
    required super.child,
  });

  static double bottomOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellInsets>()?.bottom ??
      MediaQuery.paddingOf(context).bottom;

  static double navOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellInsets>()?.nav ?? 0;

  @override
  bool updateShouldNotify(ShellInsets old) => old.bottom != bottom || old.nav != nav;
}

class NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const NavItem(this.label, this.icon, this.activeIcon);
}

/// Floating frosted tab bar. The highlight slides between tabs rather than
/// jumping, so the eye can follow where it went.
class FloatingNavBar extends StatelessWidget {
  static const height = 64.0;
  static const gap = 12.0;

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  const FloatingNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final n = items.length;
    return Glass(
      radius: 26,
      blur: 24,
      fill: 0.07,
      shadow: true,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: Motion.base,
              curve: Motion.easeOut,
              alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.white(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.white(0.06)),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: Semantics(
                      selected: i == index,
                      button: true,
                      label: items[i].label,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (i == index) return;
                          HapticFeedback.selectionClick();
                          onChanged(i);
                        },
                        child: _NavButton(item: items[i], active: i == index),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool active;
  const _NavButton({required this.item, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.text : AppColors.textTertiary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: Motion.fast,
          child: Icon(
            active ? item.activeIcon : item.icon,
            key: ValueKey(active),
            size: 22,
            color: active ? AppColors.accent : color,
          ),
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: Motion.fast,
          style: AppType.caption.copyWith(
            fontSize: 11,
            color: color,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
          child: Text(item.label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
        ),
      ],
    );
  }
}

/// Keeps every tab alive (scroll position, streams) and switches between
/// them instantly, like a native tab bar. Fading the page in from 0 on every
/// switch blanked it for a frame and made text-heavy tabs flash.
class TabStack extends StatelessWidget {
  final int index;
  final List<Widget> children;
  const TabStack({super.key, required this.index, required this.children});

  @override
  Widget build(BuildContext context) => IndexedStack(index: index, children: children);
}
