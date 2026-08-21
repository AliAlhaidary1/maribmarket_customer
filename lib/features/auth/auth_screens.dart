import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../core/app_theme.dart';
import '../../core/config.dart';
import '../../widgets/ui_helpers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final mobile = TextEditingController();
  final password = TextEditingController();
  final otp = TextEditingController();
  final newPassword = TextEditingController();
  final confirm = TextEditingController();
  String view = 'login';
  String? error;
  bool busy = false;

  @override
  void dispose() {
    mobile.dispose();
    password.dispose();
    otp.dispose();
    newPassword.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    return Scaffold(
      appBar: AppBar(title: Text(app.t('login'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Image.asset(
            'assets/brand/saree.png',
            height: 88,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/brand/saree.png',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.shopping_cart_rounded,
                size: 64,
                color: app.accentColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppTheme.brandNameAr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            AppTheme.brandNameEn,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.accentOrange,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: mobile,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: app.t('enter_mobile'),
              prefixText: '+${AppConfig.countryDialCode} ',
            ),
          ),
          if (view == 'login') ...[
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(labelText: app.t('enter_password')),
            ),
          ],
          if (view == 'forgot')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(app.t('reset_password_via_whatsapp_otp')),
            ),
          if (view == 'forgot_reset') ...[
            const SizedBox(height: 12),
            TextField(
              controller: otp,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: app.t('enter_otp')),
            ),
            TextField(
              controller: newPassword,
              obscureText: true,
              decoration: InputDecoration(labelText: app.t('new_password')),
            ),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: InputDecoration(
                labelText: app.t('confirm_new_password'),
              ),
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : _submit,
            child: busy ? const BusySpinner() : Text(_buttonLabel()),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                view = view == 'login' ? 'forgot' : 'login';
                error = null;
              });
            },
            child: Text(
              view == 'login' ? app.t('forgot_password') : app.t('login'),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/register'),
            child: Text(app.t('register')),
          ),
        ],
      ),
    );
  }

  String _buttonLabel() {
    if (view == 'forgot') return appController.t('apply');
    if (view == 'forgot_reset') return appController.t('update');
    return appController.t('login');
  }

  Future<void> _submit() async {
    final app = appController;
    if (view == 'login' &&
        (mobile.text.trim().isEmpty || password.text.isEmpty)) {
      setState(() => error = app.t('fill_required_fields'));
      return;
    }
    if (view != 'login' && mobile.text.trim().isEmpty) {
      setState(() => error = app.t('enter_mobile'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (view == 'login') {
        final message = await app.login(
          mobile: mobile.text.trim(),
          password: password.text,
        );
        if (!mounted) return;
        if (message != null) {
          setState(() => error = message);
        } else {
          context.go('/');
        }
      } else if (view == 'forgot') {
        final result = await app.api.forgotPasswordOtp(
          mobile: mobile.text.trim(),
        );
        if (!mounted) return;
        if (!result.ok) {
          setState(() => error = result.message);
        } else {
          setState(() {
            view = 'forgot_reset';
            error = app.t('forgot_otp_sent');
          });
        }
      } else {
        if (otp.text.trim().isEmpty ||
            newPassword.text.length < 6 ||
            newPassword.text != confirm.text) {
          setState(() => error = app.t('enter_confirm_password'));
        } else {
          final result = await app.api.resetPasswordOtp(
            mobile: mobile.text.trim(),
            otp: otp.text.trim(),
            password: newPassword.text,
            passwordConfirmation: confirm.text,
          );
          if (!mounted) return;
          if (!result.ok) {
            setState(() => error = result.message);
          } else {
            setState(() {
              view = 'login';
              error = app.t('password_reset_ok');
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = app.t('network_error'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final mobile = TextEditingController();
  final password = TextEditingController();
  String? error;
  bool busy = false;
  bool acceptedTerms = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    mobile.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    return Scaffold(
      appBar: AppBar(title: Text(app.t('register'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: name,
            decoration: InputDecoration(labelText: app.t('Name')),
          ),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: app.t('enter_email')),
          ),
          TextField(
            controller: mobile,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: app.t('enter_mobile'),
              prefixText: '+${AppConfig.countryDialCode} ',
            ),
          ),
          TextField(
            controller: password,
            obscureText: true,
            decoration: InputDecoration(labelText: app.t('enter_password')),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: acceptedTerms,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) => setState(() => acceptedTerms = v ?? false),
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(app.t('i_agree_to')),
                TextButton(
                  onPressed: () => context.push('/terms'),
                  child: Text(app.t('terms_of_service')),
                ),
                Text(app.t('and')),
                TextButton(
                  onPressed: () => context.push('/privacy'),
                  child: Text(app.t('privacy_policy')),
                ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : _register,
            child: busy ? const BusySpinner() : Text(app.t('register')),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    final app = appController;
    if (name.text.trim().isEmpty ||
        mobile.text.trim().isEmpty ||
        password.text.length < 6) {
      setState(() => error = app.t('fill_required_fields'));
      return;
    }
    if (!acceptedTerms) {
      setState(() => error = app.t('accept_terms_required'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final message = await app.registerCustomer(
        name: name.text.trim(),
        mobile: mobile.text.trim(),
        password: password.text,
        email: email.text.trim(),
      );
      if (!mounted) return;
      if (message != null) {
        setState(() => error = message);
      } else {
        context.go('/addresses');
      }
    } catch (_) {
      if (mounted) setState(() => error = app.t('network_error'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
