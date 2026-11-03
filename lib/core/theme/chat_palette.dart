import 'package:flutter/material.dart';

// Share a room's colors between its list card and its open conversation.
final _roomIndices = <String, int>{};
(Color, Color) chatRoomColors(String id) {
  const tones = [
    Color(0xFFE4F1FC),
    Color(0xFFFCE5D6),
    Color(0xFFE0EAFC),
    Color(0xFFFFF0DB),
    Color(0xFFF0DFF7),
    Color(0xFFFFDFE5),
    Color(0xFFD7EFF3),
    Color(0xFFECEBCF),
  ];
  const accents = [
    Color(0xFF568BB7),
    Color(0xFFC17B45),
    Color(0xFF527ABD),
    Color(0xFFB59336),
    Color(0xFF8D63AE),
    Color(0xFFBD6C74),
    Color(0xFF4295A4),
    Color(0xFF8D9550),
  ];
  final index =
      _roomIndices.putIfAbsent(id, () => _roomIndices.length) % tones.length;
  return (tones[index], accents[index]);
}
