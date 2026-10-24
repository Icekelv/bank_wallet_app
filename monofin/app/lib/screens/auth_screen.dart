import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state.dart';
import '../theme.dart';

/// Sign in / create account. Looks like whichever app the admin has switched on.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = context.read<AppState>();
    try {
      if (_register) {
        await s.register(_name.text.trim(), _email.text.trim(), _phone.text.trim(), _password.text);
      } else {
        await s.login(_email.text.trim(), _password.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = Palette.of(context);
    final canRegister = s.config.signupEnabled;
    final register = _register && canRegister;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(16)),
                        child: Icon(s.isWallet ? Icons.show_chart_rounded : Icons.account_balance_rounded, color: p.bg),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      register ? 'Create your account' : 'Welcome back',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      register ? 'It takes less than a minute.' : 'Sign in to ${s.config.appName}.',
                      style: TextStyle(color: p.muted, fontSize: 15),
                    ),
                    const SizedBox(height: 28),
                    if (register) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(labelText: 'Full name'),
                        validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your full name' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email',
                    ),
                    const SizedBox(height: 12),
                    if (register) ...[
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(labelText: 'Phone (optional)'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      autofillHints: [register ? AutofillHints.newPassword : AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _hidePassword ? 'Show password' : 'Hide password',
                          icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      validator: (v) => (v ?? '').length < 6 ? 'At least 6 characters' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: p.downBg, borderRadius: BorderRadius.circular(14)),
                        child: Text(_error!, style: TextStyle(color: p.down)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: p.muted))
                          : Text(register ? 'Create account' : 'Sign in'),
                    ),
                    if (canRegister) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: _busy ? null : () => setState(() {
                          _register = !_register;
                          _error = null;
                        }),
                        child: Text(register ? 'I already have an account' : 'Create an account'),
                      ),
                    ],
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
