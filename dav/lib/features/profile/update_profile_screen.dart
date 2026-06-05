import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;

  String? _userType; // 'student' or 'teacher'
  final _departmentCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _rollNoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = ApiService().currentUser ?? {};
    _nameCtrl = TextEditingController(text: user['name'] ?? '');
    _emailCtrl = TextEditingController(text: user['email'] ?? '');

    // Pre-fill existing data if available
    _userType = user['user_type'];
    _departmentCtrl.text = user['department'] ?? '';
    _classCtrl.text = user['class_name'] ?? '';
    _rollNoCtrl.text = user['roll_number'] ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _departmentCtrl.dispose();
    _classCtrl.dispose();
    _rollNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select your role (Student or Teacher)'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final resp = await ApiService().updateProfile(
        userType: _userType!,
        department: _userType == 'teacher' ? _departmentCtrl.text.trim() : null,
        className: _userType == 'student' ? _classCtrl.text.trim() : null,
        rollNumber: _userType == 'student' ? _rollNoCtrl.text.trim() : null,
      );

      if (mounted) {
        if (resp['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ));
          Navigator.pop(context, true); // Return true to signal update
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(resp['message'] ?? 'Failed to update profile'),
            backgroundColor: AppColors.error,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Name (Read-only)
                    _buildTextField(
                      controller: _nameCtrl,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    // Email (Read-only)
                    _buildTextField(
                      controller: _emailCtrl,
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      readOnly: true,
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Academic Information',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Role Dropdown
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _userType,
                          hint: const Text('Select Role'),
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: const [
                            DropdownMenuItem(value: 'student', child: Text('Student')),
                            DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _userType = val;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dynamic Fields based on Role
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _userType == 'teacher'
                          ? _buildTextField(
                              controller: _departmentCtrl,
                              label: 'Department',
                              icon: Icons.business_center_outlined,
                              validator: (v) => v!.isEmpty ? 'Enter your department' : null,
                            )
                          : _userType == 'student'
                              ? Column(
                                  key: const ValueKey('student_fields'),
                                  children: [
                                    _buildTextField(
                                      controller: _classCtrl,
                                      label: 'Class / Course',
                                      icon: Icons.school_outlined,
                                      validator: (v) => v!.isEmpty ? 'Enter your class' : null,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTextField(
                                      controller: _rollNoCtrl,
                                      label: 'Roll Number',
                                      icon: Icons.badge_outlined,
                                      validator: (v) => v!.isEmpty ? 'Enter your roll number' : null,
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      validator: validator,
      style: TextStyle(
        color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textHint, size: 20),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF9FAFB) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
