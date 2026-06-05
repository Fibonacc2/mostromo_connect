// lib/features/storage/shared_preview_page.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:common_ui/data/theme_colors.dart';
import 'package:shared_core/models/file_model.dart';
import 'viewmodels/storage_view_model.dart';

class SharedPreviewPage extends StatefulWidget {
  final String token;
  const SharedPreviewPage({super.key, required this.token});

  @override
  State<SharedPreviewPage> createState() => _SharedPreviewPageState();
}

class _SharedPreviewPageState extends State<SharedPreviewPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _fileData;

  @override
  void initState() {
    super.initState();
    _fetchFileInfo();
  }

  Future<void> _fetchFileInfo() async {
    try {
      final response = await http.get(
        Uri.parse(
          "https://mostromo.com/connect/android/share_info.php?token=${widget.token}",
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _fileData = data;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Bilinmeyen bir hata oluştu.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Sunucuya bağlanılamadı.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'İnternet bağlantınızı kontrol edin.';
        _isLoading = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  void _downloadFile() {
    if (_fileData == null) return;

    // Uzantıya göre dosya türünü (fileType) tahmin et
    final fileExt = _fileData!['file_name']
        .toString()
        .split('.')
        .last
        .toLowerCase();
    String fType = 'other';
    if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(fileExt))
      fType = 'image';
    else if (['mp4', 'avi', 'mov', 'mkv'].contains(fileExt))
      fType = 'video';
    else if (['pdf', 'txt', 'doc', 'docx'].contains(fileExt))
      fType = 'document';

    // Geçici bir FileItem oluşturup uygulamanın kendi indirme motoruna yolluyoruz
    final dummyFile = FileItem(
      fileName: _fileData!['file_name'],
      fileUrl: _fileData!['file_url'],
      fileSize: _fileData!['file_size'],
      fileExtension: fileExt,
      fileType: fType, // 🌟 EKSİK PARAMETRE EKLENDİ
      folderId:
          0, // 🌟 EKSİK PARAMETRE EKLENDİ (Salt indirme işlemi olduğu için 0 yeterli)
      createdAt: DateTime.now().toIso8601String(),
    );

    context.read<StorageViewModel>().startDownload(dummyFile);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('İndirme arka planda başlatıldı.'),
        backgroundColor: Colors.green,
      ),
    );
    context.go('/'); // İndirmeyi başlatıp ana sayfaya at
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/'), // Ana sayfaya dön
        ),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _errorMessage.isNotEmpty
            ? _buildErrorCard()
            : _buildPreviewCard(),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final fileName = _fileData!['file_name'];
    final fileSize = _formatSize(_fileData!['file_size']);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: ThemeColors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: ThemeColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.insert_drive_file_rounded,
                  size: 48,
                  color: ThemeColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                fileName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Boyut: $fileSize",
                style: TextStyle(fontSize: 15, color: ThemeColors.captionText),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _downloadFile,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text(
                    "Dosyayı İndir",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ThemeColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text("Ana Sayfaya Dön"),
          ),
        ],
      ),
    );
  }
}
