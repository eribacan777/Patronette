import 'package:flutter/material.dart';

import 'session.dart';

/// Conectare sau cont nou în comunitate.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});

  final Session session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _newAccount = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_newAccount) {
        await widget.session
            .register(_email.text.trim(), _password.text, _name.text.trim());
      } else {
        await widget.session.login(_email.text.trim(), _password.text);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_newAccount ? 'Cont nou' : 'Conectare')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ca să postezi, să apreciezi și să comentezi ai nevoie de un '
                      'cont. Măsurile tale rămân doar pe telefon.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    if (_newAccount) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.nickname],
                        maxLength: 40,
                        decoration: const InputDecoration(
                            labelText: 'Numele afișat',
                            helperText: 'Așa te văd celelalte'),
                        validator: (v) => (v ?? '').trim().length < 2
                            ? 'Cel puțin 2 caractere'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      validator: (v) => (v ?? '').contains('@')
                          ? null
                          : 'Scrie o adresă de e-mail',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autofillHints: [
                        _newAccount
                            ? AutofillHints.newPassword
                            : AutofillHints.password
                      ],
                      decoration: InputDecoration(
                        labelText: 'Parolă',
                        helperText:
                            _newAccount ? 'Cel puțin 8 caractere' : null,
                        suffixIcon: IconButton(
                          tooltip:
                              _showPassword ? 'Ascunde parola' : 'Arată parola',
                          icon: Icon(_showPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      validator: (v) => _newAccount && (v ?? '').length < 8
                          ? 'Cel puțin 8 caractere'
                          : (v ?? '').isEmpty
                              ? 'Scrie parola'
                              : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                              _newAccount ? 'Creează contul' : 'Conectează-te'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _newAccount = !_newAccount;
                                _error = null;
                              }),
                      child: Text(_newAccount
                          ? 'Am deja cont: mă conectez'
                          : 'Nu am cont: îmi fac unul'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
