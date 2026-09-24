import 'dart:io';

import '../http/multipart_data.dart';
import '../http/multipart_parser.dart';
import '../http/request_body_reader.dart';
import '../http/request_context.dart';
import '../http/request_parameters.dart';
import '../routing/parameter_location.dart';
import '../routing/route_parameter.dart';
import '../serialization/json_codecs.dart';

abstract final class ArgumentResolver {
  static Future<List<Object?>> resolve(
    List<RouteParameter> parameters,
    RequestContext ctx,
    JsonCodecs codecs,
  ) async {
    final multipart = parameters.any(
            (parameter) => parameter.location == ParameterLocation.multipart)
        ? await MultipartParser.read(
            ctx.request, ctx.limits.maxRequestBodyBytes)
        : null;
    final arguments = <Object?>[];
    for (final parameter in parameters) {
      arguments.add(await _resolve(parameter, ctx, codecs, multipart));
    }
    return arguments;
  }

  static List<Object?> resolveSocket(
    List<RouteParameter> parameters,
    WebSocket socket,
    RequestContext ctx,
  ) =>
      [
        for (final parameter in parameters)
          switch (parameter.location) {
            ParameterLocation.webSocket => socket,
            ParameterLocation.context => ctx,
            _ => null,
          },
      ];

  static Future<Object?> _resolve(
    RouteParameter parameter,
    RequestContext ctx,
    JsonCodecs codecs,
    MultipartData? multipart,
  ) async =>
      switch (parameter.location) {
        ParameterLocation.path => RequestParameters.coerce(
            parameter.name,
            ctx.pathParams[parameter.name],
            parameter.type,
          ),
        ParameterLocation.query => RequestParameters.coerce(
            parameter.name,
            ctx.request.uri.queryParameters[parameter.name],
            parameter.type,
          ),
        ParameterLocation.header => RequestParameters.coerce(
            parameter.name,
            ctx.request.headers.value(parameter.name),
            parameter.type,
          ),
        ParameterLocation.cookie => RequestParameters.coerce(
            parameter.name,
            RequestParameters.cookieValue(ctx.request.cookies, parameter.name),
            parameter.type,
          ),
        ParameterLocation.body =>
          _decodeBody(parameter, await _bodyJson(ctx, multipart), codecs),
        ParameterLocation.context => ctx,
        ParameterLocation.multipart => multipart,
        ParameterLocation.webSocket => null,
      };

  static Future<Map<String, dynamic>> _bodyJson(
    RequestContext ctx,
    MultipartData? multipart,
  ) async {
    if (multipart != null) return Map<String, dynamic>.from(multipart.fields);
    final body = await RequestBodyReader.readLimited(
      ctx.request,
      ctx.limits.maxRequestBodyBytes,
      maxDrainBytes: ctx.limits.maxBodyDrainBytes,
    );
    return body.isEmpty
        ? const <String, dynamic>{}
        : RequestBodyReader.decode(ctx.request, body);
  }

  static Object? _decodeBody(
    RouteParameter parameter,
    Map<String, dynamic> json,
    JsonCodecs codecs,
  ) {
    final decode = codecs.forType(parameter.type)?.decode;
    if (decode == null) {
      throw StateError(
        'No JSON decoder is registered for ${parameter.type}, the body of '
        'parameter "${parameter.name}".',
      );
    }
    return decode(json);
  }
}
