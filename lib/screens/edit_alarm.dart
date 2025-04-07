
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ExampleAlarmEditScreen extends StatefulWidget {
  const ExampleAlarmEditScreen({super.key, this.alarmSettings});

  final AlarmSettings? alarmSettings;

  @override
  State<ExampleAlarmEditScreen> createState() => _ExampleAlarmEditScreenState();
}

class _ExampleAlarmEditScreenState extends State<ExampleAlarmEditScreen> {
  bool loading = false;

  late bool creating;
  late int id;
  late DateTime selectedDateTime;
  late bool loopAudio;
  late bool vibrate;
  late double? volume;
  late String assetAudio;
  late List<bool> selectedDays;

  @override
  void initState() {
    super.initState();
    creating = widget.alarmSettings == null;

    if (creating) {
      id = DateTime.now().millisecondsSinceEpoch % 10000 + 1;
      selectedDateTime = DateTime.now().add(const Duration(minutes: 1));
      selectedDateTime = selectedDateTime.copyWith(second: 0, millisecond: 0);
      loopAudio = true;
      vibrate = true;
      volume = null;
      assetAudio = 'assets/marimba.mp3';
      selectedDays = List.filled(7, false);
    } else {
      selectedDateTime = widget.alarmSettings!.dateTime;
      loopAudio = widget.alarmSettings!.loopAudio;
      vibrate = widget.alarmSettings!.vibrate;
      volume = widget.alarmSettings!.volume;
      assetAudio = widget.alarmSettings!.assetAudioPath;
      selectedDays = List.filled(7, false);

      // ✅ Ensure selected days are loaded correctly
      loadSelectedDays().then((days) {
        if (mounted) {
          setState(() {
            selectedDays = days;
          });
        }
      });
    }
  }


  // Save selected days to SharedPreferences
  Future<void> saveSelectedDays(List<bool> selectedDays) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedDaysString = selectedDays.map((day) => day ? '1' : '0').join();
    await prefs.setString('selectedDays_${widget.alarmSettings?.id}', selectedDaysString);
  }


  // Load selected days from SharedPreferences
  Future<List<bool>> loadSelectedDays() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedDaysString = prefs.getString('selectedDays_${widget.alarmSettings?.id}');

    if (selectedDaysString != null) {
      return selectedDaysString.split('').map((day) => day == '1').toList();
    }

    // Default: No days selected
    return List.filled(7, false);
  }


  Future<void> pickTime() async {
    final res = await showTimePicker(
      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
      context: context,
    );

    if (res != null) {
      setState(() {
        final now = DateTime.now();
        selectedDateTime = now.copyWith(
          hour: res.hour,
          minute: res.minute,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
        if (selectedDateTime.isBefore(now)) {
          selectedDateTime = selectedDateTime.add(const Duration(days: 1));
        }
      });
    }
  }

  void saveAlarm() async {
    if (loading) return;
    setState(() => loading = true);



    // Create a single alarm that repeats on selected days
    final alarmSettings = AlarmSettings(
      id: widget.alarmSettings?.id ?? DateTime.now().millisecondsSinceEpoch % 10000 + 1,
      dateTime: selectedDateTime,
      loopAudio: loopAudio,
      vibrate: vibrate,
      volume: volume,
      assetAudioPath: assetAudio,
      notificationSettings: NotificationSettings(
        title: 'Alarm example',
        body: 'Your alarm is ringing',
        stopButton: 'Stop the alarm',
        icon: 'notification_icon',
      ),
    );

    // Save the selected days
    await saveSelectedDays(selectedDays);

    // Schedule the alarm
    final res = await Alarm.set(alarmSettings: alarmSettings);
    if (res && mounted) {
      Navigator.pop(context, true);
    }

    setState(() => loading = false);
  }
  // void saveAlarm() async {
  //   if (loading) return;
  //   setState(() => loading = true);
  //
  //   // Save the selected days
  //   await saveSelectedDays(selectedDays);
  //
  //   final now = DateTime.now();
  //   final baseId = DateTime.now().millisecondsSinceEpoch % 10000;
  //
  //   for (int i = 0; i < 7; i++) {
  //     if (!selectedDays[i]) continue;
  //
  //     // Calculate the next occurrence of the selected day
  //     int weekday = i + 1; // DateTime weekday is from 1 (Mon) to 7 (Sun)
  //     DateTime nextAlarmDateTime = selectedDateTime;
  //
  //     // Adjust to match the selected weekday
  //     int currentWeekday = nextAlarmDateTime.weekday;
  //     int daysUntil = (weekday - currentWeekday) % 7;
  //     if (daysUntil == 0 && nextAlarmDateTime.isBefore(now)) {
  //       daysUntil = 7;
  //     }
  //     nextAlarmDateTime = nextAlarmDateTime.add(Duration(days: daysUntil));
  //
  //     final alarmSettings = AlarmSettings(
  //       id: baseId + i,
  //       dateTime: nextAlarmDateTime,
  //       loopAudio: loopAudio,
  //       vibrate: vibrate,
  //       volume: volume,
  //       assetAudioPath: assetAudio,
  //       notificationSettings: NotificationSettings(
  //         title: 'Alarm',
  //         body: 'Your alarm is ringing',
  //         stopButton: 'Stop the alarm',
  //         icon: 'notification_icon',
  //       ),
  //     );
  //
  //     await Alarm.set(alarmSettings: alarmSettings);
  //   }
  //
  //   if (mounted) Navigator.pop(context, true);
  //   setState(() => loading = false);
  // }

  void deleteAlarm() {
    Alarm.stop(widget.alarmSettings!.id).then((res) {
      if (res && mounted) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(color: Colors.blueAccent),
                ),
              ),
              TextButton(
                onPressed: saveAlarm,
                child: loading
                    ? const CircularProgressIndicator()
                    : Text(
                  'Save',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(color: Colors.blueAccent),
                ),
              ),
            ],
          ),
          RawMaterialButton(
            onPressed: pickTime,
            fillColor: Colors.grey[200],
            child: Container(
              margin: const EdgeInsets.all(20),
              child: Text(
                TimeOfDay.fromDateTime(selectedDateTime).format(context),
                style: Theme.of(context)
                    .textTheme
                    .displayMedium!
                    .copyWith(color: Colors.blueAccent),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              final dayName = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][index];
              return Expanded(
                child: Column(
                  children: [
                    Text(dayName),
                    Checkbox(
                      value: selectedDays[index], // Reflect the saved state
                      onChanged: (value) {
                        setState(() {
                          selectedDays[index] = value!;
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Loop alarm audio',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Switch(
                value: loopAudio,
                onChanged: (value) => setState(() => loopAudio = value),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vibrate',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Switch(
                value: vibrate,
                onChanged: (value) => setState(() => vibrate = value),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sound',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              DropdownButton(
                value: assetAudio,
                items: const [
                  DropdownMenuItem<String>(
                    value: 'assets/marimba.mp3',
                    child: Text('Marimba'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'assets/nokia.mp3',
                    child: Text('Nokia'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'assets/mozart.mp3',
                    child: Text('Mozart'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'assets/star_wars.mp3',
                    child: Text('Star Wars'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'assets/one_piece.mp3',
                    child: Text('One Piece'),
                  ),
                ],
                onChanged: (value) => setState(() => assetAudio = value!),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Custom volume',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Switch(
                value: volume != null,
                onChanged: (value) =>
                    setState(() => volume = value ? 0.5 : null),
              ),
            ],
          ),
          if (volume != null)
            SizedBox(
              height: 45,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    volume! > 0.7
                        ? Icons.volume_up_rounded
                        : volume! > 0.1
                        ? Icons.volume_down_rounded
                        : Icons.volume_mute_rounded,
                  ),
                  Expanded(
                    child: Slider(
                      value: volume!,
                      onChanged: (value) {
                        setState(() => volume = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (!creating)
            TextButton(
              onPressed: deleteAlarm,
              child: Text(
                'Delete Alarm',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(color: Colors.red),
              ),
            ),
          const SizedBox(),
        ],
      ),
    );
  }
}