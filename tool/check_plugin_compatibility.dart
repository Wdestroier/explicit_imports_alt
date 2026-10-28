import 'dart:convert' show jsonEncode;
import 'dart:io' show Directory, File, Platform, Process, stdout, stderr;

/// Resolves and runs both plugins in the same analysis server, without starting
/// build_runner (the fixture deliberately has no build_runner dependency).
Future<void> main() async {
  final pluginRoot = File.fromUri(
    Platform.script,
  ).parent.parent.path.replaceAll('\\', '/');
  final fixture = Directory.systemTemp.createTempSync(
    'explicit_imports_compat_',
  );
  try {
    File('${fixture.path}/pubspec.yaml').writeAsStringSync('''
name: plugin_compatibility
publish_to: none
environment:
  sdk: ^3.13.0
dependencies:
  explicit_imports_alt:
    path: ${jsonEncode(pluginRoot)}
  auto_build_runner: 1.0.0
''');
    File('${fixture.path}/analysis_options.yaml').writeAsStringSync('''
plugins:
  explicit_imports_alt:
    path: ${jsonEncode(pluginRoot)}
  auto_build_runner:
    version: 1.0.0
''');
    final lib = Directory('${fixture.path}/lib')..createSync();
    File('${lib.path}/main.dart').writeAsStringSync('''
import 'dart:math';
final random = Random();
''');
    final resolution = await Process.run(Platform.resolvedExecutable, [
      'pub',
      'get',
    ], workingDirectory: fixture.path);
    stdout.write(resolution.stdout);
    stderr.write(resolution.stderr);
    if (resolution.exitCode != 0) {
      throw StateError('The two plugin dependency graphs are incompatible.');
    }
    final analysis = await Process.run(Platform.resolvedExecutable, [
      'analyze',
      '--format',
      'machine',
    ], workingDirectory: fixture.path);
    final output = '${analysis.stdout}\n${analysis.stderr}';
    stdout.write(output);
    final diagnostics = output
        .split('\n')
        .where((line) => RegExp(r'^(INFO|WARNING|ERROR)\|').hasMatch(line));
    if (analysis.exitCode != 0 ||
        diagnostics.length != 1 ||
        !diagnostics.single.toLowerCase().contains('explicit_imports') ||
        output.contains('ERROR|')) {
      throw StateError(
        'Expected only the explicit-import diagnostic with both '
        'plugins enabled (exit ${analysis.exitCode}).',
      );
    }
    stdout.writeln('Both plugins resolved and ran successfully.');
  } finally {
    fixture.deleteSync(recursive: true);
  }
}
