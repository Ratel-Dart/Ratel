import 'scanned_controller.dart';
import 'scanned_dto.dart';
import 'scanned_entity.dart';

final class ScannedApp {
  const ScannedApp({
    this.controllers = const [],
    this.dtos = const [],
    this.entities = const [],
  });

  final List<ScannedController> controllers;
  final List<ScannedDto> dtos;
  final List<ScannedEntity> entities;
}
