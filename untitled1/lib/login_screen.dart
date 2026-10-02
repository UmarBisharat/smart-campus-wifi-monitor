import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'auth_controller.dart';
import 'signup_screen.dart';
import 'exit_app_helper.dart';
import 'fade_slide_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isPasswordHidden = true;

  // Loading variable
  bool isLoading = false;

  final AuthController authController = Get.find<AuthController>();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  // =========================
  // LOGIN FUNCTION
  // =========================
  Future<void> handleLogin() async {
    // Validate fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Close keyboard when login button is pressed
    FocusScope.of(context).unfocus();

    // Start loading
    setState(() {
      isLoading = true;
    });

    // Wait for 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    // Login
    await authController.login(
      emailController.text.trim(),
      passwordController.text,
    );

    // Stop loading
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,

      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Don't allow back while loading
        if (isLoading) return;

        await ExitAppHelper.handleBackPress(context);
      },

      child: Scaffold(
        // =========================
        // APP BAR
        // (colors come from AppBarTheme — follows the current theme)
        // =========================
        appBar: AppBar(
          title: const Text(
            'Login',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        // =========================
        // BODY
        // =========================
        body: GestureDetector(
          // This makes the entire area detect taps
          behavior: HitTestBehavior.opaque,

          // Close keyboard when tapping anywhere
          // outside the text fields
          onTap: () {
            FocusScope.of(context).unfocus();
          },

          child: Padding(
            padding: const EdgeInsets.all(16),

            child: Form(
              key: _formKey,

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  // =========================
                  // EMAIL
                  // =========================
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 0),
                    child: TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,

                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }

                        return null;
                      },

                      // fill color, border, icon color all come
                      // from InputDecorationTheme in main.dart
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // =========================
                  // PASSWORD
                  // =========================
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: TextFormField(
                      controller: passwordController,
                      obscureText: isPasswordHidden,

                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your password';
                        }

                        return null;
                      },

                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),

                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordHidden
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),

                          onPressed: () {
                            setState(() {
                              isPasswordHidden = !isPasswordHidden;
                            });
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =========================
                  // LOGIN BUTTON
                  // (style comes from ElevatedButtonTheme)
                  // =========================
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 160),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,

                      child: ElevatedButton(
                        // Disable while loading
                        onPressed: isLoading ? null : handleLogin,

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
                            'Login',
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

                  const SizedBox(height: 10),

                  // =========================
                  // SIGN UP BUTTON
                  // (color comes from TextButtonTheme)
                  // =========================
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 240),
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                        // Close keyboard before
                        // opening Sign Up screen
                        FocusScope.of(context).unfocus();

                        Get.to(() => const SignUpScreen());
                      },

                      child: const Text(
                        "Don't have an account? Sign Up",
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}