import 'scanned_controller.dart';
import 'scanned_json_class.dart';

final class ScannedApp {
  const ScannedApp({required this.controllers, required this.jsonClasses});

  final List<ScannedController> controllers;
  final List<ScannedJsonClass> jsonClasses;
}
