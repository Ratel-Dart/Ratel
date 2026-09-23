import 'package:analyzer/dart/constant/value.dart';
import 'package:source_gen/source_gen.dart';

String? readString(DartObject? object, String field) {
  if (object == null) return null;
  final reader = ConstantReader(object).read(field);
  return reader.isString ? reader.stringValue : null;
}

List<String> readRoles(DartObject? object) {
  if (object == null) return const [];
  final reader = ConstantReader(object).read('roles');
  if (reader.isNull) return const [];
  return reader.listValue.map((e) => e.toStringValue() ?? '').toList();
}
