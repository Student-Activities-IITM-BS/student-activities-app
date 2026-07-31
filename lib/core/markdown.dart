String normalizeMarkdownLinks(String source) {
  final urlPattern = RegExp(r'https?://[^\s<>()\[\]]+');
  final output = StringBuffer();
  var cursor = 0;

  for (final match in urlPattern.allMatches(source)) {
    final start = match.start;
    final url = match.group(0)!;
    final isMarkdownDestination =
        start >= 2 && source.substring(start - 2, start) == '](';
    final isAutoLink = start > 0 && source[start - 1] == '<';
    if (isMarkdownDestination || isAutoLink) continue;

    var link = url;
    var suffix = '';
    while (link.isNotEmpty && RegExp(r'[.,!?;:]$').hasMatch(link)) {
      suffix = '${link.substring(link.length - 1)}$suffix';
      link = link.substring(0, link.length - 1);
    }
    if (link.isEmpty) continue;

    output
      ..write(source.substring(cursor, start))
      ..write('[$link]($link)$suffix');
    cursor = match.end;
  }

  if (cursor == 0) return source;
  output.write(source.substring(cursor));
  return output.toString();
}
