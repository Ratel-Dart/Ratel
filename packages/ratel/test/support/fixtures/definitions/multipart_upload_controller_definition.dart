import 'package:ratel/runtime.dart';

import '../controllers/multipart_upload_controller.dart';

abstract final class MultipartUploadControllerDefinition {
  static const value = ControllerDefinition<MultipartUploadController>(
    create: MultipartUploadController.new,
    routes: [
      RouteDefinition<MultipartUploadController>(
        method: 'POST',
        path: '/upload',
        parameters: [
          RouteParameter(
            name: 'data',
            location: ParameterLocation.multipart,
            type: MultipartData,
          ),
        ],
        invoke: _upload,
      ),
    ],
  );

  static Object? _upload(
    MultipartUploadController controller,
    List<Object?> arguments,
  ) =>
      controller.upload(arguments[0] as MultipartData);
}
