import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';

class OfficeDetailsScreen extends ConsumerStatefulWidget {
  const OfficeDetailsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OfficeDetailsScreen> createState() => _OfficeDetailsScreenState();
}

class _OfficeDetailsScreenState extends ConsumerState<OfficeDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactController;
  bool _isLoading = true;
  String? _logoBase64;

  Uint8List? get _logoBytes {
    if (_logoBase64 == null || _logoBase64!.isEmpty) return null;
    try {
      return base64Decode(_logoBase64!);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _contactController = TextEditingController();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = ref.read(userProfileProvider).value;
    setState(() {
      _nameController.text = profile?['office_name'] ?? prefs.getString('office_name') ?? 'My Laundry Co.';
      _addressController.text = (profile?['office_preferences']?['address'] as String?) ?? prefs.getString('office_address') ?? '123 Clean St, Suite 4';
      _contactController.text = profile?['office_contact_info'] ?? prefs.getString('office_contact') ?? '+1 234 567 8900';
      _logoBase64 = prefs.getString('office_logo_base64') ?? (profile?['office_preferences']?['logo_base64'] as String?);
      _isLoading = false;
    });
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _logoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _removeLogo() {
    setState(() {
      _logoBase64 = null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _saveDetails() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final profile = ref.read(userProfileProvider).value;
        final officeId = profile?['office_id'];
        
        final existingPreferences = Map<String, dynamic>.from(profile?['office_preferences'] ?? {});
        existingPreferences['logo_base64'] = _logoBase64;
        existingPreferences['address'] = _addressController.text;
        
        if (officeId != null) {
          final api = ref.read(apiServiceProvider);
          await api.updateOfficeDetails(officeId, {
            'name': _nameController.text,
            'contact_info': _contactController.text,
            'preferences': existingPreferences,
          });
        }
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('office_name', _nameController.text);
        await prefs.setString('office_address', _addressController.text);
        await prefs.setString('office_contact', _contactController.text);
        if (_logoBase64 != null) {
          await prefs.setString('office_logo_base64', _logoBase64!);
        } else {
          await prefs.remove('office_logo_base64');
        }
        
        ref.invalidate(officeNameProvider);
        ref.invalidate(officeLogoProvider);
        ref.invalidate(userProfileProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Office details saved successfully!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save office details: ${e.toString().replaceAll('Exception:', '').trim()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoBytes = _logoBytes;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Office Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveDetails,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickLogo,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                          image: logoBytes != null
                              ? DecorationImage(
                                  image: MemoryImage(logoBytes),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: logoBytes == null
                            ? const Icon(Icons.add_a_photo, size: 36, color: AppTheme.primaryColor)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: logoBytes == null ? _pickLogo : _removeLogo,
                      child: Text(
                        logoBytes == null ? 'Upload Logo' : 'Remove Logo',
                        style: TextStyle(
                          color: logoBytes == null ? AppTheme.primaryColor : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Brand Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a brand name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Office Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a contact number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text('Save Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
