import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, FirebaseAuthException;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../firebase/firestore_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _notificationsPrefKey = 'session_notifications_enabled';

  bool _isLoadingPrefs = true;
  bool _notificationsEnabled = true;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_notificationsPrefKey) ?? true;
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = value;
      _isLoadingPrefs = false;
    });
  }

  Future<void> _toggleNotifications(bool enabled) async {
    final authUser = context.read<app_auth.AuthProvider>().currentUser;
    if (authUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsPrefKey, enabled);

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
    });

    if (!enabled) {
      await FirebaseMessaging.instance.deleteToken();
      await FirestoreService.instance.updateUser(
        authUser.copyWith(fcmToken: ''),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session notifications disabled.')),
      );
      return;
    }

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final token = await FirebaseMessaging.instance.getToken() ?? '';
    await FirestoreService.instance.updateUser(
      authUser.copyWith(fcmToken: token),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          token.isEmpty
              ? 'Notifications enabled, but token is not available yet.'
              : 'Session notifications enabled.',
        ),
      ),
    );
  }

  Future<void> _clearSessionHistory() async {
    final uid = context.read<app_auth.AuthProvider>().currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Session History'),
        content: const Text(
          'This removes you from collaborator lists of joined sessions. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final snapshot = await FirestoreService.instance
        .sessionsRef()
        .where('collaborators', arrayContains: uid)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'collaborators': FieldValue.arrayRemove([uid]),
      });
    }
    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Session history cleared for ${snapshot.docs.length} sessions.',
        ),
      ),
    );
  }

  Future<void> _deleteAccountFlow() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final authUser = FirebaseAuth.instance.currentUser;
    final userModel = authProvider.currentUser;
    if (authUser == null || userModel == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canDelete = controller.text.trim() == 'DELETE';
            return AlertDialog(
              title: const Text('Delete Account'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This permanently deletes your account and profile. Type DELETE to confirm.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(labelText: 'Type DELETE'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: canDelete
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: const Text('Delete Account'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() {
      _isDeletingAccount = true;
    });

    try {
      await FirestoreService.instance.userDoc(userModel.uid).delete();
      await authUser.delete();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'requires-recent-login') {
        await _showReAuthRequiredDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to delete account: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete account: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }

  Future<void> _showReAuthRequiredDialog() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final shouldRelogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Re-authentication Required'),
        content: const Text(
          'For security, Firebase requires a recent sign-in before deleting your account. Sign in again, then retry deletion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign Out & Re-Login'),
          ),
        ],
      ),
    );

    if (shouldRelogin != true) return;

    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openGithubUrl() async {
    final uri = Uri.parse('https://github.com/goochoi913/vibzcheck');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open GitHub URL.')),
      );
    }
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPrefs) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _sectionHeader('Notification Settings'),
          SwitchListTile(
            title: const Text('Session Notifications'),
            subtitle: const Text(
              'Turn off to prevent this device from receiving FCM updates.',
            ),
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
          ),
          _sectionHeader('Privacy'),
          ListTile(
            leading: const Icon(Icons.history_toggle_off),
            title: const Text('Clear Session History'),
            subtitle: const Text(
              'Remove your UID from prior collaborator lists.',
            ),
            onTap: _clearSessionHistory,
          ),
          _sectionHeader('Account'),
          ListTile(
            leading: _isDeletingAccount
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.redAccent),
            ),
            subtitle: const Text(
              'This permanently removes your Auth account and profile.',
            ),
            onTap: _isDeletingAccount ? null : _deleteAccountFlow,
          ),
          _sectionHeader('App Info'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VibzCheck',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    const Text('Version 1.0.0'),
                    const Text('Course: CSC 4360 Mobile App Dev Studio'),
                    const Text('Team: Goo Choi & Eva Park'),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _openGithubUrl,
                      child: Text(
                        'https://github.com/goochoi913/vibzcheck',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
