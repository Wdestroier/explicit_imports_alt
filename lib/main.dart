import 'package:analysis_server_plugin/plugin.dart' show Plugin;
import 'package:analysis_server_plugin/registry.dart' show PluginRegistry;

import 'src/explicit_imports_alt.dart' show ExplicitImportsAltRule;

final plugin = ExplicitImportsAltPlugin();

class ExplicitImportsAltPlugin extends Plugin {
  @override
  String get name => 'Explicit imports alt plugin';

  @override
  void register(PluginRegistry registry) {
    // Warning rules are enabled by default, so users do not need a diagnostics
    // section in analysis_options.yaml.
    registry.registerWarningRule(ExplicitImportsAltRule());
  }
}
