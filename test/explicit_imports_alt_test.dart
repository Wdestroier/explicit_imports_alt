// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart'
    show AnalysisRuleTest;
import 'package:explicit_imports_alt/explicit_imports_alt.dart'
    show ExplicitImportsAltRule;
import 'package:test_reflective_loader/test_reflective_loader.dart'
    show defineReflectiveSuite, defineReflectiveTests, reflectiveTest;

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ExplicitImportsAltTest);
  });
}

@reflectiveTest
class ExplicitImportsAltTest extends AnalysisRuleTest {
  @override
  String get analysisRule => 'explicit_imports';

  @override
  void setUp() {
    final somePackage = newPackage('some_pkg');
    somePackage.addFile(
      'lib/some_pkg.dart',
      'class SomePkg { const SomePkg(); } const int someValue = 1;',
    );

    final flutter = newPackage('flutter');
    flutter.addFile('lib/material.dart', 'class MaterialApp {}');
    flutter.addFile('lib/cupertino.dart', 'class CupertinoApp {}');

    final materialUi = newPackage('material_ui');
    materialUi.addFile('lib/material_ui.dart', 'class MaterialUiApp {}');

    final cupertinoUi = newPackage('cupertino_ui');
    cupertinoUi.addFile('lib/cupertino_ui.dart', 'class CupertinoUiApp {}');

    final flutterTest = newPackage('flutter_test');
    flutterTest.addFile('lib/flutter_test.dart', 'void testWidgets() {}');

    rule = ExplicitImportsAltRule();
    super.setUp();
  }

  Future<void> test_package_import_is_linted_by_default() async {
    const import = "import 'package:some_pkg/some_pkg.dart';";
    await assertDiagnostics('$import\nfinal _ = const SomePkg();\n', [
      lint(0, import.length),
    ]);
  }

  Future<void> test_relative_import_is_linted_by_default() async {
    newFile('$testPackageLibPath/local.dart', 'class Local { const Local(); }');

    const import = "import 'local.dart';";
    await assertDiagnostics('$import\nfinal _ = const Local();\n', [
      lint(0, import.length),
    ]);
  }

  Future<void> test_dart_imports_are_linted_by_default() async {
    const import = "import 'dart:math';";
    await assertDiagnostics('$import\nfinal _ = Random();\n', [
      lint(0, import.length),
    ]);
  }

  Future<void> test_flutter_material_import_is_linted_by_default() async {
    const import = "import 'package:flutter/material.dart';";
    await assertDiagnostics('$import\nfinal _ = MaterialApp();\n', [
      lint(0, import.length),
    ]);
  }

  Future<void> test_flutter_cupertino_import_is_linted_by_default() async {
    const import = "import 'package:flutter/cupertino.dart';";
    await assertDiagnostics('$import\nfinal _ = CupertinoApp();\n', [
      lint(0, import.length),
    ]);
  }

  Future<void> test_flutter_test_import_is_linted_by_default() async {
    const import = "import 'package:flutter_test/flutter_test.dart';";
    await assertDiagnostics('$import\nfinal _ = testWidgets;\n', [
      lint(0, import.length),
    ]);
  }

  Future<void> test_configured_package_is_excluded() async {
    newFile('$testPackageRootPath/analysis_options.yaml', '''
plugins:
  explicit_imports_alt:
    path: .
    # exclude_packages:
    #   - some_pkg
''');
    await assertNoDiagnostics(
      "import 'package:some_pkg/some_pkg.dart';\n"
      'final _ = const SomePkg();\n',
    );
  }

  Future<void> test_workspace_configured_package_is_excluded() async {
    newFile('$workspaceRootPath/analysis_options.yaml', '''
plugins:
  explicit_imports_alt:
    path: .
    # exclude_packages:
    #   - some_pkg
''');
    await assertNoDiagnostics(
      "import 'package:some_pkg/some_pkg.dart';\n"
      'final _ = const SomePkg();\n',
    );
  }

  Future<void> test_configured_uri_glob_is_excluded() async {
    newFile('$testPackageRootPath/analysis_options.yaml', '''
plugins:
  explicit_imports_alt:
    path: .
    # exclude_packages:
    #   - package:some_pkg/**
''');
    await assertNoDiagnostics(
      "import 'package:some_pkg/some_pkg.dart';\n"
      'final _ = const SomePkg();\n',
    );
  }

  Future<void> test_commented_yaml_exclusion_list_is_excluded() async {
    newFile('$testPackageRootPath/analysis_options.yaml', '''
plugins:
  explicit_imports_alt:
    path: .
    # exclude_packages:
    #   - dart:**
    #   - material_ui
    #   - cupertino_ui
    #   - flutter_test
''');
    await assertNoDiagnostics(
      "import 'dart:math';\n"
      "import 'package:material_ui/material_ui.dart';\n"
      "import 'package:cupertino_ui/cupertino_ui.dart';\n"
      "import 'package:flutter_test/flutter_test.dart';\n"
      'final random = Random();\n'
      'final material = MaterialUiApp();\n'
      'final cupertino = CupertinoUiApp();\n'
      'final widgets = testWidgets;\n',
    );
  }

  Future<void> test_as_prefix_is_allowed() async {
    const import = "import 'package:some_pkg/some_pkg.dart' as some;";
    await assertNoDiagnostics('$import\nfinal _ = const some.SomePkg();\n');
  }

  Future<void> test_show_combinator_is_allowed() async {
    const import = "import 'package:some_pkg/some_pkg.dart' show SomePkg;";
    await assertNoDiagnostics('$import\nfinal _ = const SomePkg();\n');
  }

  Future<void> test_hide_only_does_not_make_import_explicit() async {
    const import = "import 'package:some_pkg/some_pkg.dart' hide SomePkg;";
    await assertDiagnostics('$import\nfinal _ = someValue;\n', [
      lint(0, import.length),
    ]);
  }
}
