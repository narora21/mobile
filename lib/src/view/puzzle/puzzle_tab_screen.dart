import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_providers.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_theme.dart';
import 'package:lichess_mobile/src/model/puzzle/streak_storage.dart';
import 'package:lichess_mobile/src/network/connectivity.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/styles/puzzle_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/tab_navigation.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/screen.dart';
import 'package:lichess_mobile/src/view/account/account_menu.dart';
import 'package:lichess_mobile/src/view/puzzle/daily_puzzle.dart';
import 'package:lichess_mobile/src/view/puzzle/dashboard_screen.dart';
import 'package:lichess_mobile/src/view/puzzle/puzzle_angle_preview.dart';
import 'package:lichess_mobile/src/view/puzzle/puzzle_history_screen.dart';
import 'package:lichess_mobile/src/view/puzzle/puzzle_screen.dart';
import 'package:lichess_mobile/src/view/puzzle/puzzle_themes_screen.dart';
import 'package:lichess_mobile/src/view/puzzle/storm_screen.dart';
import 'package:lichess_mobile/src/view/puzzle/streak_screen.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/shimmer.dart';
import 'package:material_ui/material_ui.dart';

const _kNumberOfHistoryItemsOnHandset = 8;
const _kNumberOfHistoryItemsOnTablet = 16;

class const PuzzleTabScreen({super.key}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The saved batches are only used to show the extra angle previews at the bottom of the list,
    // so a storage failure must not prevent the rest of the tab from being displayed. The listener
    // only fires on state changes, so the user is warned once per failed load.
    ref.listen(savedBatchesProvider, (_, next) {
      if (next case AsyncError(:final error, :final stackTrace)) {
        debugPrint('SEVERE: [PuzzleTabScreen] could not load saved batches; $error\n$stackTrace');
        showSnackBar(context, 'Could not load the puzzles.', type: SnackBarType.error);
      }
    });

    switch (ref.watch(savedBatchesProvider)) {
      case AsyncData(:final value):
        return _MaterialTabBody(value);
      case AsyncError():
        return const _MaterialTabBody(IList.empty());
      case _:
        return const _PuzzleTabScaffold(body: CenterLoadingIndicator());
    }
  }
}

/// Scaffold of the puzzle tab, shared by all states of the [savedBatchesProvider].
class const _PuzzleTabScaffold({required final Widget body}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) {
          ref.read(currentBottomTabProvider.notifier).state = BottomTab.home;
        }
      },
      child: PlatformScaffold(
        appBar: PlatformAppBar(
          title: Text(context.l10n.puzzles),
          centerTitle: false,
          titleTextStyle: Theme.of(context).platform == TargetPlatform.iOS
              ? Theme.of(context).textTheme.headlineSmall
              : null,
          actions: const [AccountMenuButton()],
        ),
        body: body,
      ),
    );
  }
}

class const _MaterialTabBody(final IList<PuzzleAngle> savedAngles) extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MaterialTabBody> createState() => _MaterialTabBodyState();
}

class _MaterialTabBodyState() extends ConsumerState<_MaterialTabBody> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late AnimatedListModel<PuzzleAngle> _angles;

  @override
  void initState() {
    super.initState();
    _angles = AnimatedListModel<PuzzleAngle>(
      listKey: _listKey,
      removedItemBuilder: _buildMainListRemovedItem,
      initialItems: widget.savedAngles,
      itemsOffset: 4,
    );
  }

  @override
  void didUpdateWidget(covariant _MaterialTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKeys = ISet(oldWidget.savedAngles);
    final newKeys = ISet(widget.savedAngles);

    if (oldKeys != newKeys) {
      final missings = oldKeys.difference(newKeys);
      if (missings.isNotEmpty) {
        for (final missing in missings) {
          final index = _angles.indexOf(missing);
          if (index != -1) {
            _angles.removeAt(index);
          }
        }
      }

      final additions = newKeys.difference(oldKeys);
      if (additions.isNotEmpty) {
        for (final addition in additions) {
          _angles.prepend(addition);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = isTabletOrLarger(context);

    Widget buildItem(BuildContext context, int index, Animation<double> animation) =>
        _buildMainListItem(context, index, animation, (index) => _angles[index]);

    return _PuzzleTabScaffold(
      body: isTablet
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AnimatedList(
                    key: _listKey,
                    initialItemCount: _angles.length,
                    controller: puzzlesScrollController,
                    itemBuilder: buildItem,
                  ),
                ),
                Expanded(child: ListView(children: const [PuzzleHistoryWidget()])),
              ],
            )
          : AnimatedList(
              key: _listKey,
              controller: puzzlesScrollController,
              initialItemCount: _angles.length,
              itemBuilder: buildItem,
            ),
    );
  }
}

Widget _buildMainListItem(
  BuildContext context,
  int index,
  Animation<double> animation,
  PuzzleAngle Function(int index) getAngle,
) {
  switch (index) {
    case 0:
      return const _PuzzleMenu();
    case 1:
      return Padding(
        padding: Styles.horizontalBodyPadding,
        child: Text(context.l10n.puzzleDesc, style: Styles.sectionTitle),
      );
    case 2:
      return const DailyPuzzle();
    case 3:
      return PuzzleAnglePreview(
        angle: const PuzzleTheme(PuzzleThemeKey.mix),
        onTap: () {
          Navigator.of(
            context,
            rootNavigator: true,
          ).push(PuzzleScreen.buildRoute(angle: const PuzzleTheme(PuzzleThemeKey.mix)));
        },
      );
    default:
      final angle = getAngle(index);
      return PuzzleAnglePreview(
        angle: angle,
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(PuzzleScreen.buildRoute(angle: angle));
        },
      );
  }
}

Widget _buildMainListRemovedItem(
  PuzzleAngle angle,
  BuildContext context,
  Animation<double> animation,
) {
  return SizeTransition(
    sizeFactor: animation,
    child: PuzzleAnglePreview(angle: angle),
  );
}

class const _PuzzleMenuListTile({
  required final IconData icon,
  required final String title,
  required final String subtitle,
  final String? badgeLabel,
  final VoidCallback? onTap,
  final bool enabled = true,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      leading: Badge(
        backgroundColor: ColorScheme.of(context).secondary,
        textStyle: TextStyle(
          color: ColorScheme.of(context).onSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        isLabelVisible: badgeLabel != null,
        label: (badgeLabel != null) ? Text(badgeLabel!) : null,
        child: Icon(icon, color: ColorScheme.of(context).primary),
      ),
      title: Text(title, style: Styles.mainListTileTitle),
      subtitle: Text(subtitle, maxLines: 3),
      trailing: Theme.of(context).platform == TargetPlatform.iOS
          ? const CupertinoListTileChevron()
          : null,
      onTap: onTap,
    );
  }
}

class const _PuzzleMenu() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isDeviceOnlineProvider);
    final authUser = ref.watch(authControllerProvider);

    return ListSection(
      hasLeading: true,
      children: [
        _PuzzleMenuListTile(
          icon: PuzzleIcons.opening,
          title: context.l10n.puzzlePuzzleThemes,
          subtitle: context.l10n.mobilePuzzleThemesSubtitle,
          onTap: () {
            Navigator.of(context).push(PuzzleThemesScreen.buildRoute());
          },
        ),
        _PuzzleMenuListTile(
          enabled: isOnline,
          icon: LichessIcons.streak,
          title: 'Puzzle Streak',
          badgeLabel: switch (ref.watch(savedStreakScoreProvider)) {
            AsyncData(:final value?) => value.toString(),
            _ => null,
          },
          subtitle:
              context.l10n.puzzleStreakDescription.characters
                  .takeWhile((c) => c != '.')
                  .toString() +
              (context.l10n.puzzleStreakDescription.contains('.') ? '.' : ''),
          onTap: isOnline
              ? () {
                  Navigator.of(context, rootNavigator: true).push(StreakScreen.buildRoute());
                }
              : null,
        ),
        _PuzzleMenuListTile(
          enabled: isOnline,
          icon: LichessIcons.storm,
          title: 'Puzzle Storm',
          subtitle: context.l10n.mobilePuzzleStormSubtitle,
          onTap: isOnline
              ? () {
                  Navigator.of(context, rootNavigator: true).push(StormScreen.buildRoute());
                }
              : null,
        ),
        if (authUser != null) ...[
          _PuzzleMenuListTile(
            icon: Icons.assessment_outlined,
            title: context.l10n.puzzlePuzzleDashboard,
            subtitle: context.l10n.puzzlePuzzleDashboardDescription,
            enabled: isOnline,
            onTap: isOnline
                ? () => Navigator.of(context).push(PuzzleDashboardScreen.buildRoute())
                : null,
          ),
          _PuzzleMenuListTile(
            icon: Icons.history_outlined,
            title: context.l10n.puzzleHistory,
            subtitle: 'Review your past puzzle attempts.',
            enabled: isOnline,
            onTap: isOnline
                ? () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).push(PuzzleHistoryScreen.buildRoute())
                : null,
          ),
        ],
      ],
    );
  }
}

class const PuzzleHistoryWidget({final bool showHeader = true}) extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(puzzleRecentActivityProvider);
    final isTablet = isTabletOrLarger(context);
    return asyncData.when(
      data: (recentActivity) {
        if (recentActivity == null) {
          return const SizedBox.shrink();
        }
        if (recentActivity.isEmpty) {
          return ListSection(
            header: showHeader ? Text(context.l10n.puzzleHistory) : null,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                  child: Text(context.l10n.puzzleNoPuzzlesToShow),
                ),
              ),
            ],
          );
        }

        final maxItems = isTablet
            ? _kNumberOfHistoryItemsOnTablet
            : _kNumberOfHistoryItemsOnHandset;

        return ListSection(
          backgroundColor: Colors.transparent,
          clipBehavior: Clip.none,
          header: showHeader ? Text(context.l10n.puzzleHistory) : null,
          onHeaderTap: showHeader
              ? () => Navigator.of(context).push(PuzzleHistoryScreen.buildRoute())
              : null,
          children: [PuzzleHistoryPreview(recentActivity.take(maxItems).toIList(), maxRows: 5)],
        );
      },
      error: (e, s) {
        debugPrint('SEVERE: [PuzzleHistoryWidget] could not load puzzle history');
        return const Padding(
          padding: Styles.bodySectionPadding,
          child: Text('Could not load Puzzle history.'),
        );
      },
      loading: () => Shimmer(
        child: ShimmerLoading(
          isLoading: true,
          child: ListSection.loading(itemsNumber: 5, header: true),
        ),
      ),
    );
  }
}
