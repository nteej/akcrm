import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/job.dart';

class JobProvider extends ChangeNotifier {
  static const String _runningJobKey = 'running_job';
  static const String _jobStartTimeKey = 'job_start_time';

  final storage = const FlutterSecureStorage();

  Job? _runningJob;
  DateTime? _jobStartTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isPaused = false;

  Job? get runningJob => _runningJob;
  DateTime? get jobStartTime => _jobStartTime;
  Duration get elapsed => _elapsed;
  bool get isPaused => _isPaused;
  bool get isJobRunning => _runningJob != null;

  JobProvider() {
    _loadRunningJob();
  }

  Future<void> _loadRunningJob() async {
    try {
      final jobData = await storage.read(key: _runningJobKey);
      final startTimeData = await storage.read(key: _jobStartTimeKey);

      if (jobData != null && startTimeData != null) {
        final jobMap = jsonDecode(jobData);
        _runningJob = Job.fromJson(jobMap);
        _jobStartTime = DateTime.parse(startTimeData);

        // Calculate elapsed time
        _elapsed = DateTime.now().difference(_jobStartTime!);

        // Start timer
        _startTimer();

        log('Loaded running job: ${_runningJob?.service}, elapsed: $_elapsed');
        notifyListeners();
      }
    } catch (e) {
      log('Error loading running job: $e');
    }
  }

  Future<void> startJob(Job job, DateTime startTime) async {
    _runningJob = job;
    _jobStartTime = startTime;
    _elapsed = Duration.zero;
    _isPaused = false;

    // Save to storage
    await storage.write(key: _runningJobKey, value: jsonEncode(job.toJson()));
    await storage.write(key: _jobStartTimeKey, value: startTime.toIso8601String());

    _startTimer();
    notifyListeners();

    log('Started job: ${job.service}');
  }

  Future<void> stopJob() async {
    _timer?.cancel();
    _runningJob = null;
    _jobStartTime = null;
    _elapsed = Duration.zero;
    _isPaused = false;

    // Clear storage
    await storage.delete(key: _runningJobKey);
    await storage.delete(key: _jobStartTimeKey);

    notifyListeners();

    log('Stopped job');
  }

  void pauseJob() {
    _isPaused = true;
    notifyListeners();
    log('Paused job');
  }

  void resumeJob() {
    _isPaused = false;
    notifyListeners();
    log('Resumed job');
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && _jobStartTime != null) {
        _elapsed = DateTime.now().difference(_jobStartTime!);
        notifyListeners();
      }
    });
  }

  String getElapsedTimeString() {
    final hours = _elapsed.inHours;
    final minutes = _elapsed.inMinutes % 60;
    final seconds = _elapsed.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}