import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExampleAlarmRingScreen extends StatelessWidget {
  const ExampleAlarmRingScreen({required this.alarmSettings, super.key});

  final AlarmSettings alarmSettings;

  Future<List<bool>> _loadSelectedDays() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDays = prefs.getString('selectedDays_${alarmSettings.id}');

    if (savedDays != null) {
      return savedDays.split('').map((e) => e == '1').toList();
    }
    return List.filled(7, false); // Default: No days selected
  }

  void _scheduleNextAlarm() async {
    final now = DateTime.now();
    final selectedDays = await _loadSelectedDays();

    if (!selectedDays.contains(true)) return; // No selected days, stop alarm.

    int nextDayOffset = 1;
    while (!selectedDays[(now.weekday - 1 + nextDayOffset) % 7]) {
      nextDayOffset++;
    }

    final nextAlarmTime = DateTime(
      now.year,
      now.month,
      now.day,
      alarmSettings.dateTime.hour,
      alarmSettings.dateTime.minute,
    ).add(Duration(days: nextDayOffset));

    Alarm.set(alarmSettings: alarmSettings.copyWith(dateTime: nextAlarmTime));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              'Your alarm is ringing...',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text('🔔', style: TextStyle(fontSize: 50)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                RawMaterialButton(
                  onPressed: () {
                    final now = DateTime.now();
                    Alarm.set(
                      alarmSettings: alarmSettings.copyWith(
                        dateTime: DateTime(
                          now.year,
                          now.month,
                          now.day,
                          now.hour,
                          now.minute,
                        ).add(const Duration(minutes: 1)),
                      ),
                    ).then((_) {
                      if (context.mounted) Navigator.pop(context);
                    });
                  },
                  child: Text(
                    'Snooze',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                RawMaterialButton(
                  onPressed: () {
                    Alarm.stop(alarmSettings.id).then((_) {
                      _scheduleNextAlarm(); // Schedule for the next day
                      if (context.mounted) Navigator.pop(context);
                    });
                  },
                  child: Text(
                    'Stop',
                    style: Theme.of(context).textTheme.titleLarge,
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
