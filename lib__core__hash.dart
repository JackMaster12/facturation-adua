import 'dart:convert';

/// Empreinte courte (FNV-1a 32 bits) affichée dans le QR pour repérer une modification.
String empreinte(String s) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(s)) {
    h ^= b;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16).toUpperCase().padLeft(8, '0');
}
