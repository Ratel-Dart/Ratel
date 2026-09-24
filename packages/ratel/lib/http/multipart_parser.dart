import 'dart:io';

import '../src/http/multipart_parser.dart';
import 'multipart_data.dart';

Future<MultipartData> readMultipart(HttpRequest request, int maxBytes) =>
    MultipartParser.read(request, maxBytes);
