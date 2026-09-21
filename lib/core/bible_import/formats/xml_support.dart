import 'package:xml/xml_events.dart';

/// "osis:verse" and "VERS" as "verse" and "vers": files differ in prefix and
/// case, never in meaning.
String localName(String name) {
  final colon = name.indexOf(':');
  return (colon < 0 ? name : name.substring(colon + 1)).toLowerCase();
}

/// The first of [names] the element has, ignoring case and prefix.
String? attributeOf(List<XmlEventAttribute> attributes, List<String> names) {
  for (final name in names) {
    for (final attribute in attributes) {
      if (localName(attribute.name) == name) return attribute.value;
    }
  }
  return null;
}

/// Elements whose text is not the Bible's: footnotes, cross references and
/// the headings editors add.
const notBibleText = {'note', 'caption', 'title', 'xref', 'rf', 'rdg'};

/// Elements that break a line. Without a space the words either side join.
const lineBreaks = {'br', 'lb', 'l', 'lg', 'p', 'div'};

/// The name of the root element and of the first element inside it.
({String? root, String? firstChild}) xmlShape(String xml) {
  String? root;
  for (final event in parseEvents(xml)) {
    if (event is! XmlStartElementEvent) continue;
    if (root != null) return (root: root, firstChild: localName(event.name));
    root = localName(event.name);
    if (event.isSelfClosing) break;
  }
  return (root: root, firstChild: null);
}
