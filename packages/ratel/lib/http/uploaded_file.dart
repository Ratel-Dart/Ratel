class UploadedFile {
  final String field;

  final String? filename;

  final String? contentType;

  final List<int> bytes;

  const UploadedFile({
    required this.field,
    required this.bytes,
    this.filename,
    this.contentType,
  });
}
