import 'package:flutter/material.dart';

import '../theme/zest_colors.dart';

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(color: context.colors.text),
        decoration: InputDecoration(
          hintText: 'Cari kata, arti, atau bacaan...',
          hintStyle: TextStyle(color: context.colors.textHint),
          prefixIcon: Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(
              Icons.search_rounded,
              color: context.colors.textMuted,
              size: 20,
            ),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }
}
