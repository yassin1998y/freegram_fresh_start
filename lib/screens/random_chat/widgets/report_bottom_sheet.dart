import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freegram/blocs/interaction/interaction_bloc.dart';
import 'package:freegram/blocs/interaction/interaction_event.dart';

class ReportBottomSheet extends StatefulWidget {
  final String userId;
  final String userName;

  const ReportBottomSheet({
    super.key,
    required this.userId,
    required this.userName,
  });

  static void show(BuildContext context,
      {required String userId, String userName = 'User'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ReportBottomSheet(userId: userId, userName: userName),
    );
  }

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  final _reasonController = TextEditingController();
  String? _selectedCategory;

  final Map<String, String> _categories = {
    'nudity': 'Nudity or Sexual Content',
    'harassment': 'Harassment or Bullying',
    'violence': 'Violence or Dangerous Organizations',
    'spam': 'Scam or Spam',
    'other': 'Other',
  };

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submitReport() {
    if (_selectedCategory == null) return;

    context.read<InteractionBloc>().add(
          ReportUserEvent(
            userId: widget.userId,
            category: _selectedCategory!,
            reason: _reasonController.text.trim(),
          ),
        );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            "Report received. We've flagged this user and disconnected you."),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            'Report ${widget.userName}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Why are you reporting this user?',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Categories
          ..._categories.entries.map((entry) {
            final isSelected = _selectedCategory == entry.key;
            return InkWell(
              onTap: () => setState(() => _selectedCategory = entry.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.red.withOpacity(0.2)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Colors.red : Colors.grey[800]!,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      entry.value,
                      style: TextStyle(
                        color: isSelected ? Colors.red : Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                          color: Colors.red, size: 20),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 10),

          // Optional Details
          TextField(
            controller: _reasonController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Additional details (optional)',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 20),

          // Submit Button
          ElevatedButton(
            onPressed: _selectedCategory != null ? _submitReport : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[800],
              disabledForegroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Submit Report',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
