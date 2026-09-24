import 'dart:convert';

import 'package:ratel/ratel.dart';

final class MultipartUploadController {
  Future<Response> upload(MultipartData data) async {
    final avatar = data.file('avatar');
    return Response.json(data: {
      'title': data.fields['title'],
      'filename': avatar?.filename,
      'contentType': avatar?.contentType,
      'content': avatar == null ? null : utf8.decode(avatar.bytes),
      'attachments': data.filesFor('attachment').length,
    });
  }
}
