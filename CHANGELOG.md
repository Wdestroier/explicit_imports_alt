# Changelog

## 1.1.0

- Support analyzer 14.5 and newer 14.x versions, allowing this plugin to run
  alongside `auto_build_runner` 1.0.0 in the same analysis server.
- Remove the unused direct `analyzer_plugin` dependency and its incompatible
  upper bound.
- Update analyzer testing utilities to cover the supported analyzer APIs.

## 1.0.1

- Improved documentation.

## 1.0.0

- Added import exclusions through a commented YAML list in
  `analysis_options.yaml`.
- Documented common exclusions, including `material_ui` and `cupertino_ui`.
- Checks every package, Dart SDK, and relative import by default.
- Forked the explicit import analyzer plugin.
