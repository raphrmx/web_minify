import 'dart:convert';
import 'dart:io';

import 'package:web_minify/web_minify.dart';

const String _usage = '''
Minifies HTML, CSS and JavaScript.

Usage:
  dart run web_minify <file> [file...] [options]
  dart run web_minify --type html < input > output

Each input is minified as a whole: an HTML page carries its inline <style> and
<script> blocks through the stylesheet and script minifiers.

Options:
  -o, --out <dir>   Write each result next to its source under <dir>, keeping
                    the file name. Without it, results go to stdout.
  -i, --in-place    Overwrite each input file with its minified content.
  -t, --type <t>    Force the language (html, css or js) instead of deriving it
                    from the file extension or the content.
  -q, --quiet       Do not print the per-file size report to stderr.
  -h, --help        Show this message.
''';

/// Command line front end for the `web_minify` package.
///
/// Reads every input, minifies it according to its type and reports how many
/// bytes each file lost.
///
/// ---
///
/// ### Parameters:
/// - [arguments]: the raw command line arguments.
///
/// ### Example:
/// ```bash
/// dart run web_minify assets/html/page.html --out build/assets/html
/// ```
Future<void> main(List<String> arguments) async {
  final files = <String>[];
  String? outDir;
  String? type;
  var inPlace = false;
  var quiet = false;

  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    switch (argument) {
      case '-h':
      case '--help':
        stdout.write(_usage);
        return;
      case '-i':
      case '--in-place':
        inPlace = true;
      case '-q':
      case '--quiet':
        quiet = true;
      case '-o':
      case '--out':
        outDir = i + 1 < arguments.length ? arguments[++i] : null;
      case '-t':
      case '--type':
        type = i + 1 < arguments.length ? arguments[++i].toLowerCase() : null;
      default:
        if (argument.startsWith('-')) {
          stderr.writeln('Unknown option: $argument');
          exitCode = 64;
          return;
        }
        files.add(argument);
    }
  }

  MinifyLanguage? forced;
  if (type != null) {
    forced = MinifyLanguage.values.cast<MinifyLanguage?>().firstWhere((l) => l?.name == type, orElse: () => null);
    if (forced == null) {
      stderr.writeln('Unknown type: $type. Use html, css or js.');
      exitCode = 64;
      return;
    }
  }

  if (files.isEmpty) {
    final source = await utf8.decodeStream(stdin);
    stdout.write(minify(source, language: forced));
    return;
  }

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('No such file: $path');
      exitCode = 66;
      continue;
    }

    final source = file.readAsStringSync();
    final minified = minify(source, path: path, language: forced);

    if (inPlace) {
      file.writeAsStringSync(minified);
    } else if (outDir != null) {
      final target = File('$outDir/${file.uri.pathSegments.last}');
      target.parent.createSync(recursive: true);
      target.writeAsStringSync(minified);
    } else {
      stdout.write(minified);
    }

    if (!quiet) {
      final before = source.length;
      final after = minified.length;
      final saved = before == 0 ? 0 : ((before - after) * 100 / before).round();
      stderr.writeln('$path: $before -> $after bytes ($saved%)');
    }
  }
}
