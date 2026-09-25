import 'package:ratel/src/http/utf8_content_type.dart';
import 'package:test/test.dart';

void main() {
  group('Utf8ContentType.forText', () {
    test('adds charset=utf-8 to a text type', () {
      expect(
        Utf8ContentType.forText('text/plain'),
        'text/plain; charset=utf-8',
      );
    });

    test('adds charset=utf-8 to JSON and +json types', () {
      expect(
        Utf8ContentType.forText('application/json'),
        'application/json; charset=utf-8',
      );
      expect(
        Utf8ContentType.forText('application/vnd.api+json'),
        'application/vnd.api+json; charset=utf-8',
      );
    });

    test('matches the media type regardless of case', () {
      expect(Utf8ContentType.forText('Text/HTML'), 'Text/HTML; charset=utf-8');
    });

    test('keeps a charset=utf-8 already given', () {
      expect(
        Utf8ContentType.forText('application/json; charset=utf-8'),
        'application/json; charset=utf-8',
      );
    });

    test('replaces another charset with utf-8', () {
      expect(
        Utf8ContentType.forText('text/plain;charset=ISO-8859-1; format=flowed'),
        'text/plain; charset=utf-8; format=flowed',
      );
    });

    test('keeps the other parameters', () {
      expect(
        Utf8ContentType.forText('text/plain; format=flowed'),
        'text/plain; format=flowed; charset=utf-8',
      );
    });

    test('leaves a binary type without a charset alone', () {
      expect(
        Utf8ContentType.forText('application/octet-stream'),
        'application/octet-stream',
      );
    });

    test('drops empty parameters', () {
      expect(
        Utf8ContentType.forText('text/plain;'),
        'text/plain; charset=utf-8',
      );
      expect(
        Utf8ContentType.forText('text/plain;; format=flowed;'),
        'text/plain; format=flowed; charset=utf-8',
      );
    });

    test('finds a charset written with spaces around the equals sign', () {
      expect(
        Utf8ContentType.forText('text/plain ; charset = latin1'),
        'text/plain; charset=utf-8',
      );
    });

    test('keeps a single charset when several are given', () {
      expect(
        Utf8ContentType.forText(
          'text/plain; charset=latin1; format=flowed; Charset=ascii',
        ),
        'text/plain; charset=utf-8; format=flowed',
      );
    });

    test('does not mistake a parameter named like charset', () {
      expect(
        Utf8ContentType.forText('text/plain; charsets=a'),
        'text/plain; charsets=a; charset=utf-8',
      );
    });
  });

  group('Utf8ContentType.forBytes', () {
    test('adds charset=utf-8 to a text type', () {
      expect(Utf8ContentType.forBytes('text/css'), 'text/css; charset=utf-8');
    });

    test('keeps the charset given', () {
      expect(
        Utf8ContentType.forBytes('text/plain; charset=iso-8859-1'),
        'text/plain; charset=iso-8859-1',
      );
    });

    test('leaves a binary type alone', () {
      expect(Utf8ContentType.forBytes('image/png'), 'image/png');
    });

    test('drops empty parameters', () {
      expect(Utf8ContentType.forBytes('text/css;'), 'text/css; charset=utf-8');
    });

    test('keeps a charset written with spaces around the equals sign', () {
      expect(
        Utf8ContentType.forBytes('text/plain; charset = iso-8859-1'),
        'text/plain; charset = iso-8859-1',
      );
    });
  });
}
