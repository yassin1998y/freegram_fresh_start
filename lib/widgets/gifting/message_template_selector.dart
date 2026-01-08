import 'package:flutter/material.dart';
import 'package:freegram/models/message_template_model.dart';
import 'package:freegram/utils/haptic_helper.dart';

/// Message template selector widget
class MessageTemplateSelector extends StatefulWidget {
  final Function(String) onTemplateSelected;
  final String? initialMessage;

  const MessageTemplateSelector({
    super.key,
    required this.onTemplateSelected,
    this.initialMessage,
  });

  @override
  State<MessageTemplateSelector> createState() =>
      _MessageTemplateSelectorState();
}

class _MessageTemplateSelectorState extends State<MessageTemplateSelector> {
  String _selectedCategory = 'general';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.message, size: 20),
              const SizedBox(width: 8),
              Text(
                'Message Templates',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  HapticHelper.light();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),

        // Category tabs
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: MessageTemplates.categories.length,
            itemBuilder: (context, index) {
              final category = MessageTemplates.categories[index];
              final isSelected = category == _selectedCategory;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(MessageTemplates.getCategoryName(category)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      HapticHelper.selection();
                      setState(() => _selectedCategory = category);
                    }
                  },
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Templates list
        SizedBox(
          height: 300,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: MessageTemplates.getByCategory(_selectedCategory).length,
            itemBuilder: (context, index) {
              final template =
                  MessageTemplates.getByCategory(_selectedCategory)[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(template.icon, color: Colors.purple),
                  title: Text(template.text),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    HapticHelper.light();
                    widget.onTemplateSelected(template.text);
                  },
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

/// Compact template chips for inline display
class MessageTemplateChips extends StatelessWidget {
  final Function(String) onTemplateSelected;
  final String category;

  const MessageTemplateChips({
    super.key,
    required this.onTemplateSelected,
    this.category = 'general',
  });

  @override
  Widget build(BuildContext context) {
    final templates = MessageTemplates.getByCategory(category).take(3).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: templates.map((template) {
        return ActionChip(
          avatar: Icon(template.icon, size: 16),
          label: Text(
            template.text,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: () {
            HapticHelper.light();
            onTemplateSelected(template.text);
          },
        );
      }).toList(),
    );
  }
}
