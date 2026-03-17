import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'firebase_options.dart';
import 'widgets/ai_result_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DietaryApp());
}

class DietaryApp extends StatelessWidget {
  const DietaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dietary Recommendations',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0), // Medical Blue
          primary: const Color(0xFF1565C0),
          secondary: const Color(0xFF00ACC1), // Cyan accent
          surface: Colors.white,
          surfaceContainerHighest: const Color(0xFFF5F7FA), // Soft background
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.nunitoTextTheme(Theme.of(context).textTheme),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const MainScreen();
        }
        return const AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;

  Future<void> _submitAuth() async {
    if (!_isLogin &&
        _passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 64),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
            if (!_isLogin) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock_reset),
                ),
                obscureText: true,
              ),
            ],
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _submitAuth,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isLogin ? 'Login' : 'Sign Up',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(
                _isLogin ? 'Create an account' : 'I already have an account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dietary Recommendations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [AnalyzeTab(), HistoryTab(), ProfileTab()],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          elevation: 0,
          backgroundColor: Colors.white,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.medical_information_outlined),
              selectedIcon: Icon(Icons.medical_information),
              label: 'Analyze',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_edu_outlined),
              selectedIcon: Icon(Icons.history_edu),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.health_and_safety_outlined),
              selectedIcon: Icon(Icons.health_and_safety),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class AnalyzeTab extends StatefulWidget {
  const AnalyzeTab({super.key});

  @override
  State<AnalyzeTab> createState() => _AnalyzeTabState();
}

class _AnalyzeTabState extends State<AnalyzeTab> {
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _webImagePath;

  List<String> _selectedDiseases = [];
  final List<String> _allDiseases = [
    'Diabetic',
    'High Blood Pressure',
    'Gout',
    'Healthy adult (General Nutrition)',
  ];

  String _labResults = '';
  String _medications = '';
  String _allergies = '';
  double _activityLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDefaultDisease();
  }

  Future<void> _loadDefaultDisease() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data.containsKey('defaultDiseases')) {
          final diseases = List<String>.from(data['defaultDiseases'] as List);
          setState(() {
            _selectedDiseases = diseases
                .where((d) => _allDiseases.contains(d))
                .toList();
          });
        } else if (data.containsKey('defaultDisease')) {
          // Migration step for old singular profiles
          final disease = data['defaultDisease'] as String;
          if (_allDiseases.contains(disease)) {
            setState(() {
              _selectedDiseases = [disease];
            });
          }
        }

        setState(() {
          _labResults = data['labResults'] ?? '';
          _medications = data['medicationList'] ?? '';
          _allergies = data['allergies'] ?? '';
          if (data['activityLevel'] != null) {
            _activityLevel = (data['activityLevel'] as num).toDouble();
          }
        });
      }
    }
  }

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

    // Default to Healthy Adult if nothing is selected
    if (_selectedDiseases.isEmpty) {
      setState(() {
        _selectedDiseases.add('Healthy adult (General Nutrition)');
      });
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("You must be logged in to upload.");
      }

      final fileName =
          'photos/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask;
      if (kIsWeb) {
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

      setState(() {
        _uploadProgress = 1.0;
      });

      String aiResult = "";

      try {
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
          'analyze_image',
          options: HttpsCallableOptions(timeout: const Duration(minutes: 3)),
        );
        final contextString = _selectedDiseases.join(', ');
        final response = await callable.call(<String, dynamic>{
          'gcs_uri': 'gs://${storageRef.bucket}/${storageRef.fullPath}',
          'disease': contextString,
          'labResults': _labResults,
          'medications': _medications,
          'allergies': _allergies,
          'activityLevel': _activityLevel,
        });
        final rawResult = response.data['result'];

        if (rawResult is String) {
          aiResult = rawResult;
        } else {
          try {
            aiResult = const JsonEncoder.withIndent('  ').convert(rawResult);
          } catch (_) {
            aiResult = rawResult.toString();
          }
        }
      } catch (e) {
        aiResult = "Error: Failed to process image with AI: $e";
      }

      // Save to Firestore History
      await FirebaseFirestore.instance.collection('photos').add({
        'userId': user.uid,
        'storageUrl': 'gs://${storageRef.bucket}/${storageRef.fullPath}',
        'diseaseContext': _selectedDiseases.join(', '),
        'rawResult': aiResult,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification Complete! History Logged.'),
            backgroundColor: Colors.green,
          ),
        );
        // Show result dialog
        showDialog(
          context: context,
          builder: (context) {
            return AiResultDialog(rawResult: aiResult);
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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
    return SafeArea(
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
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              shadowColor: Colors.black.withValues(alpha: 0.2),
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: _allDiseases.map((String disease) {
                    return CheckboxListTile(
                      title: Text(
                        disease,
                        style: const TextStyle(fontSize: 14),
                      ),
                      value: _selectedDiseases.contains(disease),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                      ),
                      onChanged: _isUploading
                          ? null
                          : (bool? isChecked) {
                              setState(() {
                                if (isChecked == true) {
                                  _selectedDiseases.add(disease);
                                } else {
                                  _selectedDiseases.remove(disease);
                                }
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
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
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
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text(
                'Take Photo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _imageFile == null || _isUploading
                  ? null
                  : _uploadPhoto,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text(
                'Analyze',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _countryController = TextEditingController();

  // Advanced User Profile
  final _labResultsController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _allergiesController = TextEditingController();
  double _activityLevel = 0;

  List<String> _selectedDiseases = [];
  final List<String> _allDiseases = [
    'Diabetic',
    'High Blood Pressure',
    'Gout',
    'Healthy adult (General Nutrition)',
  ];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          _phoneController.text = data['phoneNumber'] ?? '';
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          if (data['birthYear'] != null) {
            _birthYearController.text = data['birthYear'].toString();
          }
          _countryController.text = data['country'] ?? '';

          _labResultsController.text = data['labResults'] ?? '';
          _medicationsController.text = data['medicationList'] ?? '';
          _allergiesController.text = data['allergies'] ?? '';
          if (data['activityLevel'] != null) {
            _activityLevel = (data['activityLevel'] as num).toDouble();
          }

          if (data.containsKey('defaultDiseases')) {
            final diseases = List<String>.from(data['defaultDiseases'] as List);
            _selectedDiseases = diseases
                .where((d) => _allDiseases.contains(d))
                .toList();
          } else if (data.containsKey('defaultDisease')) {
            // Migration
            final disease = data['defaultDisease'] as String;
            if (_allDiseases.contains(disease)) {
              _selectedDiseases = [disease];
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading profile: $e');
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': _emailController.text,
          'phoneNumber': _phoneController.text,
          'firstName': _firstNameController.text,
          'lastName': _lastNameController.text,
          'birthYear': int.tryParse(_birthYearController.text),
          'country': _countryController.text,
          'labResults': _labResultsController.text,
          'medicationList': _medicationsController.text,
          'allergies': _allergiesController.text,
          'activityLevel': _activityLevel,
          'defaultDiseases': _selectedDiseases,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Profile details',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              enabled: false,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: 'First Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: 'Last Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _birthYearController,
                    decoration: InputDecoration(
                      labelText: 'Birth Year',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _countryController,
                    decoration: InputDecoration(
                      labelText: 'Country',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.public_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              'Advanced Medical Profile (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _labResultsController,
              decoration: InputDecoration(
                labelText: 'Lab Results / Biomarkers',
                hintText: 'e.g. HbA1c: 6.5, Uric Acid: 8.0 mg/dL',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.science_outlined),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _medicationsController,
              decoration: InputDecoration(
                labelText: 'Current Medications',
                hintText: 'e.g. Statins, Warfarin, Insulin',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.medication_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _allergiesController,
              decoration: InputDecoration(
                labelText: 'Allergies & Intolerances',
                hintText: 'e.g. Celiac, Peanuts, Dairy',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.warning_amber_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            const Text(
              'Activity Level (0 = Sedentary, 5 = Highly Active)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _activityLevel,
              min: 0,
              max: 5,
              divisions: 5,
              label: _activityLevel.round().toString(),
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (double value) {
                setState(() {
                  _activityLevel = value;
                });
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Default Medical Conditions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              shadowColor: Colors.black.withValues(alpha: 0.2),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: _allDiseases.map((String disease) {
                    return CheckboxListTile(
                      title: Text(
                        disease,
                        style: const TextStyle(fontSize: 14),
                      ),
                      value: _selectedDiseases.contains(disease),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                      ),
                      onChanged: (bool? isChecked) {
                        setState(() {
                          if (isChecked == true) {
                            _selectedDiseases.add(disease);
                          } else {
                            _selectedDiseases.remove(disease);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Not logged in."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('photos')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_toggle_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                const Text("No past analyses found."),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final tA =
              (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final tB =
              (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tB.compareTo(tA); // descending
        });

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = data['createdAt'] as Timestamp?;
            final dateStr = timestamp != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    timestamp.millisecondsSinceEpoch,
                  ).toLocal().toString().split('.')[0]
                : 'Unknown Date';

            final overallColor = data['overallColor'] as String? ?? 'Grey';
            Color indicatorColor;
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
              default:
                indicatorColor = Colors.grey;
            }

            final foodName = data.containsKey('rawResult') ? 'Raw AI Result' : (data['foodName'] as String? ?? 'Unknown Food');
            final assessments = data['assessments'] as List<dynamic>? ?? [];

            String summaryText = 'Click to view detailed analysis.';
            if (data.containsKey('rawResult')) {
               summaryText = 'Click to view raw JSON output.';
            } else if (assessments.isNotEmpty) {
              summaryText = '${assessments.length} condition(s) analyzed.';
            }

            return Card(
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: indicatorColor,
                  child: const Icon(
                    Icons.monitor_heart_outlined,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  foodName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      summaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                isThreeLine: true,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      if (data.containsKey('rawResult')) {
                         return AiResultDialog(rawResult: data['rawResult']);
                      } else {
                         return AlertDialog(
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  foodName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  overallColor,
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
                                  const Text(
                                    'Individual Assessments:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  ...assessments.map((a) {
                                    Color condColor = Colors.grey;
                                    switch ((a['color'] as String?)?.toLowerCase()) {
                                      case 'green':
                                        condColor = Colors.green;
                                        break;
                                      case 'yellow':
                                        condColor = Colors.orange;
                                        break;
                                      case 'red':
                                        condColor = Colors.red;
                                        break;
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: Container(
                                        padding: const EdgeInsets.all(8.0),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: condColor.withValues(alpha: 0.5),
                                          ),
                                          borderRadius: BorderRadius.circular(8.0),
                                          color: condColor.withValues(alpha: 0.1),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${a["condition"] ?? "Condition"} - ${a["color"] ?? "Grey"}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: condColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(a["reasoning"] ?? ""),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Alternatives:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(data['alternatives'] ?? 'N/A'),
                                ],
                              ),
                            ),
                            actions: [
                              if (data['storageUrl'] != null)
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      final url = await FirebaseStorage.instance
                                          .refFromURL(data['storageUrl'])
                                          .getDownloadURL();
                                      if (context.mounted) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            content: Image.network(url),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Close Photo'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Could not load image.'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('View Photo'),
                                ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          );
                      }
                    }
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class GradientIndicatorBar extends StatelessWidget {
  final String colorName; // "green", "yellow", "red"

  const GradientIndicatorBar({super.key, required this.colorName});

  @override
  Widget build(BuildContext context) {
    double alignment = 0.0;
    final lowerColor = colorName.toLowerCase();
    if (lowerColor == 'green') {
      alignment = -0.8;
    } else if (lowerColor == 'yellow') {
      alignment = 0.0;
    } else if (lowerColor == 'red') {
      alignment = 0.8;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [Colors.green, Colors.orange, Colors.red],
                ),
              ),
            ),
            Align(
              alignment: Alignment(alignment, 0.0),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black87, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
