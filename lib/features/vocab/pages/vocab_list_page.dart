import 'package:flutter/material.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/card_surface.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/speak_button.dart';
import '../../tts/services/tts_service.dart';
import '../models/word.dart';

class VocabListPage extends StatefulWidget {
  const VocabListPage({
    super.key,
    required this.words,
    required this.mastered,
    this.tts,
    this.grid,
  });

  final List<Word> words;
  final Set<String> mastered;
  final TtsService? tts;

  /// null → adaptif (grid di layout lebar, daftar di compact).
  final bool? grid;

  @override
  State<VocabListPage> createState() => _VocabListPageState();
}

class _VocabListPageState extends State<VocabListPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Word> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.words;
    return widget.words
        .where(
          (w) =>
              w.word.toLowerCase().contains(q) ||
              w.read.toLowerCase().contains(q) ||
              w.meaning.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final isGrid = widget.grid ?? AdaptiveLayout.isWide(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: SearchField(
            controller: _controller,
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada hasil.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : isGrid
              ? GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: 148,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _WordCard(
                    word: items[i],
                    hafal: widget.mastered.contains(items[i].masteryKey),
                    tts: widget.tts,
                  ),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: AppColors.border, height: 1),
                  itemBuilder: (_, i) => _WordRow(
                    word: items[i],
                    hafal: widget.mastered.contains(items[i].masteryKey),
                    tts: widget.tts,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Kartu kata untuk layout lebar.
class _WordCard extends StatelessWidget {
  const _WordCard({required this.word, required this.hafal, this.tts});

  final Word word;
  final bool hafal;
  final TtsService? tts;

  @override
  Widget build(BuildContext context) {
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (word.word.isNotEmpty)
                Text(
                  word.word,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              if (word.read.isNotEmpty)
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        word.read,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.accentSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (tts != null) ...[
                      const SizedBox(width: 6),
                      SpeakButton(text: word.read, tts: tts!),
                    ],
                  ],
                ),
              if (word.read.isNotEmpty && word.readRomaji.isNotEmpty)
                Text(
                  word.readRomaji,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textHint,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        if (hafal)
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppColors.hafal,
          ),
      ],
    );
    return CardSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const Spacer(),
          if (word.meaning.isNotEmpty)
            Text(
              word.meaning,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
        ],
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.word, required this.hafal, this.tts});

  final Word word;
  final bool hafal;
  final TtsService? tts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kolom Kiri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (word.word.isNotEmpty) ...[
                  Text(
                    word.word,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                if (word.read.isNotEmpty)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          word.read,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.accentSoft,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      if (tts != null) ...[
                        const SizedBox(width: 6),
                        SpeakButton(text: word.read, tts: tts!),
                      ],
                    ],
                  ),
                if (word.read.isNotEmpty && word.readRomaji.isNotEmpty)
                  Text(
                    word.readRomaji,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textHint,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Kolom Kanan (Bungkus dengan Expanded)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (word.meaning.isNotEmpty)
                  Text(
                    word.meaning,
                    maxLines: 4,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.text,
                      height: 1.35,
                    ),
                  ),
                if (hafal) ...[
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: AppColors.hafal,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Hafal',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.hafal,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
