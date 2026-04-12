import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart';

class StepSensorSample {
  const StepSensorSample({required this.rawSteps, required this.timestamp});

  final int rawSteps;
  final DateTime timestamp;
}

class StepCounterService {
  StepCounterService._();

  static final StepCounterService instance = StepCounterService._();

  bool get isSupported => !kIsWeb;

  Future<bool> ensurePermission({bool requestIfNeeded = true}) async {
    if (!isSupported) return false;

    var status = await Permission.activityRecognition.status;
    if (!status.isGranted && requestIfNeeded) {
      status = await Permission.activityRecognition.request();
    }

    return status.isGranted;
  }

  Stream<StepSensorSample> getStepCountStream() {
    return Pedometer.stepCountStream.map((event) {
      return StepSensorSample(
        rawSteps: event.steps,
        timestamp: event.timeStamp,
      );
    });
  }
}
