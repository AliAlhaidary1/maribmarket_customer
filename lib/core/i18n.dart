import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class I18n extends ChangeNotifier {
  I18n();

  String code = 'ar';
  Map<String, String> _strings = {};

  bool get isRtl => code == 'ar';
  TextDirection get direction => isRtl ? TextDirection.rtl : TextDirection.ltr;
  Locale get locale => Locale(code);

  String t(String key) => _strings[key] ?? key;

  Future<void> load(String languageCode) async {
    code = languageCode == 'en' ? 'en' : 'ar';
    final raw = await rootBundle.loadString('assets/i18n/$code.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _strings = decoded.map((key, value) => MapEntry(key, '$value'));
    notifyListeners();
  }
}
