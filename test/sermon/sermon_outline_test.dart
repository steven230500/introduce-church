import 'package:flutter_test/flutter_test.dart';
import 'package:introduce_church/core/sermon/sermon_outline.dart';

void main() {
  List<String> passages(SermonOutline outline) => [for (final p in outline.passages) '$p'];

  test('an outline as it comes from WhatsApp', () {
    final outline = readSermonOutline('''
*LA FE QUE VENCE*
Texto: Hebreos 11:1-6

1️⃣ La fe es certeza (He 11:1)
2️⃣ La fe agrada a Dios
Hebreos 11:6
3️⃣ _La fe actúa_ – Santiago 2:17
''');

    expect(outline.title, 'LA FE QUE VENCE');
    expect(outline.points, [
      'La fe es certeza (He 11:1)',
      'La fe agrada a Dios',
      'La fe actúa – Santiago 2:17',
    ]);
    expect(passages(outline), ['Hebreos 11:1-6', 'Hebreos 11:1', 'Hebreos 11:6', 'Santiago 2:17']);
  });

  test('numbers, letters, Roman numerals and bullets are not part of a point', () {
    final outline = readSermonOutline('''
Título
1. Uno
2) Dos
III. Tres
b) Cuatro
- Cinco
• Seis
Punto 7: Siete
''');

    expect(outline.points, ['Uno', 'Dos', 'Tres', 'Cuatro', 'Cinco', 'Seis', 'Siete']);
  });

  test('the line that says it is the title is the title, wherever it is', () {
    final outline = readSermonOutline('''
Domingo 21 de septiembre
Tema: El buen pastor
Salmo 23
- Me guía
''');

    expect(outline.title, 'El buen pastor');
    expect(outline.points, ['Domingo 21 de septiembre', 'Me guía']);
    expect(passages(outline), ['Salmos 23']);
  });

  test('a heading on its own line is not a point', () {
    final outline = readSermonOutline('''
El amor de Dios
Puntos:
Introducción:
Nos amó primero
Conclusión: Dios es fiel
''');

    expect(outline.points, ['Nos amó primero', 'Conclusión: Dios es fiel']);
  });

  test('a passage named twice is added once', () {
    final outline = readSermonOutline('''
Gracia
Efesios 2:8
Por gracia sois salvos (Efesios 2:8)
''');

    expect(passages(outline), ['Efesios 2:8']);
    expect(outline.points, ['Por gracia sois salvos (Efesios 2:8)']);
  });

  test('what WhatsApp adds to messages copied together', () {
    final outline = readSermonOutline('''
[21/9 9:40 p. m.] Pastor Andrés: Vidas transformadas
[21/9 9:41 p. m.] Pastor Andrés: 1. Una mente nueva, Romanos 12:2
''');

    expect(outline.title, 'Vidas transformadas');
    expect(outline.points, ['Una mente nueva, Romanos 12:2']);
    expect(passages(outline), ['Romanos 12:2']);
  });

  test('an English outline', () {
    final outline = readSermonOutline('''
Title: Faith that overcomes
Reading: Hebrews 11:1-6
1. Faith is being sure (Heb 11:1)
''');

    expect(outline.title, 'Faith that overcomes');
    expect(outline.points, ['Faith is being sure (Heb 11:1)']);
    expect(passages(outline), ['Hebreos 11:1-6', 'Hebreos 11:1']);
  });

  test('nothing to read', () {
    expect(readSermonOutline('  \n\n ').isEmpty, isTrue);
  });
}
