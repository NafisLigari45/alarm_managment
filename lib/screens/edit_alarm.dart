
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
  bool get areAllDaysSelected => selectedDays.every((day) => day);
  bool get areSomeDaysSelected => selectedDays.any((day) => day) && !areAllDaysSelected;
  @override
  void initState() {
    super.initState();
    creating = widget.alarmSettings == null;

    if (creating) {
      // Generate a base ID that's divisible by 10
      id = (DateTime.now().millisecondsSinceEpoch % 100000) ~/ 10 * 10;
      selectedDateTime = DateTime.now()
          .add(const Duration(minutes: 1))
          .copyWith(second: 0, millisecond: 0);
      loopAudio = true;
      vibrate = true;
      volume = null;
      assetAudio = 'assets/marimba.mp3';
      selectedDays = List.filled(7, false);
      print('[INIT] Creating new alarm with id: $id');
    } else {
      selectedDateTime = widget.alarmSettings!.dateTime;
      loopAudio = widget.alarmSettings!.loopAudio;
      vibrate = widget.alarmSettings!.vibrate;
      volume = widget.alarmSettings!.volume;
      assetAudio = widget.alarmSettings!.assetAudioPath;
      selectedDays = List.filled(7, false);
      print(
        '[INIT] Editing existing alarm with id: ${widget.alarmSettings!.id}',
      );

      loadSelectedDays().then((days) {
        if (mounted) {
          setState(() {
            selectedDays = days;
            print('[LOAD] Loaded selectedDays from prefs: $selectedDays');
          });
        }
      });
    }
  }


  void toggleAllDays(bool? value) {
    setState(() {
      if (value != null) {
        selectedDays = List.filled(7, value);
        print('[SELECT ALL] Set all days to $value');
      }
    });
  }

  void updateSelectAllState(int index, bool? value) {
    setState(() {
      selectedDays[index] = value ?? false;
      print('[CHECKBOX] Updated day $index to $value');
    });
  }

  Future<void> saveSelectedDays(int alarmId, List<bool> selectedDays) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedDaysString =
        selectedDays.map((day) => day ? '1' : '0').join();
    await prefs.setString('selectedDays_$alarmId', selectedDaysString);
    print('[SAVE] Saved selectedDays for alarm $alarmId: $selectedDaysString');
    print('[SAVE] Full prefs: ${prefs.getKeys()}'); // Debug all stored keys
  }

  Future<List<bool>> loadSelectedDays() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedDaysString = prefs.getString(
      'selectedDays_${widget.alarmSettings?.id}',
    );
    if (selectedDaysString != null) {
      print('[LOAD] Found selectedDays string in prefs: $selectedDaysString');
      return selectedDaysString.split('').map((day) => day == '1').toList();
    }
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
        print('[PICK TIME] New selected time: $selectedDateTime');
      });
    }
  }

  void saveAlarm() async {
    if (loading) return;
    setState(() => loading = true);

    // Use the same ID generation logic as in initState
    final alarmId = creating
        ? (DateTime.now().millisecondsSinceEpoch % 100000) ~/ 10 * 10
        : widget.alarmSettings!.id;

    await saveSelectedDays(alarmId, selectedDays);

    final now = DateTime.now();
    DateTime? nextAlarmDateTime;

    // Check today first if selected
    int todayIndex = now.weekday % 7; // 0=Sun, 1=Mon, ..., 6=Sat
    if (selectedDays[todayIndex]) {
      final todayCandidate = DateTime(
        now.year,
        now.month,
        now.day,
        selectedDateTime.hour,
        selectedDateTime.minute,
      );
      if (todayCandidate.isAfter(now)) {
        nextAlarmDateTime = todayCandidate;
      }
    }

    // If today doesn't work or isn't selected, find next selected day
    if (nextAlarmDateTime == null) {
      for (int i = 1; i <= 7; i++) {
        final futureDate = now.add(Duration(days: i));
        final dayIndex = futureDate.weekday % 7;
        if (selectedDays[dayIndex]) {
          nextAlarmDateTime = DateTime(
            futureDate.year,
            futureDate.month,
            futureDate.day,
            selectedDateTime.hour,
            selectedDateTime.minute,
          );
          break;
        }
      }
    }

    if (nextAlarmDateTime == null) {
      print('[SCHEDULE] No valid alarm date found');
      setState(() => loading = false);
      return;
    }

    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: nextAlarmDateTime,
      loopAudio: loopAudio,
      vibrate: vibrate,
      volume: volume,
      assetAudioPath: assetAudio,
      notificationSettings: NotificationSettings(
        title: 'Alarm',
        body: 'Your alarm is ringing',
        stopButton: 'Stop the alarm',
        icon: 'notification_icon',
      ),
    );

    await Alarm.set(alarmSettings: alarmSettings);
    print('[SCHEDULE] Next alarm set for: $nextAlarmDateTime with ID: $alarmId');

    if (mounted) Navigator.pop(context, true);
    setState(() => loading = false);
  }

  void deleteAlarm() {
    Alarm.stop(widget.alarmSettings!.id).then((res) {
      print(
        '[DELETE] Deleted alarm with id: ${widget.alarmSettings!.id}, result: $res',
      );
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
          // Top Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge!.copyWith(color: Colors.blueAccent),
                ),
              ),
              TextButton(
                onPressed: saveAlarm,
                child:
                    loading
                        ? const CircularProgressIndicator()
                        : Text(
                          'Save',
                          style: Theme.of(context).textTheme.titleLarge!
                              .copyWith(color: Colors.blueAccent),
                        ),
              ),
            ],
          ),

          // Time Picker
          RawMaterialButton(
            onPressed: pickTime,
            fillColor: Colors.grey[200],
            child: Container(
              margin: const EdgeInsets.all(20),
              child: Text(
                TimeOfDay.fromDateTime(selectedDateTime).format(context),
                style: Theme.of(
                  context,
                ).textTheme.displayMedium!.copyWith(color: Colors.blueAccent),
              ),
            ),
          ),

          // Select All checkbox
          Row(
            children: [
              Text('Select All'),
              Checkbox(
                value: areAllDaysSelected,
                tristate: true,
                onChanged: toggleAllDays,
              ),
            ],
          ),
          // Weekday Checkboxes
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          //   children: List.generate(7, (index) {
          //     final dayName =
          //         ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][index];
          //     return Expanded(
          //       child: Column(
          //         children: [
          //           Text(dayName),
          //           Checkbox(
          //             value: selectedDays[index],
          //             onChanged: (value) {
          //               setState(() {
          //                 selectedDays[index] = value!;
          //                 print('[CHECKBOX] Toggled $dayName to $value');
          //               });
          //             },
          //           ),
          //         ],
          //       ),
          //     );
          //   }),
          // ),

          /// Individual day checkboxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              final dayName = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][index];
              return Expanded(
                child: Column(
                  children: [
                    Text(dayName),
                    Checkbox(
                      value: selectedDays[index],
                      onChanged: (value) => updateSelectAllState(index, value),
                    ),
                  ],
                ),
              );
            }),
          ),
          // Loop, Vibrate, Sound
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
              Text('Vibrate', style: Theme.of(context).textTheme.titleMedium),
              Switch(
                value: vibrate,
                onChanged: (value) => setState(() => vibrate = value),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sound', style: Theme.of(context).textTheme.titleMedium),
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
                onChanged: (value) {
                  setState(() => assetAudio = value!);
                  print('[AUDIO] Selected sound: $assetAudio');
                },
              ),
            ],
          ),

          // Volume
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Custom volume',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Switch(
                value: volume != null,
                onChanged: (value) {
                  setState(() => volume = value ? 0.5 : null);
                  print(
                    '[VOLUME] Custom volume ${value ? "enabled" : "disabled"}',
                  );
                },
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
                        print('[SLIDER] Volume set to $volume');
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Delete
          if (!creating)
            TextButton(
              onPressed: deleteAlarm,
              child: Text(
                'Delete Alarm',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium!.copyWith(color: Colors.red),
              ),
            ),

          const SizedBox(),
        ],
      ),
    );
  }
}
