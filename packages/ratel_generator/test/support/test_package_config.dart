import 'package:package_config/package_config.dart';

final testPackageConfig = PackageConfig([
  for (final name in const ['app', 'ratel', 'ratel_orm'])
    Package(
      name,
      Uri.parse('file:///$name/'),
      packageUriRoot: Uri.parse('file:///$name/lib/'),
      languageVersion: LanguageVersion(3, 6),
    ),
]);
