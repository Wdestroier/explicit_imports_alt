# explicit_imports_alt

A Dart analyzer plugin that flags imports unless they use a `show`
combinator or an `as` prefix.

## Install

Add the plugin to the top-level `plugins` section of your
`analysis_options.yaml`:

    plugins:
      explicit_imports_alt:
        version: ^1.1.0

The Dart analysis server should restart automatically after changing the `plugins`
section. You do not need to add this plugin to your application's
`pubspec.yaml`.

## Default behavior and optional exclusions

Every supported import is checked by default. Nothing is excluded unless you configure it. A `hide` combinator alone does not make an import explicit.

## Configure exclusions

Add the commented directive under the plugin entry in your root `analysis_options.yaml`:

    plugins:
      explicit_imports_alt:
        version: ^1.1.0
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

## Compatibility with other plugins

Analyzer plugins in the same analysis server share a dependency resolution.
Version 1.1.0 supports analyzer `^14.5.0` and analysis_server_plugin `^0.3.24`,
matching `auto_build_runner` 1.0.0. Enable both with:

    plugins:
      explicit_imports_alt:
        version: ^1.1.0
      auto_build_runner:
        version: ^1.0.0

Older explicit_imports_alt releases cap analyzer at 13.0.0 and cannot resolve
alongside auto_build_runner 1.0.0. Update the plugin version in
`analysis_options.yaml` and restart the analysis server after upgrading.

## Development

Run `dart test` for rule tests and
`dart run tool/check_plugin_compatibility.dart` to resolve and analyze a temporary
project with both plugins enabled. The latter downloads auto_build_runner 1.0.0
from pub.dev and does not start a build_runner watcher.

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
