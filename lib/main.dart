import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';

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
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open camera: $e')),
        );
      }
    }
  }

  Future<void> _uploadPhoto() async {
    if (_imageFile == null) return;

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
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('analyze_image');
        final response = await callable.call(<String, dynamic>{
          'gcs_uri': 'gs://${storageRef.bucket}/${storageRef.fullPath}',
        });
        aiResult = response.data['result'] as String;
      } catch (e) {
        aiResult = "Failed to process image with AI: $e";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload & Processing successful! \u2728'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Show AI result
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('AI Analysis Result'),
            content: SingleChildScrollView(child: Text(aiResult)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture & Upload'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                              Image.network(
                                _webImagePath!,
                                fit: BoxFit.cover,
                              )
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
                                        value: _uploadProgress > 0 ? _uploadProgress : null,
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
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No photo selected',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                onPressed: _imageFile == null || _isUploading ? null : _uploadPhoto,
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
