// lib/features/notes/presentation/screens/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drivenotes/features/notes/presentation/providers/theme_provider.dart';

class ProfilePage extends ConsumerWidget {
  final GoogleSignInAccount? user;

  const ProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);

    // If user is null, show error state
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('Session expired', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Please sign in again', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          // Profile Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Hero(
                  tag: 'profile_image',
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage:
                        user?.photoUrl != null
                            ? NetworkImage(user!.photoUrl!)
                            : null,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child:
                        user?.photoUrl == null
                            ? Text(
                              user?.displayName?.characters.first
                                      .toUpperCase() ??
                                  'U',
                              style: theme.textTheme.headlineMedium,
                            )
                            : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.displayName ?? 'User',
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  user?.email ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Theme Settings
          ListTile(
            leading: Icon(
              themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
            ),
            title: const Text('Theme'),
            subtitle: Text(
              themeMode == ThemeMode.dark ? 'Dark Mode' : 'Light Mode',
            ),
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (value) {
                ref
                    .read(themeProvider.notifier)
                    .setTheme(value ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ),

          // Drive Folder
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Google Drive Folder'),
            subtitle: const Text('Open notes folder in browser'),
            onTap: () async {
              const url = 'https://drive.google.com';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
            },
          ),

          // App Info
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About DriveNotes'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'DriveNotes',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.note_alt_outlined, size: 48),
                children: [
                  const Text(
                    'DriveNotes is a simple note-taking app that syncs with Google Drive.',
                  ),
                ],
              );
            },
          ),

          // Sign Out
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            subtitle: const Text('Log out of your account'),
            onTap: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('SIGN OUT'),
                        ),
                      ],
                    ),
              );

              if (shouldLogout == true && context.mounted) {
                await GoogleSignIn().signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
