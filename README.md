# explicit_imports_alt

A Dart analyzer plugin that flags imports unless they use a `show`
combinator or an `as` prefix.

## Install

Add the plugin to the top-level `plugins` section of your
`analysis_options.yaml`:

    plugins:
      explicit_imports_alt:
        version: ^1.0.0

The Dart analysis server should restart automatically after changing the `plugins`
section. You do not need to add this plugin to your application's
`pubspec.yaml`.

## Default behavior and optional exclusions

Every supported import is checked by default. Nothing is excluded unless you configure it. A `hide` combinator alone does not make an import explicit.

## Configure exclusions

Add the commented directive under the plugin entry in your root `analysis_options.yaml`:

    plugins:
      explicit_imports_alt:
        version: ^1.0.0
        # The commented lines below are read by the plugin!
        # exclude_packages:
        #   - dart:**
        #   - test
        #   - material_ui
        #   - cupertino_ui
        #   - flutter_test

The plugin reads this commented YAML list. Leave the `#` on each line,
uncommenting the block makes `exclude_packages` an unsupported analyzer option.

A package name, such as `material_ui`, excludes every import from that package. URI patterns can target a single import or use `*` and `**` wildcards. For example:
`package:legacy_api/src/**` excludes libraries under that path, while `dart:io`
excludes only that Dart SDK library.

## Examples

Bad:

    import 'package:some_package/some_package.dart';

Good:

    import 'package:some_package/some_package.dart' show SomeType;
    import 'package:some_package/some_package.dart' as some;
    import 'package:some_package/some_package.dart' as some show SomeType;

## Suppress a diagnostic

    // ignore: explicit_imports_alt/explicit_imports
    import 'package:some_package/some_package.dart';

## Development

For local testing, replace `version` with the path to your checkout:

    plugins:
      explicit_imports_alt:
        path: C:/path/to/explicit_imports_alt
        # exclude_packages:
        #   - dart:**
        #   - test
        #   - material_ui
        #   - cupertino_ui
        #   - flutter_test

## License

The original license and copyright notice are preserved in `LICENSE`.
