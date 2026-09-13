/// The words in an RTF document, without its formatting.
///
/// ProPresenter keeps every slide's text as RTF. This reads the subset those
/// files use: paragraphs and line breaks, escaped characters in both the
/// Windows code page and Unicode, and the header groups - fonts, colours,
/// styles - that carry no words and are skipped.
String rtfToText(String rtf) {
  final out = StringBuffer();
  // One entry per open group: whether its text is skipped, and how many
  // characters stand in for each \u escape.
  final skip = <bool>[false];
  final uc = <int>[1];
  var pendingSkip = 0;
  var i = 0;

  void emit(String text) {
    if (skip.last) return;
    out.write(text);
  }

  while (i < rtf.length) {
    final ch = rtf[i];
    if (ch == '{') {
      skip.add(skip.last);
      uc.add(uc.last);
      i++;
      continue;
    }
    if (ch == '}') {
      if (skip.length > 1) {
        skip.removeLast();
        uc.removeLast();
      }
      i++;
      continue;
    }
    if (ch == '\r' || ch == '\n') {
      // A raw line break in RTF source is not a line break in the text.
      i++;
      continue;
    }
    if (ch != '\\') {
      if (pendingSkip > 0) {
        pendingSkip--;
      } else {
        emit(ch);
      }
      i++;
      continue;
    }

    // A backslash: an escaped symbol or a control word.
    if (i + 1 >= rtf.length) break;
    final next = rtf[i + 1];
    if (next == '\\' || next == '{' || next == '}') {
      emit(next);
      i += 2;
      continue;
    }
    if (next == "'") {
      final hex = i + 4 <= rtf.length ? rtf.substring(i + 2, i + 4) : '';
      final code = int.tryParse(hex, radix: 16);
      if (pendingSkip > 0) {
        pendingSkip--;
      } else if (code != null) {
        emit(_cp1252(code));
      }
      i += 4;
      continue;
    }
    if (next == '*') {
      skip[skip.length - 1] = true;
      i += 2;
      continue;
    }
    if (next == '\n' || next == '\r') {
      emit('\n');
      i += 2;
      continue;
    }
    if (next == '~') {
      emit(' ');
      i += 2;
      continue;
    }
    if (next == '-' || next == '_') {
      if (next == '_') emit('-');
      i += 2;
      continue;
    }

    final word = _controlWord.matchAsPrefix(rtf, i + 1);
    if (word == null) {
      i += 2;
      continue;
    }
    final name = word.group(1)!;
    final param = word.group(2) == null ? null : int.tryParse(word.group(2)!);
    i = word.end;
    if (i < rtf.length && rtf[i] == ' ') i++;

    switch (name) {
      case 'par' || 'line' || 'sect' || 'page':
        emit('\n');
      case 'tab':
        emit('\t');
      case 'u':
        if (param != null) {
          emit(String.fromCharCode(param < 0 ? param + 65536 : param));
          pendingSkip = uc.last;
        }
      case 'uc':
        if (param != null) uc[uc.length - 1] = param;
      case 'emdash':
        emit('—');
      case 'endash':
        emit('–');
      case 'lquote':
        emit('‘');
      case 'rquote':
        emit('’');
      case 'ldblquote':
        emit('“');
      case 'rdblquote':
        emit('”');
      case 'bullet':
        emit('•');
      case _ when _destinations.contains(name):
        skip[skip.length - 1] = true;
    }
  }
  return out.toString();
}

final _controlWord = RegExp(r'([a-zA-Z]+)(-?\d+)?');

/// Groups whose contents are settings, not words.
const _destinations = {
  'fonttbl',
  'colortbl',
  'stylesheet',
  'info',
  'pict',
  'header',
  'footer',
  'headerl',
  'headerr',
  'footerl',
  'footerr',
  'listtable',
  'listoverridetable',
  'rsidtbl',
  'generator',
  'xmlnstbl',
  'themedata',
  'colorschememapping',
  'latentstyles',
  'datastore',
  'fldinst',
  'object',
  'expandedcolortbl',
  'mmathPr',
  'pgdsctbl',
  'revtbl',
  'filetbl',
  'nonshppict',
  'bkmkstart',
};

/// Windows-1252, which is what the \'hh escapes in these files are in. Only
/// 0x80-0x9F differ from Latin-1.
String _cp1252(int code) {
  const high = [
    0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
    0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F,
    0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
    0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178,
  ];
  if (code >= 0x80 && code <= 0x9F) return String.fromCharCode(high[code - 0x80]);
  return String.fromCharCode(code);
}
