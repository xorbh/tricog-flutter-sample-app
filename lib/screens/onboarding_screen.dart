import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _medicationsController = TextEditingController();
  String _gender = 'Male';
  DateTime? _dateOfBirth;
  final Set<String> _selectedConditions = {};

  @override
  void dispose() {
    _nameController.dispose();
    _medicationsController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1980, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: 'Select your date of birth',
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
      return;
    }

    final now = DateTime.now();
    final profile = UserProfile(
      name: _nameController.text.trim(),
      dateOfBirth: _dateOfBirth!,
      gender: _gender,
      medicalConditions: _selectedConditions.toList(),
      medications: _medicationsController.text.trim().isEmpty
          ? null
          : _medicationsController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await DatabaseService.instance.saveProfile(profile);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Icon(Icons.monitor_heart, size: 64, color: AppColors.primary),
                const SizedBox(height: 12),
                const Text(
                  'Welcome to CardioScan',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  "Let's set up your profile",
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Date of Birth
                GestureDetector(
                  onTap: _pickDateOfBirth,
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Date of Birth',
                        prefixIcon: const Icon(Icons.cake),
                        hintText: _dateOfBirth != null
                            ? DateFormat('MMM d, yyyy').format(_dateOfBirth!)
                            : 'Tap to select',
                      ),
                      controller: TextEditingController(
                        text: _dateOfBirth != null
                            ? DateFormat('MMM d, yyyy').format(_dateOfBirth!)
                            : '',
                      ),
                      validator: (_) => _dateOfBirth == null ? 'Required' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Gender
                const Text('Gender', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Male', label: Text('Male'), icon: Icon(Icons.male)),
                    ButtonSegment(value: 'Female', label: Text('Female'), icon: Icon(Icons.female)),
                    ButtonSegment(value: 'Other', label: Text('Other')),
                  ],
                  selected: {_gender},
                  onSelectionChanged: (v) => setState(() => _gender = v.first),
                ),
                const SizedBox(height: 24),

                // Medical Conditions
                const Text('Medical Conditions', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Select any that apply', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: UserProfile.commonConditions.map((condition) {
                    final selected = _selectedConditions.contains(condition);
                    return FilterChip(
                      label: Text(condition),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedConditions.add(condition);
                          } else {
                            _selectedConditions.remove(condition);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Medications
                TextFormField(
                  controller: _medicationsController,
                  decoration: const InputDecoration(
                    labelText: 'Current Medications (optional)',
                    prefixIcon: Icon(Icons.medication),
                    hintText: 'e.g., Aspirin 75mg, Metoprolol 50mg',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 32),

                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Get Started'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
