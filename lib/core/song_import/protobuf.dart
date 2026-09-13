import 'dart:convert';
import 'dart:typed_data';

/// One field of a protobuf message, undecoded.
class ProtoField {
  const ProtoField(this.number, this.wireType, {this.varint = 0, this.bytes});

  final int number;
  final int wireType;
  final int varint;

  /// For a length-delimited field: a string, raw bytes, or a nested message.
  final Uint8List? bytes;

  String get string => utf8.decode(bytes ?? const [], allowMalformed: true);

  /// The field read as a nested message, or null when it is not one.
  List<ProtoField>? get message => bytes == null ? null : readProto(bytes!);
}

/// Splits a protobuf message into its fields without a schema, or returns
/// null when the bytes are not a well-formed message.
///
/// ProPresenter 7 writes its documents as protobuf. The app needs a handful of
/// fields out of them - the song's words, its groups, its CCLI details - and a
/// generated decoder for the whole format would be thousands of lines to read
/// a dozen numbers. The numbers are in propresenter.dart.
List<ProtoField>? readProto(Uint8List data) {
  final fields = <ProtoField>[];
  var i = 0;

  int? varint() {
    var result = 0;
    var shift = 0;
    while (i < data.length) {
      final byte = data[i++];
      if (shift < 64) result |= (byte & 0x7F) << shift;
      if (byte & 0x80 == 0) return result;
      shift += 7;
      if (shift > 70) return null;
    }
    return null;
  }

  while (i < data.length) {
    final key = varint();
    if (key == null) return null;
    final number = key >> 3;
    final wire = key & 0x7;
    if (number <= 0) return null;
    switch (wire) {
      case 0:
        final value = varint();
        if (value == null) return null;
        fields.add(ProtoField(number, wire, varint: value));
      case 1:
        if (i + 8 > data.length) return null;
        fields.add(ProtoField(number, wire, bytes: Uint8List.sublistView(data, i, i + 8)));
        i += 8;
      case 2:
        final length = varint();
        if (length == null || length < 0 || i + length > data.length) return null;
        fields.add(ProtoField(number, wire, bytes: Uint8List.sublistView(data, i, i + length)));
        i += length;
      case 5:
        if (i + 4 > data.length) return null;
        fields.add(ProtoField(number, wire, bytes: Uint8List.sublistView(data, i, i + 4)));
        i += 4;
      default:
        return null;
    }
  }
  return fields;
}

extension ProtoFields on List<ProtoField> {
  Iterable<ProtoField> all(int number) => where((f) => f.number == number);

  ProtoField? field(int number) => all(number).firstOrNull;

  List<ProtoField>? message(int number) => field(number)?.message;

  String? string(int number) => field(number)?.string;

  int? varint(int number) => field(number)?.varint;
}
