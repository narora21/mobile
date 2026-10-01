import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:lichess_mobile/l10n/l10n.dart';

/// Enum representing the editable widgets on the home screen.
enum HomeEditableWidget(
  /// True if the widget should always be enabled and cannot be disabled.
  final bool alwaysEnabled,
) {
  hello(false),
  perfCards(false),
  friends(false),
  ongoingGames(true),
  puzzles(false),
  blogCarousel(false),
  quickPairing(false),
  featuredTournaments(false),
  recentGames(false);

  /// Whether the user can move the widget. The greeting always stays at the top.
  bool get isReorderable => this != HomeEditableWidget.hello;

  String label(AppLocalizations l10n) => switch (this) {
    // not shown in the UI, so no need to localize
    HomeEditableWidget.ongoingGames => 'Ongoing Games',
    HomeEditableWidget.hello => l10n.mobileHello,
    // not shown in the UI, so no need to localize
    HomeEditableWidget.perfCards => 'Performance Cards',
    HomeEditableWidget.friends => l10n.friends,
    HomeEditableWidget.puzzles => l10n.puzzlePuzzles,
    HomeEditableWidget.quickPairing => l10n.quickPairing,
    HomeEditableWidget.featuredTournaments => l10n.openTournaments,
    HomeEditableWidget.recentGames => l10n.recentGames,
    HomeEditableWidget.blogCarousel => l10n.blog,
  };
}

/// The order of the home widgets until the user reorders them.
const kDefaultHomeWidgetOrder = IListConst<HomeEditableWidget>([
  HomeEditableWidget.hello,
  HomeEditableWidget.perfCards,
  HomeEditableWidget.friends,
  HomeEditableWidget.quickPairing,
  HomeEditableWidget.ongoingGames,
  HomeEditableWidget.puzzles,
  HomeEditableWidget.featuredTournaments,
  HomeEditableWidget.blogCarousel,
  HomeEditableWidget.recentGames,
]);

/// Completes a saved [order] with the widgets it is missing, such as widgets added after it was
/// saved, each inserted after the widget that precedes it in [kDefaultHomeWidgetOrder].
IList<HomeEditableWidget> completeHomeWidgetOrder(IList<HomeEditableWidget> order) {
  final result = order.toSet().toList();
  for (final (index, widget) in kDefaultHomeWidgetOrder.indexed) {
    if (result.contains(widget)) continue;
    final previous = index == 0 ? null : kDefaultHomeWidgetOrder[index - 1];
    result.insert(previous == null ? 0 : result.indexOf(previous) + 1, widget);
  }
  return result.lock;
}

/// Moves the widget at [oldIndex] of [visible] so it ends up at [newIndex], as reported by a
/// reorderable list that only shows the [visible] widgets, and returns the resulting full [order].
///
/// Widgets missing from [visible] keep their position relative to the widget that follows them.
IList<HomeEditableWidget> reorderVisibleHomeWidgets({
  required IList<HomeEditableWidget> order,
  required IList<HomeEditableWidget> visible,
  required int oldIndex,
  required int newIndex,
}) {
  final moved = visible[oldIndex];
  final remainingVisible = visible.remove(moved);
  final withoutMoved = order.remove(moved);
  if (newIndex >= remainingVisible.length) {
    final last = remainingVisible.last;
    return withoutMoved.insert(withoutMoved.indexOf(last) + 1, moved);
  }
  final next = remainingVisible[newIndex];
  return withoutMoved.insert(withoutMoved.indexOf(next), moved);
}
