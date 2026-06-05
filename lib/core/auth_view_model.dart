// lib/core/auth_view_model.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthViewModel extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = true;

  int? _userId;
  String? _userName;
  String? _userEmail;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  int? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;

  AuthViewModel() {
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    _userName = prefs.getString('user_name');
    _userEmail = prefs.getString('user_email');

    _isLoggedIn = _userId != null;
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    try {
      // 🌟 DİKKAT: JSON yerine PHP'nin beklediği standart "Form Data" yolluyoruz
      final response = await http.post(
        // Buradaki adresi kendi sunucu adresine göre güncelle
        Uri.parse("https://mostromo.com//loginAoth.php"),

        // PHP'deki $_POST değişkenleriyle birebir aynı isimler olmalı
        body: {
          'email': email,
          'pwd': password, // Senin PHP 'pwd' bekliyor
          'is_app': '1', // Uygulamadan geldiğimizi PHP'ye haber veriyoruz
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          var rawId = data['userID'];
          if (rawId is int) {
            _userId = rawId;
          } else {
            _userId = int.tryParse(rawId.toString()) ?? 0;
          }
          _userName = data['nick'];
          _userEmail = email; // E-postayı formdan biliyoruz
          _isLoggedIn = true;

          // Hafızaya kaydet (Beni hatırla)
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', _userId!);
          await prefs.setString('user_name', _userName!);
          await prefs.setString('user_email', _userEmail!);

          notifyListeners();
          return null; // Hata yok, başarılı
        } else {
          // Şifre yanlış, hesap engelli vs.
          return data['message'];
        }
      } else {
        return "Sunucu yanıt vermedi (Kod: ${response.statusCode})";
      }
    } catch (e) {
      return "Bağlantı hatası: İnternetinizi kontrol edin.";
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _isLoggedIn = false;
    _userId = null;
    _userName = null;
    _userEmail = null;
    notifyListeners();
  }
}
