final class RequestLimits {
  const RequestLimits({
    this.maxRequestBodyBytes = defaultBytes,
    this.maxBodyDrainBytes = defaultBytes,
  });

  static const int defaultBytes = 1024 * 1024;

  final int maxRequestBodyBytes;
  final int maxBodyDrainBytes;
}
