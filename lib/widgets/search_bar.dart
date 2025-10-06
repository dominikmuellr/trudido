import 'package:flutter/material.dart';

class TodoSearchBar extends StatefulWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;

  const TodoSearchBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  State<TodoSearchBar> createState() => _TodoSearchBarState();
}

class _TodoSearchBarState extends State<TodoSearchBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: 'Search todos...',
        prefixIcon: Icon(Icons.search),
        suffixIcon: widget.searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  _controller.clear();
                  widget.onSearchChanged('');
                },
              )
            : null,
      ),
      onChanged: widget.onSearchChanged,
    );
  }
}
