import 'package:flutter/material.dart';
import '../models/routine.dart';
import '../models/alarm.dart';
import '../services/shared_preferences_storage.dart';

class SharedPrefsTestScreen extends StatefulWidget {
  const SharedPrefsTestScreen({super.key});

  @override
  State<SharedPrefsTestScreen> createState() => _SharedPrefsTestScreenState();
}

class _SharedPrefsTestScreenState extends State<SharedPrefsTestScreen> {
  List<Routine> _routines = [];
  List<Alarm> _alarms = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final routines = await sharedPrefsStorage.getAllRoutines();
    final alarms = await sharedPrefsStorage.getAllAlarms();

    setState(() {
      _routines = routines;
      _alarms = alarms;
      _isLoading = false;
    });
  }

  Future<void> _addSampleRoutine() async {
    final nextId = await sharedPrefsStorage.getNextRoutineId();
    final routine = Routine(
      id: nextId,
      name: 'Sample Routine ${_routines.length + 1}',
      startTime: const TimeOfDay(hour: 19, minute: 0),
      endTime: const TimeOfDay(hour: 22, minute: 0),
      color: Colors.orange,
      brightness: 0.8,
      temperature: 3000,
    );

    await sharedPrefsStorage.saveRoutine(routine);
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Routine saved to SharedPreferences!')),
      );
    }
  }

  Future<void> _addSampleAlarm() async {
    final nextId = await sharedPrefsStorage.getNextAlarmId();
    final alarm = Alarm(
      id: nextId,
      name: 'Sample Alarm ${_alarms.length + 1}',
      wakeUpTime: const TimeOfDay(hour: 7, minute: 30),
      durationMinutes: 20,
    );

    await sharedPrefsStorage.saveAlarm(alarm);
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alarm saved to SharedPreferences!')),
      );
    }
  }

  Future<void> _clearAllData() async {
    await sharedPrefsStorage.clearAllData();
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All SharedPreferences data cleared!')),
      );
    }
  }

  Future<void> _exportData() async {
    final data = await sharedPrefsStorage.exportData();

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exported Data'),
          content: SingleChildScrollView(
            child: Text(
              'Routines: ${data['routines']?.length ?? 0}\n'
              'Alarms: ${data['alarms']?.length ?? 0}\n'
              'Exported at: ${data['exported_at']}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SharedPreferences Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'SharedPreferences Storage Test',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Action buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _addSampleRoutine,
                        icon: const Icon(Icons.schedule),
                        label: const Text('Add Sample Routine'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addSampleAlarm,
                        icon: const Icon(Icons.alarm),
                        label: const Text('Add Sample Alarm'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _exportData,
                        icon: const Icon(Icons.download),
                        label: const Text('Export Data'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _clearAllData,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Data display
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Routines (${_routines.length})',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (_routines.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No routines stored'),
                              ),
                            )
                          else
                            ..._routines.map((routine) => Card(
                              child: ListTile(
                                title: Text(routine.name),
                                subtitle: Text(
                                  'ID: ${routine.id} | '
                                  '${routine.startTime.format(context)} - ${routine.endTime.format(context)}\n'
                                  'Brightness: ${(routine.brightness * 100).round()}% | '
                                  'Temperature: ${routine.temperature.round()}K',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    await sharedPrefsStorage.deleteRoutine(routine.id!);
                                    await _loadData();
                                  },
                                ),
                              ),
                            )),

                          const SizedBox(height: 20),

                          Text(
                            'Alarms (${_alarms.length})',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (_alarms.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No alarms stored'),
                              ),
                            )
                          else
                            ..._alarms.map((alarm) => Card(
                              child: ListTile(
                                title: Text(alarm.name),
                                subtitle: Text(
                                  'ID: ${alarm.id} | '
                                  'Wake up: ${alarm.wakeUpTime.format(context)}\n'
                                  'Duration: ${alarm.durationMinutes} minutes | '
                                  'Start: ${alarm.startTime.format(context)}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    await sharedPrefsStorage.deleteAlarm(alarm.id!);
                                    await _loadData();
                                  },
                                ),
                              ),
                            )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}