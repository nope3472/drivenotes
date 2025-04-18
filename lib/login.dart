import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showFeatures = false;
  final _storage = const FlutterSecureStorage();
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      GoRouter.of(context).go('/notes');
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Login failed');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser =
          await GoogleSignIn(
            scopes: [
              'https://www.googleapis.com/auth/drive.readonly',
              'https://www.googleapis.com/auth/drive.file',
            ],
          ).signIn();

      if (googleUser == null) {
        _showMessage('Sign in cancelled');
        return;
      }

      final auth = await googleUser.authentication;
      await _storage.write(key: 'access_token', value: auth.accessToken);
      await _storage.write(key: 'refresh_token', value: auth.idToken);
      await _storage.write(
        key: 'token_expiry',
        value:
            DateTime.now()
                .add(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
      );

      if (mounted) context.go('/notes');
    } catch (e) {
      _showMessage('Error signing in: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _toggleFeatures() {
    setState(() => _showFeatures = !_showFeatures);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo and Title
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          Icon(
                            Icons.note_alt_outlined,
                            size: 80,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 24),
                          DefaultTextStyle(
                            style: theme.textTheme.headlineMedium!.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                            child: AnimatedTextKit(
                              animatedTexts: [
                                TypewriterAnimatedText(
                                  'DriveNotes',
                                  speed: const Duration(milliseconds: 100),
                                ),
                              ],
                              isRepeatingAnimation: false,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your notes, everywhere.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Sign in form
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Card(
                          elevation: 8,
                          shadowColor: Colors.black26,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Welcome to DriveNotes',
                                  style: theme.textTheme.headlineSmall,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Sign in with your Google account to sync your notes with Google Drive.',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                OutlinedButton.icon(
                                  icon: Image.asset(
                                    'lib/assets/google_logo.png',
                                    height: 24,
                                  ),
                                  label: const Text('Sign in with Google'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed:
                                      _isLoading ? null : _signInWithGoogle,
                                ),
                                if (_isLoading)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Feature showcase
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: TextButton.icon(
                      icon: AnimatedRotation(
                        duration: const Duration(milliseconds: 300),
                        turns: _showFeatures ? 0.5 : 0,
                        child: const Icon(Icons.expand_more),
                      ),
                      label: const Text('Keep your notes in one place'),
                      onPressed: _toggleFeatures,
                    ),
                  ),
                  if (_showFeatures)
                    const AnimatedSize(
                      duration: Duration(milliseconds: 300),
                      child: Card(
                        margin: EdgeInsets.only(top: 16),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              ListTile(
                                leading: Icon(Icons.cloud_sync),
                                title: Text('Sync with Google Drive'),
                                subtitle: Text(
                                  'Access your notes from any device',
                                ),
                              ),
                              ListTile(
                                leading: Icon(Icons.edit_note),
                                title: Text('Rich Text Editor'),
                                subtitle: Text(
                                  'Create and edit notes easily',
                                ),
                              ),
                              ListTile(
                                leading: Icon(Icons.security),
                                title: Text('Secure Storage'),
                                subtitle: Text(
                                  'Your notes are safe and private',
                                ),
                              ),
                            ],
                          ),
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
