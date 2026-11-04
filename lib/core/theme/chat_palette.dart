import 'package:flutter/material.dart';

// Share a room's colors between its list card and its open conversation.
final _roomIndices = <String, int>{};
(Color, Color) chatRoomColors(String id) {
  const palette = [
    (Color(0xFFE8F3F8), Color(0xFF477F9C)),
    (Color(0xFFFCEEF4), Color(0xFFA34076)),
    (Color(0xFFF0EAF8), Color(0xFF7860A3)),
  ];
  final index =
      _roomIndices.putIfAbsent(id, () => _roomIndices.length) % palette.length;
  return palette[index];
}
