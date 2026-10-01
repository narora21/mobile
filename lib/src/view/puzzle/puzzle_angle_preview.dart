import 'package:dartchess/dartchess.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_providers.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_service.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_theme.dart';
import 'package:lichess_mobile/src/network/connectivity.dart';
import 'package:lichess_mobile/src/styles/puzzle_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/widgets/board_preview.dart';
import 'package:lichess_mobile/src/widgets/shimmer.dart';
import 'package:material_ui/material_ui.dart';

/// A widget that displays a preview of a puzzle angle batch.
class const PuzzleAnglePreview({
  required final PuzzleAngle angle,
  final VoidCallback? onTap,
  super.key,
}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puzzle = ref.watch(nextPuzzlePreviewProvider(angle));
    final flatOpenings = ref.watch(flatOpeningsListProvider);
    final isOnline = ref.watch(isDeviceOnlineProvider);
    // Only useful offline: online the queue is refilled as puzzles are solved, so the number of
    // puzzles left says nothing about what the user can still do.
    final savedCount = ref.watch(savedBatchNbUnsolvedProvider(angle)).value ?? 0;

    Widget buildPuzzlePreview(Puzzle? puzzle, {bool loading = false}) {
      final preview = puzzle != null ? PuzzlePreview.fromPuzzle(puzzle) : null;

      return loading
          ? const Shimmer(
              child: ShimmerLoading(isLoading: true, child: SmallBoardPreview.loading()),
            )
          : Slidable(
              dragStartBehavior: DragStartBehavior.start,
              enabled: angle != const PuzzleTheme(PuzzleThemeKey.mix),
              endActionPane: ActionPane(
                motion: const StretchMotion(),
                children: [
                  SlidableAction(
                    icon: Icons.delete,
                    onPressed: (context) async {
                      final service = await ref.read(puzzleServiceProvider.future);
                      if (context.mounted) {
                        await service.deleteBatch(
                          userId: ref.read(authControllerProvider)?.user.id,
                          angle: angle,
                        );
                        ref.invalidate(savedBatchesProvider);
                      }
                    },
                    spacing: 8.0,
                    backgroundColor: context.lichessColors.error,
                    foregroundColor: Colors.white,
                    label: context.l10n.delete,
                  ),
                ],
              ),
              child: SmallBoardPreview(
                orientation: preview?.orientation ?? Side.white,
                fen: preview?.initialFen ?? kEmptyFEN,
                lastMove: preview?.initialMove,
                description: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: switch (angle) {
                        PuzzleTheme(themeKey: final themeKey) => [
                          Text(
                            themeKey.l10n(context.l10n).name,
                            style: Styles.boardPreviewTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            themeKey.l10n(context.l10n).description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              height: 1.2,
                              fontSize: 12.0,
                              color: DefaultTextStyle.of(context).style.color
                                  ?.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                        PuzzleOpening(key: final openingKey) => [
                          Text(
                            flatOpenings.value
                                    ?.firstWhere(
                                      (o) => o.key == openingKey,
                                      orElse: () => (
                                        key: openingKey,
                                        name: openingKey.replaceAll('_', ''),
                                        count: 0,
                                      ),
                                    )
                                    .name ??
                                openingKey.replaceAll('_', ' '),
                            style: Styles.boardPreviewTitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      },
                    ),
                    Row(
                      children: [
                        Icon(
                          switch (angle) {
                            PuzzleTheme(themeKey: final themeKey) => themeKey.icon,
                            PuzzleOpening() => PuzzleIcons.opening,
                          },
                          size: 34,
                          color: DefaultTextStyle.of(context).style.color?.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        if (puzzle != null)
                          Flexible(
                            child: Column(
                              mainAxisSize: .min,
                              crossAxisAlignment: .start,
                              children: [
                                Text(
                                  puzzle.puzzle.sideToMove == Side.white
                                      ? context.l10n.whitePlays
                                      : context.l10n.blackPlays,
                                  style: TextStyle(color: textShade(context, 0.9)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (!isOnline && savedCount > 0)
                                  Text(
                                    '$savedCount',
                                    style: TextStyle(
                                      fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
                                      color: textShade(context, Styles.subtitleOpacity),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          )
                        else
                          Flexible(
                            child: Text(
                              isOnline
                                  // The queue is only refilled when a puzzle is opened, so an empty
                                  // one online is not a dead end.
                                  ? 'Tap to fetch new puzzles.'
                                  : 'No puzzles available, please go online to fetch them.',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Tappable even with an empty queue: the puzzle screen is what fetches new puzzles.
                onTap: onTap,
              ),
            );
    }

    return switch (puzzle) {
      AsyncData(:final value) => buildPuzzlePreview(value),
      // A storage failure leaves nothing to preview, but the angle can still be opened.
      AsyncError() => buildPuzzlePreview(null),
      _ => buildPuzzlePreview(null, loading: true),
    };
  }
}
