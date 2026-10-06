import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.auth});
  final AuthController auth;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController();
  bool busy = false;
  bool sent = false;
  String? message;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final value = email.text.trim();
    if (!value.contains('@')) {
      setState(() => message = 'Introdu o adresă de email validă.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.auth.requestPasswordReset(value);
      if (mounted) {
        setState(() {
          sent = true;
          message = 'Dacă există un cont pentru acest email, am trimis instrucțiunile de resetare.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => message = AuthController.message(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperare parolă')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ai uitat parola?',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Introdu emailul contului tău și îți trimitem un link pentru a alege o parolă nouă.',
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      key: const ValueKey('recovery-email'),
                      controller: email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.send,
                      autofillHints: const [AutofillHints.email],
                      onSubmitted: (_) => submit(),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('recovery-submit'),
                      onPressed: busy ? null : submit,
                      child: Text(
                        busy
                            ? 'Se trimite…'
                            : sent
                            ? 'Trimite din nou'
                            : 'Trimite instrucțiuni',
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 20),
                      Semantics(
                        liveRegion: true,
                        child: sent
                            ? DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xffe8efdc),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.mark_email_read_outlined,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              message!,
                                              style: theme.textTheme.titleSmall,
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              'Deschide linkul în același browser și verifică și folderul Spam.',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Text(
                                message!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.auth});
  final AuthController auth;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (password.text.length < 8 || password.text != confirmation.text) {
      setState(
        () => error = password.text.length < 8
            ? 'Parola trebuie să aibă cel puțin 8 caractere.'
            : 'Parolele nu coincid.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.auth.updatePassword(password.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parola a fost actualizată.')),
        );
      }
    } catch (value) {
      if (mounted) setState(() => error = AuthController.message(value));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Alege o parolă nouă'),
      automaticallyImplyLeading: false,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            key: const ValueKey('new-password'),
            controller: password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Parolă nouă'),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('confirm-password'),
            controller: confirmation,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirmă parola'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('password-submit'),
            onPressed: busy ? null : submit,
            child: Text(busy ? 'Se actualizează…' : 'Actualizează parola'),
          ),
          TextButton(
            onPressed: busy ? null : widget.auth.cancelRecovery,
            child: const Text('Anulează'),
          ),
          if (error != null) Semantics(liveRegion: true, child: Text(error!)),
        ],
      ),
    ),
  );
}
