import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExampleAlarmRingScreen extends StatelessWidget {
  const ExampleAlarmRingScreen({required this.alarmSettings, super.key});

  final AlarmSettings alarmSettings;


  Future<List<bool>> _loadSelectedDays() async {
    final prefs = await SharedPreferences.getInstance();
    // Just use the alarm ID directly (no need for base ID extraction)
    final savedDays = prefs.getString('selectedDays_${alarmSettings.id}');

    if (savedDays != null) {
      print('[LOAD] Found selectedDays for alarm ${alarmSettings.id}: $savedDays');
      return savedDays.split('').map((e) => e == '1').toList();
    }
    print('[LOAD] No selectedDays found for alarm ${alarmSettings.id}');
    return List.filled(7, false);
  }

  void _scheduleNextAlarm() async {
    final now = DateTime.now();
    final selectedDays = await _loadSelectedDays();

    if (!selectedDays.contains(true)) {
      print('[SCHEDULE] No days selected - not rescheduling');
      return;
    }
    // Find the next selected day (including today if it's selected)
    DateTime? nextAlarmDate;

    // Check if today is selected and the alarm time is still in the future today
    int todayIndex = now.weekday % 7; // 0=Sun, 1=Mon, ..., 6=Sat
    if (selectedDays[todayIndex]) {
      final todayAlarm = DateTime(
        now.year,
        now.month,
        now.day,
        alarmSettings.dateTime.hour,
        alarmSettings.dateTime.minute,
      );
      if (todayAlarm.isAfter(now)) {
        nextAlarmDate = todayAlarm;
      }
    }

    // If today isn't selected or the time has passed, find the next selected day
    if (nextAlarmDate == null) {
      for (int i = 1; i <= 7; i++) {
        final futureDate = now.add(Duration(days: i));
        final dayIndex = futureDate.weekday % 7;
        if (selectedDays[dayIndex]) {
          nextAlarmDate = DateTime(
            futureDate.year,
            futureDate.month,
            futureDate.day,
            alarmSettings.dateTime.hour,
            alarmSettings.dateTime.minute,
          );
          break;
        }
      }
    }

    if (nextAlarmDate != null) {
      final newAlarm = alarmSettings.copyWith(dateTime: nextAlarmDate);
      await Alarm.set(alarmSettings: newAlarm);
      print('[RE-SCHEDULE] Alarm rescheduled for: $nextAlarmDate');
    }
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
