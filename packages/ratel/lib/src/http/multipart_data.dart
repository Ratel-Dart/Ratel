import 'uploaded_file.dart';

class MultipartData {
  final Map<String, String> fields;

  final List<UploadedFile> files;

  const MultipartData({this.fields = const {}, this.files = const []});

  UploadedFile? file(String field) {
    for (final file in files) {
      if (file.field == field) return file;
    }
    return null;
  }

  List<UploadedFile> filesFor(String field) =>
      files.where((file) => file.field == field).toList();
}
