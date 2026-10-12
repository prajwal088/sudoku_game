import 'package:flutter/material.dart';

/// ============================================================================
/// PaginationWidget
/// ----------------------------------------------------------------------------
/// A centered row of numbered page chips.
///
/// - Up to [_maxVisibleItems] pages are all shown, exactly like a plain list
///   of chips.
/// - With more pages, the row is windowed so it can never overflow the
///   screen: the first page, the last page and the pages around the current
///   one are shown, with "…" for the gaps (for example `1 … 9 10 11 … 20`).
/// - Tapping the already-selected page does nothing, so the parent is not
///   asked to reload what it is already showing.
/// - Every chip is exposed to screen readers as a button ("Page 3").
///
/// Pages are 1-based.
/// ============================================================================

class PaginationWidget extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  const PaginationWidget({
    super.key,
    required this.totalPages,
    required this.currentPage,
    required this.onPageChanged,
  });

  /// Most chips (pages plus ellipses) ever shown at once. Seven fits a
  /// 320 dp wide screen.
  static const int _maxVisibleItems = 7;

  static const double _chipSpacing = 4;
  static const EdgeInsets _chipPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 5,
  );

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================

  void _goToPage(int page) {
    if (page < 1 || page > totalPages || page == currentPage) return;

    onPageChanged(page);
  }

  // ==========================================================================
  // VISIBLE ITEMS
  // ==========================================================================

  /// Returns the page numbers to show, with `null` standing for "…".
  List<int?> _visibleItems() {
    if (totalPages <= _maxVisibleItems) {
      return List<int?>.generate(totalPages, (int i) => i + 1, growable: false);
    }

    // Keep the current page inside the valid range for window maths even if
    // the parent passes something out of range.
    final int current = currentPage < 1
        ? 1
        : (currentPage > totalPages ? totalPages : currentPage);

    final List<int> pages = <int>{
      1,
      totalPages,
      current - 1,
      current,
      current + 1,
    }.where((int page) => page >= 1 && page <= totalPages).toList()..sort();

    final List<int?> items = <int?>[];

    for (int i = 0; i < pages.length; i++) {
      if (i > 0) {
        final int gap = pages[i] - pages[i - 1];

        if (gap == 2) {
          // A single missing page is shown instead of a pointless "…".
          items.add(pages[i - 1] + 1);
        } else if (gap > 2) {
          items.add(null);
        }
      }

      items.add(pages[i]);
    }

    return items;
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (totalPages < 1) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (final int? page in _visibleItems())
          page == null ? _buildEllipsis() : _buildPageChip(page),
      ],
    );
  }

  Widget _buildPageChip(int page) {
    final bool isActive = currentPage == page;

    return Padding(
      padding: const EdgeInsets.all(_chipSpacing),
      child: Semantics(
        button: true,
        selected: isActive,
        label: 'Page $page',
        // The visible digit is summarised by the label.
        excludeSemantics: true,
        onTap: () => _goToPage(page),
        child: Material(
          color: isActive ? Colors.blue : Colors.grey,
          borderRadius: BorderRadius.circular(5),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _goToPage(page),
            child: Padding(
              padding: _chipPadding,
              child: Text(
                '$page',
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEllipsis() {
    return const Padding(
      padding: EdgeInsets.all(_chipSpacing),
      child: ExcludeSemantics(
        child: Padding(
          padding: _chipPadding,
          child: Text('…'),
        ),
      ),
    );
  }
}