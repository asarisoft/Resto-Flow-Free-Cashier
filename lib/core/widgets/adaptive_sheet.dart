import 'package:flutter/material.dart';

/// Lebar minimum (dp) untuk dialog; di bawahnya = bottom sheet.
const sheetBreakpoint = 600.0;

/// Buka [builder] sebagai bottom sheet di HP (< 600 dp: geser-tutup, maks 90%
/// tinggi, sudut atas membulat, SafeArea) atau dialog di layar lebar.
/// [builder] menerima `asSheet` agar isi bisa menyesuaikan.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext context, bool asSheet) builder,
}) {
  final size = MediaQuery.sizeOf(context);
  if (size.width >= sheetBreakpoint) {
    return showDialog<T>(context: context, builder: (c) => builder(c, false));
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: BoxConstraints(maxHeight: size.height * 0.9),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (c) => builder(c, true),
  );
}
