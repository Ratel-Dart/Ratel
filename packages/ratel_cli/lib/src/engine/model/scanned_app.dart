import 'scanned_controller.dart';
import 'scanned_dto.dart';

final class ScannedApp {
  const ScannedApp({required this.controllers, required this.dtos});

  final List<ScannedController> controllers;
  final List<ScannedDto> dtos;
}
