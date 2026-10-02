import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'auth_controller.dart';
import 'fade_slide_in.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  bool isPasswordHidden = true;
  bool isConfirmPasswordHidden = true;

  bool isLoading = false;

  final AuthController authController = Get.find<AuthController>();

  // =========================
  // NAME VALIDATION
  // =========================
  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }

    if (value.trim().length < 5) {
      return 'Name must be at least 5 characters';
    }

    if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value.trim())) {
      return 'Name can only contain letters and spaces';
    }

    return null;
  }

  // =========================
  // EMAIL VALIDATION
  // =========================
  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }

    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$')
        .hasMatch(value.trim())) {
      return 'Please enter a valid Gmail address';
    }

    return null;
  }

  // =========================
  // PASSWORD VALIDATION
  // =========================
  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain an uppercase letter';
    }

    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain a lowercase letter';
    }

    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain a number';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain a special character';
    }

    return null;
  }

  // =========================
  // CONFIRM PASSWORD
  // =========================
  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  // =========================
  // SIGN UP
  // =========================
  Future<void> createAccount() async {
    // Check validation
    if (!formKey.currentState!.validate()) {
      return;
    }

    // Start loading
    setState(() {
      isLoading = true;
    });

    // Close keyboard when creating account
    FocusScope.of(context).unfocus();

    // Wait for 3 seconds
    await Future.delayed(
      const Duration(seconds: 3),
    );

    // Save account details
    authController.signUp(
      nameController.text.trim(),
      emailController.text.trim(),
      passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    // =========================
    // GO BACK TO LOGIN
    // =========================
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,

      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (isLoading) return;

        Get.back();
      },

      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Create Account',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        // =========================
        // CLOSE KEYBOARD ON TAP
        // =========================
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,

          onTap: () {
            FocusScope.of(context).unfocus();
          },

          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Form(
              key: formKey,

              child: Column(
                children: [
                  const SizedBox(height: 25),

                  // =========================
                  // TITLE
                  // =========================
                  FadeSlideIn(
                    child: Text(
                      'Create Your Account',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Enter your details to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // =========================
                  // NAME
                  // =========================
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 60),
                    child: TextFormField(
                      controller: nameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      validator: validateName,

                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // =========================
                  // EMAIL
                  // =========================
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 120),
                    child: TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: validateEmail,

                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'example@gmail.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // =========================
                  // PASSWORD
                  // =========================
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 180),
                    child: TextFormField(
                      controller: passwordController,
                      obscureText: isPasswordHidden,
                      validator: validatePassword,

                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),

                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordHidden
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),

                          onPressed: () {
                            setState(() {
                              isPasswordHidden =
                              !isPasswordHidden;
                            });
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // =========================
                  // CONFIRM PASSWORD
                  // =========================
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 240),
                    child: TextFormField(
                      controller: confirmPasswordController,
                      obscureText: isConfirmPasswordHidden,
                      validator: validateConfirmPassword,

                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Re-enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),

                        suffixIcon: IconButton(
                          icon: Icon(
                            isConfirmPasswordHidden
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),

                          onPressed: () {
                            setState(() {
                              isConfirmPasswordHidden =
                              !isConfirmPasswordHidden;
                            });
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // =========================
                  // CREATE ACCOUNT BUTTON
                  // =========================
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 300),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,

                      child: ElevatedButton(
                        onPressed:
                        isLoading ? null : createAccount,

                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isLoading
                              ? const SizedBox(
                            key: ValueKey('loading'),
                            height: 24,
                            width: 24,

                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                              : const Text(
                            'Create Account',
                            key: ValueKey('label'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // =========================
                  // LOGIN BUTTON
                  // =========================
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 340),
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                        Get.back();
                      },

                      child: const Text(
                        'Already have an account? Login',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}