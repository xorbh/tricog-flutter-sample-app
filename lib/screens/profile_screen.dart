import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _medicationsController = TextEditingController();
  String _gender = 'Male';
  DateTime? _dateOfBirth;
  final Set<String> _selectedConditions = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await DatabaseService.instance.getProfile();
    if (profile != null) {
      _nameController.text = profile.name;
      _medicationsController.text = profile.medications ?? '';
      _gender = profile.gender;
      _dateOfBirth = profile.dateOfBirth;
      _selectedConditions.addAll(profile.medicalConditions);
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _medicationsController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1980, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) return;

    final profile = UserProfile(
      name: _nameController.text.trim(),
      dateOfBirth: _dateOfBirth!,
      gender: _gender,
      medicalConditions: _selectedConditions.toList(),
      medications: _medicationsController.text.trim().isEmpty
          ? null
          : _medicationsController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await DatabaseService.instance.saveProfile(profile);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withAlpha(30),
                child: const Icon(Icons.person, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 24),

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

              GestureDetector(
                onTap: _pickDateOfBirth,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      prefixIcon: const Icon(Icons.cake),
                      hintText: 'Tap to select',
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

              const Text('Medical Conditions', style: TextStyle(fontWeight: FontWeight.w500)),
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

              TextFormField(
                controller: _medicationsController,
                decoration: const InputDecoration(
                  labelText: 'Current Medications (optional)',
                  prefixIcon: Icon(Icons.medication),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Text('Save Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
