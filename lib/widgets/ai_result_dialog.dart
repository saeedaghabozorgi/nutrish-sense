import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Add kDebugMode
import '../main.dart'; // For GradientIndicatorBar

class AiResultDialog extends StatelessWidget {
  final String rawResult;
  final String? overallColorOverride; // For History compatibility
  final String? docId;
  final String? currentDecision;

  const AiResultDialog({
    super.key,
    required this.rawResult,
    this.overallColorOverride,
    this.docId,
    this.currentDecision,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? parsedJson;
    try {
      final match = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(rawResult);
      final cleanJson = match != null ? match.group(1)! : rawResult;
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
          OutlinedButton.icon(
            onPressed: () async {
              if (docId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot save decision: Document ID is missing.')));
                return;
              }
              final scaffold = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();
              try {
                await FirebaseFirestore.instance.collection('photos').doc(docId).update({'userDecision': 'pass'});
                scaffold.clearSnackBars();
                scaffold.showSnackBar(const SnackBar(content: Text('Decision tracked: Passed!')));
              } catch (e) {
                scaffold.showSnackBar(const SnackBar(content: Text('Database failure. Not saved.'), backgroundColor: Colors.red));
                debugPrint('Background error: $e');
              }
            },
            icon: const Icon(Icons.block),
            label: Text(currentDecision == 'pass' ? 'Passed' : "I'll Pass"),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: currentDecision == 'pass' ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.outline),
              foregroundColor: currentDecision == 'pass' ? Theme.of(context).colorScheme.error : null,
            ),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (docId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot save decision: Document ID is missing.')));
                return;
              }
              final scaffold = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();
              try {
                await FirebaseFirestore.instance.collection('photos').doc(docId).update({'userDecision': 'consume'});
                scaffold.clearSnackBars();
                scaffold.showSnackBar(const SnackBar(content: Text('Decision tracked: Eaten!')));
              } catch (e) {
                scaffold.showSnackBar(const SnackBar(content: Text('Database failure. Not saved.'), backgroundColor: Colors.red));
                debugPrint('Background error: $e');
              }
            },
            icon: const Icon(Icons.restaurant),
            label: Text(currentDecision == 'consume' ? 'Consumed' : "I'll Eat It!"),
            style: FilledButton.styleFrom(
              backgroundColor: currentDecision == 'consume' ? Colors.green : null,
            ),
          ),
        if (kDebugMode)
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
