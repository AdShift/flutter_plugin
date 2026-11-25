import 'dart:io';

/// The names in the `show` lists of the library at [path], sorted.
List<String> exportedNames(String path) => [
  for (final export in RegExp(
    r"export '[^']+'\s+show\s+([^;]+);",
  ).allMatches(File(path).readAsStringSync()))
    ...export[1]!.split(',').map((name) => name.trim()),
]..sort();

/// The signatures of the public members of [className] declared at [path], in
/// source order: each on one line, without doc comment, annotations and body.
///
/// Reads plain declarations only: no operators, no function-typed members.
List<String> memberSignatures(String path, String className) {
  final source = File(path).readAsStringSync().replaceAll(RegExp('//.*'), '');
  final bodyStart = source.indexOf('{', source.indexOf('class $className '));
  final signatures = <String>[];
  final signature = StringBuffer();
  var depth = 0;
  // Null in a signature; otherwise the character that ends the body.
  String? bodyEnd;

  void endMember() {
    final text = signature
        .toString()
        .replaceAll(RegExp(r'@\w+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r',\s*(?=[)}])'), '')
        .replaceAll(RegExp(r'(?<=[({]) | (?=[)}])'), '')
        .trim()
        .replaceFirst(RegExp(r' async$'), '');
    if (text.isNotEmpty && !memberName(text).startsWith('_')) {
      signatures.add(text);
    }
    signature.clear();
    bodyEnd = null;
  }

  for (var i = bodyStart + 1; i < source.length; i++) {
    final char = source[i];
    if (char == "'") {
      // A string literal; none in these classes holds a quote.
      i = source.indexOf("'", i + 1);
      continue;
    }
    if (bodyEnd == null && depth == 0) {
      if (char == '}') break;
      if (char == ';') {
        endMember();
        continue;
      }
      if (char == '=') bodyEnd = ';';
      if (char == '{') bodyEnd = '}';
    }
    if (bodyEnd == null) signature.write(char);
    if ('([{'.contains(char)) depth++;
    if (')]}'.contains(char)) depth--;
    if (depth == 0 && char == bodyEnd) endMember();
  }
  return signatures;
}

/// The name a signature from [memberSignatures] declares.
String memberName(String signature) =>
    signature.split('(').first.trim().split(' ').last;
