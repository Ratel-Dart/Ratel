import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

void main() {
  group('JwtValidator.validateToken', () {
    final validator = JwtValidator('secret');

    String token({Duration? expiresIn}) =>
        JWT({'sub': 'user-1'}).sign(SecretKey('secret'), expiresIn: expiresIn);

    test('accepts a valid token carrying exp', () {
      final claims =
          validator.validateToken(token(expiresIn: Duration(hours: 1)));
      expect(claims, isNotNull);
      expect(claims!['sub'], 'user-1');
    });

    test('rejects a token without exp when expiry is required', () {
      expect(validator.validateToken(token()), isNull);
    });

    test('rejects an expired token', () {
      expect(
        validator.validateToken(token(expiresIn: Duration(seconds: -10))),
        isNull,
      );
    });

    test('rejects a token signed with a different secret', () {
      final other = JWT({'sub': 'x'})
          .sign(SecretKey('wrong'), expiresIn: Duration(hours: 1));
      expect(validator.validateToken(other), isNull);
    });

    test('accepts a token without exp when requireExpiry is false', () {
      final lenient = JwtValidator('secret', requireExpiry: false);
      expect(lenient.validateToken(token()), isNotNull);
    });
  });
}
