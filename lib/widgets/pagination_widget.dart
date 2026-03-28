import 'package:flutter/material.dart';

class PaginationWidget extends StatefulWidget {
  final int totalPages;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

 const PaginationWidget({
    super.key,
    required this.totalPages,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  State<PaginationWidget> createState() => _PaginationWidgetState();
}

class _PaginationWidgetState extends State<PaginationWidget> {
  void _goToPage(int page) {
    if (page < 1 || page > widget.totalPages) return;
    widget.onPageChanged(page);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.totalPages, (index) {
        final isActive = widget.currentPage == index + 1;
        return GestureDetector(
          onTap: () => _goToPage(index + 1),
          child: Container(
            margin: const EdgeInsets.all(4.0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isActive ? Colors.blue : Colors.grey,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black,
              ),
            ),
          ),
        );
      })
    );
  }
}