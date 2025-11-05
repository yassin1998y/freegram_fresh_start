// lib/widgets/feed_widgets/edit_comment_dialog.dart

import 'package:flutter/material.dart';

class EditCommentDialog extends StatefulWidget {
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final int maxLength;

  const EditCommentDialog({
    required this.controller,
    required this.formKey,
    required this.maxLength,
  });

  @override
  State<EditCommentDialog> createState() => _EditCommentDialogState();
}

class _EditCommentDialogState extends State<EditCommentDialog> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // Don't dispose controller here - it's managed by the caller
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {}); // Update character counter
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Comment'),
      content: Form(
        key: widget.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextFormField(
              controller: widget.controller,
              decoration: const InputDecoration(
                hintText: 'Edit your comment...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: widget.maxLength,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Comment cannot be empty';
                }
                if (value.trim().length > widget.maxLength) {
                  return 'Comment is too long';
                }
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '${widget.controller.text.length}/${widget.maxLength}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          widget.controller.text.length > widget.maxLength * 0.9
                              ? Colors.orange
                              : Colors.grey[600],
                      fontSize: 11,
                    ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (widget.formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, widget.controller.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
