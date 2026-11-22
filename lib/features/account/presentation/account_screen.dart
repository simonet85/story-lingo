import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../domain/auth_session.dart';
import 'auth_provider.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _createAccount = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final mode = ref.watch(authModeProvider);
    final api = ref.watch(authApiProvider);
    final configProblem = mode == AuthMode.dev && !api.devEnabled
        ? 'Renseignez API_BASE_URL au lancement pour utiliser le mode dev.'
        : null;
    final busy = auth.isBusy;

    return Scaffold(
      appBar: AppBar(title: const Text('Compte')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              mode == AuthMode.dev
                  ? 'Mode développement'
                  : 'Se connecter à Storylingo',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              mode == AuthMode.dev
                  ? 'L’API locale délivre un jeton de test. Aucun mot de '
                        'passe n’est demandé et aucune donnée personnelle '
                        'n’est stockée sur le serveur.'
                  : 'Connectez-vous pour retrouver votre progression, vos '
                        'mots et vos révisions sur tous vos appareils.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (configProblem != null) ...[
              Text(
                configProblem,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextFormField(
              controller: _emailController,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: _validateEmail,
            ),
            if (mode == AuthMode.supabase) ...[
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Se connecter')),
                  ButtonSegment(value: true, label: Text('Créer un compte')),
                ],
                selected: {_createAccount},
                showSelectedIcon: false,
                onSelectionChanged: busy
                    ? null
                    : (selection) =>
                          setState(() => _createAccount = selection.first),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _passwordController,
                enabled: !busy,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return '6 caractères minimum.';
                  }
                  return null;
                },
              ),
            ],
            if (auth.error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                auth.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy || configProblem != null ? null : _submit,
                child: busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        mode == AuthMode.supabase && _createAccount
                            ? 'Créer mon compte'
                            : 'Se connecter',
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Vos jetons sont conservés dans le stockage sécurisé de '
              'l’appareil. La déconnexion conserve vos données locales.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Adresse email invalide.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    final controller = ref.read(authControllerProvider.notifier);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final mode = ref.read(authModeProvider);

    if (mode == AuthMode.supabase && _createAccount) {
      final outcome = await controller.signUp(
        email: email,
        password: password,
      );
      if (!mounted) return;
      if (outcome.session != null) {
        _closeWith('Compte créé. Synchronisation en cours.');
      } else if (outcome.message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(outcome.message!)));
      }
      return;
    }

    final signedIn = await controller.signIn(
      email: email,
      password: password,
    );
    if (!mounted) return;
    if (signedIn) {
      _closeWith('Connexion réussie. Synchronisation en cours.');
    }
  }

  void _closeWith(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop();
  }
}
