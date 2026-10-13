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
  final Map<String, _CachedExclusions> _configurationCache = {};

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
    registry.addImportDirective(
      this,
      _ExplicitImportVisitor(this, context, _configurationCache),
    );
  }
}

class _ExplicitImportVisitor extends SimpleAstVisitor<void> {
  final ExplicitImportsAltRule rule;
  final RuleContext context;
  final Map<String, _CachedExclusions> _configurationCache;
  late final _ImportExclusions exclusions = _readConfiguredExclusions(
    context,
    _configurationCache,
  );

  _ExplicitImportVisitor(this.rule, this.context, this._configurationCache);

  @override
  void visitImportDirective(ImportDirective node) {
    if (node.prefix != null) return;
    for (var combinator in node.combinators) {
      if (combinator is ShowCombinator) return;
    }

    final uri = node.uri.stringValue;
    if (uri == null || uri.isEmpty || !_isSupportedImport(uri)) return;

    if (exclusions.matches(uri)) return;
    rule.reportAtNode(node);
  }
}

class _ImportExclusions {
  final Set<String> _packageNames;
  final List<RegExp> _packagePatterns;
  final Set<String> _uris;
  final List<RegExp> _uriPatterns;
  final bool _hasExclusions;

  const _ImportExclusions.empty()
    : _packageNames = const {},
      _packagePatterns = const [],
      _uris = const {},
      _uriPatterns = const [],
      _hasExclusions = false;

  _ImportExclusions(Set<String> selectors)
    : _packageNames = {},
      _packagePatterns = [],
      _uris = {},
      _uriPatterns = [],
      _hasExclusions = selectors.isNotEmpty {
    for (var selector in selectors) {
      if (selector.isEmpty) continue;

      final isPackageName = !selector.contains(':') && !selector.contains('/');
      if (isPackageName) {
        if (selector.contains('*')) {
          _packagePatterns.add(_globRegExp(selector));
        } else {
          _packageNames.add(selector);
        }
      } else if (selector.contains('*')) {
        _uriPatterns.add(_globRegExp(selector));
      } else {
        _uris.add(selector);
      }
    }
  }

  bool matches(String uri) {
    if (!_hasExclusions) return false;
    if (_uris.contains(uri)) return true;

    if (_packageNames.isNotEmpty || _packagePatterns.isNotEmpty) {
      final package = _packageName(uri);
      if (package != null) {
        if (_packageNames.contains(package)) return true;
        for (var pattern in _packagePatterns) {
          if (pattern.hasMatch(package)) return true;
        }
      }
    }

    for (var pattern in _uriPatterns) {
      if (pattern.hasMatch(uri)) return true;
    }
    return false;
  }
}

class _CachedExclusions {
  final String source;
  final _ImportExclusions? exclusions;

  _CachedExclusions(this.source, this.exclusions);
}

_ImportExclusions _readConfiguredExclusions(
  RuleContext context,
  Map<String, _CachedExclusions> cache,
) {
  final packageRoot = context.package?.root;
  if (packageRoot == null) return const _ImportExclusions.empty();

  var folder = packageRoot;
  while (true) {
    final optionsFile = folder.getChildAssumingFile('analysis_options.yaml');
    if (optionsFile.exists) {
      // Compare current contents so comment edits invalidate the cached matchers.
      final source = optionsFile.readAsStringSync();
      var cached = cache[optionsFile.path];
      if (cached == null || cached.source != source) {
        final selectors = _readExclusionDirective(source);
        final configured = selectors == null
            ? null
            : selectors.isEmpty
            ? const _ImportExclusions.empty()
            : _ImportExclusions(selectors);
        cached = _CachedExclusions(source, configured);
        cache[optionsFile.path] = cached;
      }
      final configured = cached.exclusions;
      if (configured != null) return configured;
    }

    final parent = folder.parent;
    if (parent.path == folder.path) break;
    folder = parent;
  }
  return const _ImportExclusions.empty();
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
        for (var value in configured.split(';'))
          if (value.trim().isNotEmpty) value.trim(),
      };
    }
    if (configured is YamlList) {
      return {
        for (var value in configured)
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

String? _packageName(String uri) {
  if (!uri.startsWith('package:')) return null;
  final start = 'package:'.length;
  final slash = uri.indexOf('/', start);
  return uri.substring(start, slash == -1 ? uri.length : slash);
}

RegExp _globRegExp(String pattern) {
  final expression = RegExp.escape(
    pattern,
  ).replaceAll(r'\*\*', '.*').replaceAll(r'\*', '[^/]*');
  return RegExp('^$expression\$');
}
