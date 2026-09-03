import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_controller.dart';
import '../../core/app_theme.dart';
import '../../core/yemen_phone.dart';
import '../../core/config.dart';
import '../../core/json_util.dart';
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
      body: SafeArea(
        child: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        children: [
          Image.asset(
            'assets/brand/saree-market-logo.png',
            height: 88,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/brand/saree-market-mark.png',
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
    if (!YemenPhone.isValid(mobile.text.trim())) {
      setState(() => error = app.t('invalid_yemeni_mobile_number'));
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
          if (!mounted) return;
          // GoRouter refreshListenable سيعيد البناء؛ نستخدم post-frame لتجنب
          // "deactivated widget / Dirty widget in wrong build scope"
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (GoRouter.of(context).routerDelegate.currentConfiguration.uri.path != '/') {
              context.go('/');
            }
          });
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
  final confirmPassword = TextEditingController();
  final otp = TextEditingController();
  String? error;
  bool busy = false;
  bool acceptedTerms = false;
  bool otpSending = false;
  bool hidePassword = true;
  bool hideConfirm = true;
  String? otpMethod;
  Map<String, dynamic>? cityConfig;

  @override
  void initState() {
    super.initState();
    _loadCityConfig();
  }

  Future<void> _loadCityConfig() async {
    final app = appController;
    final cityId = app.city?['id'];
    if (cityId == null) return;
    final result = await app.api.cityConfig(cityId: int.tryParse('$cityId'));
    if (!mounted || !result.ok) return;
    final data = J.map(result.dataMap['data']);
    final methods = _availableOtpMethods(data);
    setState(() {
      cityConfig = data;
      otpMethod = _defaultOtpMethod(data, methods);
    });
  }

  List<String> _availableOtpMethods(Map<String, dynamic>? config) {
    final otp = config?['otp'];
    if (otp is Map && otp['available_methods'] is List) {
      return (otp['available_methods'] as List).map((item) => '$item').toList();
    }
    return const [];
  }

  String? _defaultOtpMethod(Map<String, dynamic>? config, List<String> methods) {
    if (methods.isEmpty) return null;
    final preferred = J.str((config?['otp'] as Map?)?['preferred_method']);
    if (preferred.isNotEmpty && methods.contains(preferred)) return preferred;
    return methods.first;
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    mobile.dispose();
    password.dispose();
    confirmPassword.dispose();
    otp.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon, {String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryNavy.withValues(alpha: 0.7)),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _sectionHeader(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accentOrange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.accentOrange),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primaryNavy)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = appController;
    final otpMethods = _availableOtpMethods(cityConfig);
    final needOtp = otpMethods.isNotEmpty;
    return Scaffold(
      backgroundColor: AppTheme.surfaceGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(app.t('register'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          children: [
            // Brand header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: AppTheme.primaryNavy.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Image.asset(
                      'assets/brand/saree-market-logo.png',
                      height: 42,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset('assets/brand/saree-market-mark.png', height: 42),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(AppTheme.brandNameAr, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  Text(AppTheme.brandNameEn, style: TextStyle(color: AppTheme.accentOrange, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
                    child: Text('إنشاء حساب جديد', style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  Text('أنشئ حسابك للتسوق ومتابعة طلباتك بسهولة', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Personal info card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppTheme.primaryNavy.withValues(alpha: 0.08))),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(Icons.person_outline_rounded, 'المعلومات الشخصية', 'الاسم ورقم الجوال'),
                    const SizedBox(height: 14),
                    TextField(
                      controller: name,
                      textInputAction: TextInputAction.next,
                      decoration: _dec(app.t('Name') == 'Name' ? 'الاسم الكامل' : app.t('Name'), Icons.badge_outlined, hint: app.t('enter_name')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mobile,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: _dec(app.t('enter_mobile'), Icons.phone_outlined, hint: '777 000 000').copyWith(prefixText: '+${AppConfig.countryDialCode} ', prefixStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _dec(app.t('enter_email'), Icons.mail_outline_rounded, hint: 'example@email.com'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Security card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppTheme.primaryNavy.withValues(alpha: 0.08))),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(Icons.lock_outline_rounded, 'الأمان', 'كلمة المرور • 6 أحرف على الأقل'),
                    const SizedBox(height: 14),
                    TextField(
                      controller: password,
                      obscureText: hidePassword,
                      decoration: _dec(app.t('enter_password'), Icons.lock_outline, hint: '••••••••', suffix: IconButton(
                        onPressed: () => setState(() => hidePassword = !hidePassword),
                        icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppTheme.textSecondary),
                      )),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPassword,
                      obscureText: hideConfirm,
                      decoration: _dec(app.t('enter_confirm_password'), Icons.verified_user_outlined, hint: 'تأكيد كلمة المرور', suffix: IconButton(
                        onPressed: () => setState(() => hideConfirm = !hideConfirm),
                        icon: Icon(hideConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppTheme.textSecondary),
                      )),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(child: Text('استخدم 6 أحرف على الأقل، ويفضل مزيج حروف وأرقام', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (needOtp) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppTheme.primaryNavy.withValues(alpha: 0.08))),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(Icons.verified_outlined, 'التحقق', 'رمز يُرسل إلى جوالك'),
                      const SizedBox(height: 14),
                      if (otpMethods.length > 1)
                        DropdownButtonFormField<String>(
                          value: otpMethod,
                          decoration: _dec(app.t('otp_method'), Icons.sms_outlined),
                          items: otpMethods.map((m) => DropdownMenuItem(value: m, child: Text(m == 'whatsapp' ? app.t('whatsapp_otp') : app.t('sms_otp')))).toList(),
                          onChanged: (v) => setState(() => otpMethod = v),
                        ),
                      if (otpMethods.length > 1) const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: otp,
                              keyboardType: TextInputType.number,
                              decoration: _dec(app.t('enter_otp'), Icons.pin_outlined, hint: '123456'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryNavy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: otpSending || busy ? null : _sendOtp,
                              child: otpSending
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.send_rounded, size: 16), const SizedBox(width: 6), Text(app.t('send_otp'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('سيصلك الرمز عبر ${otpMethod == 'whatsapp' ? 'واتساب' : 'الرسائل'} خلال ثوانٍ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Terms
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryNavy.withValues(alpha: 0.08))),
              child: CheckboxListTile(
                value: acceptedTerms,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppTheme.accentOrange,
                onChanged: (v) => setState(() => acceptedTerms = v ?? false),
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(app.t('i_agree_to') + ' ', style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                    InkWell(onTap: () => context.push('/terms'), child: Text(app.t('terms_of_service'), style: const TextStyle(fontSize: 13, color: AppTheme.accentOrange, fontWeight: FontWeight.w600, decoration: TextDecoration.underline))),
                    Text(' ${app.t('and')} ', style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                    InkWell(onTap: () => context.push('/privacy'), child: Text(app.t('privacy_policy'), style: const TextStyle(fontSize: 13, color: AppTheme.accentOrange, fontWeight: FontWeight.w600, decoration: TextDecoration.underline))),
                  ],
                ),
                subtitle: Text('بإنشائك الحساب توافق على الشروط وسياسة الخصوصية', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ),
            ),
            if (error != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFCDD2))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFC62828)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(error!, style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 13, height: 1.4))),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.accentOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: busy ? null : _register,
                child: busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.person_add_alt_1_rounded, size: 20), const SizedBox(width: 8), Text(app.t('register'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))]),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(app.t('already_have_account') == 'already_have_account' ? 'لديك حساب؟' : app.t('already_have_account'), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                TextButton(onPressed: () => context.go('/login'), child: Text(app.t('login'), style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryNavy))),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _sendOtp() async {
    final app = appController;
    if (mobile.text.trim().isEmpty) {
      setState(() => error = app.t('enter_mobile'));
      return;
    }
    setState(() {
      otpSending = true;
      error = null;
    });
    try {
      final cityId = int.tryParse('${app.city?['id']}');
      final result = await app.api.sendSms(
        mobile.text.trim(),
        cityId: cityId,
        channel: otpMethod,
        purpose: 'register',
      );
      if (!mounted) return;
      if (!result.ok) {
        setState(() => error = result.message);
      }
    } catch (_) {
      if (mounted) setState(() => error = app.t('network_error'));
    } finally {
      if (mounted) setState(() => otpSending = false);
    }
  }

  Future<void> _register() async {
    final app = appController;
    if (name.text.trim().isEmpty ||
        mobile.text.trim().isEmpty ||
        password.text.length < 6) {
      setState(() => error = app.t('fill_required_fields'));
      return;
    }
    if (password.text != confirmPassword.text) {
      setState(() => error = app.t('passwords_not_match'));
      return;
    }
    if (!YemenPhone.isValid(mobile.text.trim())) {
      setState(() => error = app.t('invalid_yemeni_mobile_number'));
      return;
    }
    if (_availableOtpMethods(cityConfig).isNotEmpty && otp.text.trim().isEmpty) {
      setState(() => error = app.t('enter_otp'));
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
        otp: otp.text.trim().isEmpty ? null : otp.text.trim(),
        cityId: int.tryParse('${app.city?['id']}'),
      );
      if (!mounted) return;
      if (message != null) {
        setState(() => error = message);
      } else {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/addresses');
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = app.t('network_error'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
