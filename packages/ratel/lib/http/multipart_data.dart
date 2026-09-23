import 'uploaded_file.dart';

/// A parsed `multipart/form-data` body: its text [fields] and uploaded [files].
///
/// A handler receives one by declaring a parameter typed `MultipartData`.
class MultipartData {
  /// Text form fields, keyed by field name. A repeated field keeps the last
  /// value.
  final Map<String, String> fields;

  /// Uploaded files, in the order they arrived.
  final List<UploadedFile> files;

  /// Creates a parsed multipart body.
  const MultipartData({this.fields = const {}, this.files = const []});

  /// The first file uploaded under [field], or null when there is none.
  UploadedFile? file(String field) {
    for (final file in files) {
      if (file.field == field) return file;
    }
    return null;
  }

  /// Every file uploaded under [field], for a multi-file input.
  List<UploadedFile> filesFor(String field) =>
      files.where((file) => file.field == field).toList();
}
