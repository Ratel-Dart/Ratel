import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import '../annotations/geral_annotations.dart';

class Response {
  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;

  Response({
    required this.statusCode,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'application/json',
    },
  });

  static Response from(dynamic value) {
    if (value is Response) return value;
    return Response(
      statusCode: HttpStatus.ok,
      data: value,
    );
  }

  String toJson() {
    if (data == null) return '';

    if (data is String) return data;

    if (data is List) {
      return jsonEncode(
        (data as List).map((item) => convertToJson(item)).toList(),
      );
    }

    if (data is Map) {
      return jsonEncode(
        (data as Map).map((key, value) => MapEntry(key, convertToJson(value))),
      );
    }

    return jsonEncode(convertToJson(data));
  }

  dynamic convertToJson(dynamic obj) {
    if (obj is Map ||
        obj is List ||
        obj is String ||
        obj is num ||
        obj is bool) {
      return obj;
    }

    if (obj != null && isSerializable(obj)) {
      return _objectToJson(obj);
    }

    return obj.toString();
  }

  dynamic _objectToJson(dynamic obj) {
    final instanceMirror = reflect(obj);
    final classMirror = instanceMirror.type;
    final Map<String, dynamic> result = {};

    classMirror.declarations.forEach((symbol, decl) {
      if (decl is VariableMirror && !decl.isStatic) {
        final fieldName = MirrorSystem.getName(symbol);
        if (fieldName.startsWith('_')) return;
        try {
          var value = instanceMirror.getField(symbol).reflectee;
          result[fieldName] = convertToJson(value);
        } catch (e) {}
      }
    });

    classMirror.instanceMembers.forEach((symbol, methodMirror) {
      if (methodMirror.isGetter &&
          methodMirror.owner == classMirror &&
          !['hashCode', 'runtimeType', 'toString']
              .contains(MirrorSystem.getName(symbol))) {
        final getterName = MirrorSystem.getName(symbol);
        if (result.containsKey(getterName)) return;
        if (getterName.startsWith('_')) return;
        try {
          var value = instanceMirror.getField(symbol).reflectee;
          result[getterName] = convertToJson(value);
        } catch (e) {}
      }
    });

    return result;
  }

  bool isSerializable(Object obj) {
    final classMirror = reflectClass(obj.runtimeType);
    return classMirror.metadata
        .any((annotation) => annotation.reflectee is Json);
  }

  void send(HttpResponse response) {
    response.statusCode = statusCode;
    headers.forEach((key, value) => response.headers.set(key, value));
    final jsonResponse = toJson();
    if (jsonResponse.isNotEmpty) {
      response.write(jsonResponse);
    }
    response.close();
  }
}
