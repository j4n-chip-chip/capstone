import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  bool obscurePassword = true;
  bool rememberMe = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadRememberedEmail();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();

    final savedRememberMe = prefs.getBool('remember_me') ?? false;
    final savedEmail = prefs.getString('saved_email') ?? '';

    if (!mounted) return;

    setState(() {
      rememberMe = savedRememberMe;
      emailController.text = savedEmail;
    });
  }

  Future<void> handleLogin() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      await firebaseAuthService.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('remember_me', rememberMe);

      if (rememberMe) {
        await prefs.setString('saved_email', emailController.text.trim());
      } else {
        await prefs.remove('saved_email');
      }

      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login successful'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      String message = 'Login failed';

      switch (e.code) {
        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;

        case 'invalid-email':
          message = 'Invalid email address.';
          break;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.danger),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to sign in right now. Check your internet connection and try again.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController();
    bool isSending = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSending,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> sendReset() async {
              final email = resetEmailController.text.trim();

              final emailError = validateEmail(email);
              if (emailError != null) {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(emailError),
                    backgroundColor: AppColors.danger,
                  ),
                );
                return;
              }

              setDialogState(() => isSending = true);

              try {
                await firebaseAuthService.resetPassword(email: email);

                if (!mounted) return;

                FocusManager.instance.primaryFocus?.unfocus();

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'If an account exists for this email, password reset instructions have been sent.',
                    ),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;

                if (dialogContext.mounted) {
                  setDialogState(() => isSending = false);
                }

                String message =
                    'If an account exists for this email, password reset instructions will be sent.';

                switch (e.code) {
                  case 'invalid-email':
                    message = 'Invalid email address.';
                    break;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: AppColors.danger,
                  ),
                );
              } catch (_) {
                if (!mounted) return;

                if (dialogContext.mounted) {
                  setDialogState(() => isSending = false);
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Something went wrong. Please try again.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                decoration: const BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.lock_reset_rounded,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Reset Your Password',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter the email address associated with your BananaDoctor account.',
                      style: TextStyle(
                        color: AppColors.textDark,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'If an account is registered with that address, we will send a secure password reset link.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: resetEmailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!isSending) {
                          sendReset();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Registered email',
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.primaryGreen,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed:
                  isSending ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSending ? null : sendReset,
                  icon: isSending
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    isSending ? 'Sending...' : 'Send Reset Link',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    resetEmailController.dispose();
  }

  Future<void> showCreateAccountDialog() async {
    final createNameController = TextEditingController();
    final createEmailController = TextEditingController();
    final createPasswordController = TextEditingController();

    bool isCreating = false;
    bool obscureNewPassword = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isCreating,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> createAccount() async {
              final name = createNameController.text.trim();
              final email = createEmailController.text.trim();
              final password = createPasswordController.text;

              void showError(String message) {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }

              if (name.isEmpty) {
                showError('Full name is required.');
                return;
              }

              final emailError = validateEmail(email);
              if (emailError != null) {
                showError(emailError);
                return;
              }

              final passwordError = validatePassword(password);
              if (passwordError != null) {
                showError(passwordError);
                return;
              }

              setDialogState(() => isCreating = true);

              try {
                await firebaseAuthService.register(
                  name: name,
                  email: email,
                  password: password,
                );

                if (!mounted) return;

                FocusManager.instance.primaryFocus?.unfocus();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account created successfully.'),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;

                if (dialogContext.mounted) {
                  setDialogState(() => isCreating = false);
                }

                String message = 'Registration failed';

                switch (e.code) {
                  case 'email-already-in-use':
                    message = 'This email is already registered.';
                    break;
                  case 'invalid-email':
                    message = 'Invalid email address.';
                    break;
                  case 'weak-password':
                    message = 'Password is too weak.';
                    break;
                }

                showError(message);
              } catch (_) {
                if (!mounted) return;

                if (dialogContext.mounted) {
                  setDialogState(() => isCreating = false);
                }

                showError(
                  'Unable to create the account right now. Check your internet connection and try again.',
                );
              }
            }

            return AlertDialog(
              title: const Text('Create Farmer Account'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: createNameController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'Full name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: createEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'Email address',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: createPasswordController,
                      obscureText: obscureNewPassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNewPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isCreating ? null : createAccount,
                  child: isCreating
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Account'),
                ),
              ],
            );
          },
        );
      },
    );

    createNameController.dispose();
    createEmailController.dispose();
    createPasswordController.dispose();
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    if (!value.contains('@') || !value.contains('.')) {
      return 'Enter a valid email address';
    }

    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.darkGreen,
                  AppColors.primaryGreen,
                ],
              ),
            ),
          ),

          // Decorative background circles
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              height: 240,
              width: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),

          Positioned(
            top: 100,
            left: -100,
            child: Container(
              height: 220,
              width: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          Positioned(
            bottom: -120,
            right: -80,
            child: Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // Logo
                    Container(
                      height: 92,
                      width: 92,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/icon/bananadoctor_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Smart Crop Protection',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Login card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),

                          const SizedBox(height: 6),

                          const Text(
                            'Sign in to monitor your farm and BananaDoctor device.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.textLight,
                            ),
                          ),

                          const SizedBox(height: 24),

                          TextFormField(
                            controller: emailController,
                            validator: validateEmail,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Email address',
                              hintText: 'farmer@example.com',
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: AppColors.primaryGreen,
                              ),
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.primaryGreen,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          TextFormField(
                            controller: passwordController,
                            validator: validatePassword,
                            obscureText: obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!isLoading) {
                                handleLogin();
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: AppColors.primaryGreen,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.primaryGreen,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              SizedBox(
                                height: 38,
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: rememberMe,
                                      activeColor: AppColors.primaryGreen,
                                      visualDensity: VisualDensity.compact,
                                      onChanged: isLoading
                                          ? null
                                          : (value) {
                                        setState(() {
                                          rememberMe = value ?? false;
                                        });
                                      },
                                    ),
                                    const Text(
                                      'Remember me',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const Spacer(),

                              TextButton(
                                onPressed:
                                isLoading ? null : showForgotPasswordDialog,
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color:
                                  AppColors.textLight.withValues(alpha: 0.25),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'NEW FARMER?',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color:
                                  AppColors.textLight.withValues(alpha: 0.25),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                              isLoading ? null : showCreateAccountDialog,
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              label: const Text('Create Farmer Account'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                                side: const BorderSide(
                                  color: AppColors.primaryGreen,
                                ),
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Black Sigatoka Monitoring & Smart Spraying',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'BananaDoctor • Farmer System',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
