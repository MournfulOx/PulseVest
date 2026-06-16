import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class ReminderSheet extends StatefulWidget {
  const ReminderSheet({super.key});

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  final NotificationService _notificationService = NotificationService();
  bool _enabled = false;
  int _day = 1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _notificationService.isReminderEnabled();
    final day = await _notificationService.getReminderDay();
    setState(() {
      _enabled = enabled;
      _day = day;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              const Text('定投提醒',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (!_loading)
                Switch(
                  value: _enabled,
                  onChanged: (val) async {
                    setState(() => _enabled = val);
                    if (val) {
                      await _notificationService.scheduleMonthlyReminder(_day);
                    } else {
                      await _notificationService.cancelReminder();
                    }
                  },
                  activeColor: scheme.primary,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('每月固定日期提醒你完成定投',
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 24),
          if (_enabled) ...[
            Text('提醒日期（每月第几号）',
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withOpacity(0.7))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [1, 5, 10, 15, 20, 25].map((d) {
                final selected = _day == d;
                return GestureDetector(
                  onTap: () async {
                    setState(() => _day = d);
                    await _notificationService.scheduleMonthlyReminder(d);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary
                          : scheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text('$d日',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: selected
                                ? Colors.white
                                : scheme.primary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: scheme.secondary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '将在每月 $_day 日上午9:00提醒',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
