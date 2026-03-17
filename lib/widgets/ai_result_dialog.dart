import 'dart:convert';
import 'package:flutter/material.dart';
import '../main.dart'; // For GradientIndicatorBar

class AiResultDialog extends StatelessWidget {
  final String rawResult;
  final String? overallColorOverride; // For History compatibility

  const AiResultDialog({
    super.key,
    required this.rawResult,
    this.overallColorOverride,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? parsedJson;
    try {
      // Handle markdown code blocks if the AI returned them
      String cleanJson = rawResult;
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      } else if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      parsedJson = jsonDecode(cleanJson.trim());
    } catch (e) {
      // Fallback if parsing fails
      parsedJson = null;
    }

    if (parsedJson == null || !parsedJson.containsKey('food_name')) {
      return AlertDialog(
        title: const Text("Raw AI Output"),
        content: SingleChildScrollView(
          child: SelectableText(rawResult),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }

    final overallColor = overallColorOverride ?? (parsedJson['overall_color'] as String? ?? 'grey');
    Color indicatorColor = Colors.grey;
    switch (overallColor.toLowerCase()) {
      case 'green':
        indicatorColor = Colors.green;
        break;
      case 'yellow':
        indicatorColor = Colors.orange;
        break;
      case 'red':
        indicatorColor = Colors.red;
        break;
    }

    final diseaseAssessments =
        parsedJson['disease_assessments'] as Map<String, dynamic>? ?? {};
    final alternatives =
        parsedJson['healthy_alternatives'] as List<dynamic>? ?? [];

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parsedJson['food_name'] ?? 'Unknown Food',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          if (parsedJson['food_category'] != null)
            Text(
              parsedJson['food_category'],
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            overallColor.toUpperCase(),
            style: TextStyle(
              color: indicatorColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          GradientIndicatorBar(colorName: overallColor),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (parsedJson['overall_rating'] != null) ...[
               Text(
                'Rating: ${parsedJson['overall_rating']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
               const SizedBox(height: 8),
            ],
            if (parsedJson['overall_assessment'] != null) ...[
              const Text(
                'Overall Assessment:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(parsedJson['overall_assessment']),
              const SizedBox(height: 16),
            ],
            if (diseaseAssessments.isNotEmpty) ...[
              const Text(
                'Condition Assessments:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...diseaseAssessments.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(12.0),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(entry.value.toString()),
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (alternatives.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Healthy Alternatives:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...alternatives.map((alt) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(alt.toString())),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Raw Output"),
                content:
                    SingleChildScrollView(child: SelectableText(rawResult)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"))
                ],
              ),
            );
          },
          child: const Text('View Raw'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
