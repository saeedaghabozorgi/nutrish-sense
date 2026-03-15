import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import 'dart:convert';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Catching the unsupported error when options aren't generated yet
    debugPrint("Firebase init error: $e");
  }
  runApp(const PhotoUploadApp());
}

class PhotoUploadApp extends StatelessWidget {
  const PhotoUploadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Upload',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _webImagePath;

  String? _selectedDisease = 'Healthy adult (General Nutrition)';
  final List<String> _diseases = [
    'Diabetic',
    'High Blood Pressure',
    'Gout',
    'Healthy adult (General Nutrition)',
  ];

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _imageFile = photo;
          _webImagePath = photo.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open camera: $e')));
      }
    }
  }

  Future<void> _uploadPhoto() async {
    if (_imageFile == null) return;

    if (_selectedDisease == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your medical condition first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final fileName = 'photos/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask;
      if (kIsWeb) {
        // Use byte upload on web as File is not fully supported for some IO operations
        final bytes = await _imageFile!.readAsBytes();
        uploadTask = storageRef.putData(bytes);
      } else {
        uploadTask = storageRef.putFile(File(_imageFile!.path));
      }

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask;

      // Keep loading spinner active for AI Processing
      setState(() {
        _uploadProgress = 1.0;
      });

      String aiResult = "";

      try {
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
          'analyze_image',
        );
        final response = await callable.call(<String, dynamic>{
          'gcs_uri': 'gs://${storageRef.bucket}/${storageRef.fullPath}',
          'disease': _selectedDisease,
        });
        aiResult = response.data['result'] as String;
      } catch (e) {
        aiResult =
            '{"color": "Red", "assessment": "Failed to process image with AI: $e", "alternatives": "N/A"}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload & Processing successful! \u2728'),
            backgroundColor: Colors.green,
          ),
        );

        // Show AI result
        _showResultDialog(aiResult);

        setState(() {
          _imageFile = null; // Reset view after successful upload
          _webImagePath = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildColorScale(String colorStr) {
    double alignment = 0.0;
    if (colorStr.toLowerCase().contains('green')) {
      alignment = -1.0;
    } else if (colorStr.toLowerCase().contains('red')) {
      alignment = 1.0;
    }

    return Column(
      children: [
        Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              colors: [Colors.green, Colors.orange, Colors.red],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment(alignment, 0),
          child: Icon(
            Icons.arrow_drop_up,
            size: 32,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  void _showResultDialog(String aiResultJson) {
    // Attempt to parse the JSON string, but provide fallback if it fails
    String colorStr = "Yellow";
    String assessment = "Could not parse assessment.";
    String alternatives = "";

    Color uiColor = Colors.orange;
    IconData uiIcon = Icons.warning_amber_rounded;

    try {
      final Map<String, dynamic> data = jsonDecode(aiResultJson);
      colorStr = data['color']?.toString() ?? "Yellow";
      assessment = data['assessment']?.toString() ?? "No assessment provided.";
      alternatives = data['alternatives']?.toString() ?? "";
    } catch (e) {
      // If the AI failed to return strict JSON, just show the raw string as a fallback
      final RegExp regex = RegExp(r'```json\s*(.*?)\s*```', dotAll: true);
      final match = regex.firstMatch(aiResultJson);
      if (match != null) {
        try {
          final Map<String, dynamic> data = jsonDecode(match.group(1)!);
          colorStr = data['color']?.toString() ?? "Yellow";
          assessment =
              data['assessment']?.toString() ?? "No assessment provided.";
          alternatives = data['alternatives']?.toString() ?? "";
        } catch (e2) {
          assessment = aiResultJson;
        }
      } else {
        assessment = aiResultJson;
      }
    }

    if (colorStr.toLowerCase().contains("green")) {
      uiColor = Colors.green;
      uiIcon = Icons.check_circle_outline;
    } else if (colorStr.toLowerCase().contains("red")) {
      uiColor = Colors.redAccent;
      uiIcon = Icons.cancel_outlined;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        ),
        child: SafeArea(
          child: ListView(
            children: [
              Icon(uiIcon, size: 64, color: uiColor),
              const SizedBox(height: 16),
              Text(
                colorStr.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: uiColor,
                ),
              ),
              const SizedBox(height: 24),
              _buildColorScale(colorStr),
              const SizedBox(height: 24),
              const Text(
                'Assessment Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                assessment.length > 150
                    ? '${assessment.substring(0, 150)}...'
                    : assessment,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text(
                  'More Details & Alternatives',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                childrenPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                children: [
                  Text(assessment, style: const TextStyle(fontSize: 14)),
                  if (alternatives.isNotEmpty &&
                      alternatives.toLowerCase() != "n/a" &&
                      !colorStr.toLowerCase().contains("green")) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Healthier Alternatives',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(alternatives, style: const TextStyle(fontSize: 14)),
                  ],
                ],
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it!'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dietary Recommendations')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select your medical condition:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: _diseases.map((String disease) {
                      return RadioListTile<String>(
                        title: Text(
                          disease,
                          style: const TextStyle(fontSize: 14),
                        ),
                        value: disease,
                        groupValue: _selectedDisease,
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                        ),
                        onChanged: _isUploading
                            ? null
                            : (String? newValue) {
                                setState(() {
                                  _selectedDisease = newValue;
                                });
                              },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _imageFile != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            if (kIsWeb && _webImagePath != null)
                              Image.network(_webImagePath!, fit: BoxFit.cover)
                            else
                              Image.file(
                                File(_imageFile!.path),
                                fit: BoxFit.cover,
                              ),
                            if (_isUploading)
                              Container(
                                color: Colors.black54,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                        value: _uploadProgress > 0
                                            ? _uploadProgress
                                            : null,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _uploadProgress >= 1.0
                                            ? 'Analyzing with AI...'
                                            : 'Uploading... ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No photo selected',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isUploading ? null : _takePhoto,
                icon: const Icon(Icons.camera),
                label: const Text('Take Photo'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16.0),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _imageFile == null || _isUploading
                    ? null
                    : _uploadPhoto,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Upload to Cloud'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
