// lib/views/pages/text_viewer_page.dart

import 'dart:convert'; // UTF-8 decode için eklendi
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
// Kod renklendirme paketleri
import 'package:flutter_highlight/flutter_highlight.dart';
// ✅ DÜZELTİLMİŞ YOL:
import 'package:flutter_highlight/themes/atom-one-dark.dart';

import 'package:shared_core/models/file_model.dart';

class TextViewerPage extends StatefulWidget {
  final FileItem file;
  const TextViewerPage({super.key, required this.file});

  @override
  State<TextViewerPage> createState() => _TextViewerPageState();
}

class _TextViewerPageState extends State<TextViewerPage> {
  String? _textContent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTextContent();
  }

  /// Dosyanın metin içeriğini http ile indirir
  Future<void> _loadTextContent() async {
    try {
      final response = await http.get(Uri.parse(widget.file.fileUrl));
      if (!mounted) return;
      if (response.statusCode == 200) {
        // UTF-8 olarak kodlandığından emin ol (Türkçe karakterler için önemli)
        setState(() {
          _textContent = utf8.decode(response.bodyBytes);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              "Dosya içeriği yüklenemedi (Hata Kodu: ${response.statusCode})";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Bir hata oluştu: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.file.fileName,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Kopyalama butonu
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Tümünü Kopyala',
            onPressed: (_isLoading || _error != null)
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: _textContent!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('İçerik panoya kopyalandı!'),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Dosya türüne göre "akıllı" görüntüleyici seç
    if (widget.file.fileType == 'code') {
      // --- 1. KOD GÖRÜNTÜLEYİCİ (Renkli) ---
      return SingleChildScrollView(
        child: HighlightView(
          _textContent!,
          // Dosya uzantısına göre dili otomatik bul
          language: widget.file.fileExtension,
          // Tema (atomOneDarkTheme değişkeni 'atom-one-dark.dart' importundan gelir)
          theme: atomOneDarkTheme,
          padding: const EdgeInsets.all(12),
          textStyle: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
        ),
      );
    } else {
      // --- 2. DÜZ METİN GÖRÜNTÜLEYİCİ (Sade) ---
      return TextField(
        controller: TextEditingController(text: _textContent),
        readOnly: true,
        maxLines: null, // Sınırsız satır
        expands: true, // Tüm alanı kapla
        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
        ),
      );
    }
  }
}
