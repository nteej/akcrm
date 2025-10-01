import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_snack_bar.dart';
import '../../widgets/custom_textformfield.dart';
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<Auth>(context, listen: false).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updateProfile() {
    if (_formKey.currentState!.validate()) {
      // Call your update profile API here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated!')),
      );
    }
  }

  void _resetPassword() {
    if (_passwordController.text == _confirmPasswordController.text && _passwordController.text.isNotEmpty) {
      // Call your reset password API here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile'),backgroundColor: Colors.yellow[300]),
      backgroundColor: Colors.yellow[200],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: CustomTextFormField(
                    email: _nameController,
                    label: 'Name',
                    hint: 'Enter your name',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: CustomTextFormField(
                    email: _emailController,
                    label: 'Email',
                    hint: 'Enter your email',
                  ),
                ),
                // Registered date and employment details row
                Builder(
                  builder: (context) {
                    final user = Provider.of<Auth>(context).user;
                    String registeredDate = user?.registeredDate ?? '';
                    String employmentDetails = user?.employmentDetails ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          if (registeredDate.isNotEmpty)
                            Text('Registered: $registeredDate', style: TextStyle(color: Colors.grey[700])),
                          if (employmentDetails.isNotEmpty) ...[
                            SizedBox(width: 16),
                            Text('Employment: $employmentDetails', style: TextStyle(color: Colors.grey[700])),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              SizedBox(height: 20),
              CustomButton(
                onTap: _updateProfile,
                title: 'Update Profile',
              ),
              Divider(height: 40),
              Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0, top: 12.0),
                  child: CustomTextFormField(
                    email: _passwordController,
                    label: 'Password',
                    hint: 'Enter new password',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: CustomTextFormField(
                    email: _confirmPasswordController,
                    label: 'Password',
                    hint: 'Confirm new password',
                  ),
                ),
              SizedBox(height: 20),
              CustomButton(
                onTap: _resetPassword,
                title: 'Reset Password',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
