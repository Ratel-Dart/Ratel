import 'package:analyzer/dart/constant/value.dart';

abstract final class ConstantValues {
  static String? string(DartObject? object, String field) =>
      object?.getField(field)?.toStringValue();

  static List<String> strings(DartObject? object, String field) => [
        for (final item
            in object?.getField(field)?.toListValue() ?? const <DartObject>[])
          item.toStringValue() ?? '',
      ];
}
