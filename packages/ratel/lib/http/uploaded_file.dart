/// A file received in a `multipart/form-data` request.
class UploadedFile {
  /// The form field the file was uploaded under.
  final String field;

  /// The file name the client declared, if any.
  final String? filename;

  /// The content type the part declared, if any.
  final String? contentType;

  /// The raw bytes of the file.
  final List<int> bytes;

  /// Creates an uploaded file.
  const UploadedFile({
    required this.field,
    required this.bytes,
    this.filename,
    this.contentType,
  });
}
