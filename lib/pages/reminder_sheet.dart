import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/sheets.dart';

/// Reminder settings. Changes apply as they're made: the switch schedules or
/// cancels immediately, and moving the time while the reminder is on
/// reschedules it. (Previously a new time was only saved if you toggled the
/// reminder off and on again.)
class ReminderSheet extends StatefulWidget {
  final NotificationService notificationService;
  final ReminderPreferences prefs;
  final VoidCallback onChanged;

  const ReminderSheet({
    super.key,
    required this.notificationService,
    required this.prefs,
    required this.onChanged,
  });

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  late bool _enabled = widget.prefs.isEnabled;
  late int _hour = widget.prefs.hour;
  late int _minute = widget.prefs.minute;
  bool _busy = false;
  String? _error;
  Timer? _debounce;

  @override
  void dispose() {
    // Flush a pending time change rather than dropping it on close.
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _applyTime();
    }
    super.dispose();
  }

  Future<void> _toggle(bool on) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _enabled = on;
    });
    if (on) {
      final ok = await widget.notificationService.scheduleReminderAt(_hour, _minute);
      if (ok) {
        await widget.prefs.setTime(_hour, _minute);
        await widget.prefs.setEnabled(true);
        widget.notificationService.showConfirmation(Dates.time(_hour, _minute));
      } else if (mounted) {
        setState(() {
          _enabled = false;
          _error = "Couldn't schedule it. Allow notifications for Nightly Ritual in "
              'your device settings, then try again.';
        });
      }
    } else {
      await widget.notificationService.cancelReminder();
      await widget.prefs.setEnabled(false);
    }
    widget.onChanged();
    if (mounted) setState(() => _busy = false);
  }

  void _onTime(DateTime t) {
    setState(() {
      _hour = t.hour;
      _minute = t.minute;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _applyTime);
  }

  Future<void> _applyTime() async {
    await widget.prefs.setTime(_hour, _minute);
    if (widget.prefs.isEnabled) {
      final ok = await widget.notificationService.scheduleReminderAt(_hour, _minute);
      if (!ok && mounted) {
        setState(() => _error = "Couldn't move the reminder. Try again.");
      }
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return GlassSheet(
      title: 'Nightly reminder',
      subtitle: 'A quiet nudge when it\'s time to wind down.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Glass(
            radius: AppRadius.lg,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Remind me', style: AppType.bodyStrong),
                            const SizedBox(height: 2),
                            Text(
                              _enabled ? 'Every night at ${Dates.time(_hour, _minute)}' : 'Off',
                              style: AppType.secondary,
                            ),
                          ],
                        ),
                      ),
                      CupertinoSwitch(
                        value: _enabled,
                        activeTrackColor: AppColors.accent,
                        onChanged: _busy ? null : _toggle,
                      ),
                    ],
                  ),
                ),
                const GlassDivider(),
                SizedBox(
                  height: 180,
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      brightness: Brightness.dark,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          fontFamily: AppType.sans,
                          fontSize: 21,
                          color: AppColors.text,
                          fontFeatures: AppType.tabular,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      backgroundColor: Colors.transparent,
                      initialDateTime: DateTime(now.year, now.month, now.day, _hour, _minute),
                      onDateTimeChanged: _onTime,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.easeOut,
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(_error!, style: AppType.secondary.copyWith(color: AppColors.danger)),
                  ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
