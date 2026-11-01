import 'package:flutter/material.dart';

import '../../shared/widgets/app_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.onRegister,
    required this.onShowLogin,
  });

  final ValueChanged<String> onRegister;
  final VoidCallback onShowLogin;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: AppPanel(
                padding: 24,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'lib/assets/images/cams_gold.jpeg',
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Créer un compte',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 22),
                      const FieldLabel('Nom complet'),
                      TextFormField(
                        controller: _name,
                        decoration: fieldDecoration('Votre nom'),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                            ? 'Saisissez votre nom.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      const FieldLabel('E-mail'),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: fieldDecoration('nom@exemple.com'),
                        validator: (value) {
                          if (value == null ||
                              !RegExp(
                                r'^[^@]+@[^@]+\.[^@]+$',
                              ).hasMatch(value)) {
                            return 'Saisissez une adresse e-mail valide.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const FieldLabel('Mot de passe'),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: fieldDecoration('6 caractères minimum'),
                        validator: (value) => value == null || value.length < 6
                            ? '6 caractères minimum.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      const FieldLabel('Confirmer le mot de passe'),
                      TextFormField(
                        controller: _confirmation,
                        obscureText: true,
                        decoration: fieldDecoration('Répétez le mot de passe'),
                        validator: (value) => value != _password.text
                            ? 'Les mots de passe ne correspondent pas.'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Créer mon compte',
                        onPressed: _submit,
                      ),
                      TextButton(
                        onPressed: widget.onShowLogin,
                        child: const Text('Retour à la connexion'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onRegister(_name.text.trim());
  }
}
