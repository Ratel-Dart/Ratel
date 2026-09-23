import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:ratel_generator/builder.dart';

import 'stub_packages.dart';
import 'test_package_config.dart';

const _bannerLine =
    '// **************************************************************************';

Future<String> generate(String input, Map<String, String> sources) async {
  final result = await _run(input, sources);
  final output = result.readerWriter.testing.readString(_outputId(input));
  final lines = output.split('\n');
  final start = lines.lastIndexOf(_bannerLine) + 1;
  return lines.skip(start).join('\n').trim();
}

Future<List<String>> generateErrors(
  String input,
  Map<String, String> sources,
) async {
  try {
    final result = await _run(input, sources);
    return result.errors.toList();
  } catch (error) {
    return [error.toString()];
  }
}

AssetId _outputId(String input) {
  final id = makeAssetId(input);
  return AssetId(
    id.package,
    '${id.path.substring(0, id.path.length - '.dart'.length)}.ratel.dart',
  );
}

Future<TestBuilderResult> _run(String input, Map<String, String> sources) =>
    testBuilder(
      ratelBuilder(const BuilderOptions({})),
      {...stubPackages, ...sources},
      generateFor: {input},
      rootPackage: makeAssetId(input).package,
      flattenOutput: true,
      packageConfig: testPackageConfig,
    );

Future<List<String>> generatedPaths(
  String input,
  Map<String, String> sources,
) async {
  final result = await _run(input, sources);
  return result.outputs.map((id) => '$id').toList();
}
