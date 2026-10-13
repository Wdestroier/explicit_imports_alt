import 'package:analyzer/analysis_rule/analysis_rule.dart' show AnalysisRule;
import 'package:analyzer/analysis_rule/rule_context.dart' show RuleContext;
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart'
    show RuleVisitorRegistry;
import 'package:analyzer/dart/ast/ast.dart'
    show ImportDirective, ShowCombinator;
import 'package:analyzer/dart/ast/visitor.dart' show SimpleAstVisitor;
import 'package:analyzer/error/error.dart' show LintCode;
import 'package:yaml/yaml.dart' show YamlException, YamlList, YamlMap, loadYaml;

class ExplicitImportsAltRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'explicit_imports',
    'Imports must use either a "show" combinator or an "as" prefix.',
    correctionMessage:
        'Restrict the import with show, or add an import prefix (as ...).',
  );

  ExplicitImportsAltRule()
    : super(
        name: code.lowerCaseName,
        description: 'Flags imports without "show" or "as".',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final excludedPackages = _readConfiguredExclusions(context);
    registry.addImportDirective(
      this,
      _ExplicitImportVisitor(this, excludedPackages),
    );
  }
}

class _ExplicitImportVisitor extends SimpleAstVisitor<void> {
  final ExplicitImportsAltRule rule;
  final Set<String> excludedPackages;

  _ExplicitImportVisitor(this.rule, this.excludedPackages);

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue;
    if (uri == null || uri.isEmpty || !_isSupportedImport(uri)) return;
    if (_isExcluded(uri, excludedPackages)) return;

    final hasAsPrefix = node.prefix != null;
    final hasShow = node.combinators.any(
      (combinator) => combinator is ShowCombinator,
    );
    if (!hasAsPrefix && !hasShow) {
      rule.reportAtNode(node);
    }
  }
}

Set<String> _readConfiguredExclusions(RuleContext context) {
  final packageRoot = context.package?.root;
  if (packageRoot == null) return const {};

  var folder = packageRoot;
  while (true) {
    final optionsFile = folder.getChildAssumingFile('analysis_options.yaml');
    if (optionsFile.exists) {
      final configured = _readExclusionDirective(
        optionsFile.readAsStringSync(),
      );
      if (configured != null) return configured;
    }

    final parent = folder.parent;
    if (parent.path == folder.path) break;
    folder = parent;
  }
  return const {};
}

Set<String>? _readExclusionDirective(String source) {
  final lines = source.split(RegExp(r'\r?\n'));
  var pluginsIndent = -1;
  var pluginIndent = -1;
  var isTargetPlugin = false;

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final indentation = line.length - line.trimLeft().length;
    final content = line.trimLeft();
    if (content.isEmpty) continue;

    if (content.startsWith('#')) {
      if (isTargetPlugin && indentation > pluginIndent) {
        final configured = _parseCommentedExclusions(lines, index);
        if (configured != null) return configured;
      }
      continue;
    }

    final key = RegExp(r'^([A-Za-z0-9_-]+)[ \t]*:').firstMatch(content);
    if (pluginsIndent == -1) {
      if (key?.group(1) == 'plugins') pluginsIndent = indentation;
      continue;
    }

    if (indentation <= pluginsIndent) {
      pluginsIndent = key?.group(1) == 'plugins' ? indentation : -1;
      pluginIndent = -1;
      isTargetPlugin = false;
      continue;
    }

    if (key != null && (pluginIndent == -1 || indentation <= pluginIndent)) {
      pluginIndent = indentation;
      isTargetPlugin = key.group(1) == 'explicit_imports_alt';
    }
  }

  return null;
}

Set<String>? _parseCommentedExclusions(List<String> lines, int index) {
  final marker = RegExp(
    r'^#[ \t]*exclude_packages[ \t]*:(.*)$',
  ).firstMatch(lines[index].trimLeft());
  if (marker == null) return null;

  final yamlLines = ['exclude_packages:${marker.group(1) ?? ''}'];
  for (var next = index + 1; next < lines.length; next++) {
    final content = lines[next].trimLeft();
    if (!content.startsWith('#')) break;

    var uncommented = content.substring(1);
    if (uncommented.startsWith(' ')) uncommented = uncommented.substring(1);
    if (uncommented.trim().isEmpty ||
        !(uncommented.startsWith(' ') || uncommented.startsWith('\t'))) {
      break;
    }
    yamlLines.add(uncommented);
  }

  try {
    final config = loadYaml(yamlLines.join('\n'));
    if (config is! YamlMap) return const {};

    final configured = config['exclude_packages'];
    if (configured is String) {
      return {
        for (final value in configured.split(';'))
          if (value.trim().isNotEmpty) value.trim(),
      };
    }
    if (configured is YamlList) {
      return {
        for (final value in configured)
          if (value is String && value.trim().isNotEmpty) value.trim(),
      };
    }
    return const {};
  } on YamlException {
    return const {};
  }
}

bool _isSupportedImport(String uri) {
  return uri.startsWith('package:') ||
      uri.startsWith('dart:') ||
      !uri.contains(':');
}

bool _isExcluded(String uri, Set<String> selectors) {
  final package = _packageName(uri);
  for (final selector in selectors) {
    if (selector.isEmpty) continue;

    // Package-name selectors apply to every library in that package.
    if (!selector.contains(':') && !selector.contains('/')) {
      if (package != null && _matchesGlob(package, selector)) return true;
      continue;
    }

    // URI selectors can target a single library or use * and ** globs.
    if (_matchesGlob(uri, selector)) return true;
  }
  return false;
}

String? _packageName(String uri) {
  if (!uri.startsWith('package:')) return null;
  final rest = uri.substring('package:'.length);
  final slash = rest.indexOf('/');
  return slash == -1 ? rest : rest.substring(0, slash);
}

bool _matchesGlob(String value, String pattern) {
  final expression = RegExp.escape(
    pattern,
  ).replaceAll(r'\*\*', '.*').replaceAll(r'\*', '[^/]*');
  return RegExp('^$expression\$').hasMatch(value);
}
