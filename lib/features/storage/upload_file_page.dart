// apps/mostromo_connect/lib/features/storage/upload_file_page.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // MethodChannel için
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';

// 🌟 YENİ MOTOR
import 'viewmodels/storage_view_model.dart';

class UploadFilePage extends StatefulWidget {
  final int folderId;

  const UploadFilePage({super.key, required this.folderId});

  @override
  State<UploadFilePage> createState() => _UploadFilePageState();
}

class _UploadFilePageState extends State<UploadFilePage> {
  // ✅ DRIVE İÇİN KANAL ADI (Aynen korundu)
  static const platform = MethodChannel('mostromo_connect/share');

  // Eski Controller yerine dosyaları yerel olarak tutuyoruz
  final List<PlatformFile> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    // Sayfa açıldığında paylaşılan dosya var mı kontrol et
    _checkSharedFiles();
  }

  // Native taraftan paylaşılan dosyaları alıp Listeye ekler
  Future<void> _checkSharedFiles() async {
    try {
      final bool? hasShare = await platform.invokeMethod('hasPendingShare');

      if (hasShare == true) {
        final List<dynamic>? sharedPaths = await platform.invokeMethod(
          'getSharedFiles',
        );

        if (sharedPaths != null && sharedPaths.isNotEmpty && mounted) {
          setState(() {
            for (var path in sharedPaths.cast<String>()) {
              final name = path.split('/').last;
              _selectedFiles.add(PlatformFile(name: name, size: 0, path: path));
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${sharedPaths.length} dosya paylaşımdan eklendi.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Paylaşım kontrol hatası: $e");
    }
  }

  // Yükleme tamamlandıktan sonra native cache'i temizlemek için
  Future<void> _clearNativeSharedFiles() async {
    try {
      await platform.invokeMethod('clearSharedFiles');
    } catch (e) {
      debugPrint("Native temizleme hatası: $e");
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        _selectedFiles.addAll(result.files);
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dosya seçilmedi.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _clearAll() {
    setState(() {
      _selectedFiles.clear();
    });
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return "Boyut Hesaplanıyor...";
    const units = ["B", "KB", "MB", "GB"];
    final digitGroups = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, digitGroups)).toStringAsFixed(1)} ${units[digitGroups]}";
  }

  // 🌟 YENİ: DOSYALARI WINDOWS İLE AYNI OLAN ANA MOTORA PASLIYORUZ
  Future<void> _startUpload() async {
    if (_selectedFiles.isEmpty) return;

    final viewModel = context.read<StorageViewModel>();
    final folderName = viewModel.currentFolderName;

    // Dosyaları yeni motora ekle
    for (var file in _selectedFiles) {
      if (file.path != null) {
        viewModel.addProgrammaticUpload(
          file: XFile(file.path!),
          targetFolderId: widget.folderId,
          targetFolderName: folderName,
        );
      }
    }

    // Yüklemeyi Global Motor üzerinden başlat
    viewModel.startUpload();
    await _clearNativeSharedFiles();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yükleme başlatıldı. Arka planda devam edecek.'),
          backgroundColor: Colors.green,
        ),
      );

      // ✅ Tasarımdaki "İstersen sayfayı kapatabilirsin" yorumunu uyguladık.
      // Kullanıcı kapandığında alttaki Global Upload paneliyle karşılaşacak.
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFiles = _selectedFiles.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dosya Yükleme'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded),
            onPressed: hasFiles ? _clearAll : null,
          ),
        ],
      ),

      // Dosya Ekleme Butonu (FAB)
      floatingActionButton: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: hasFiles ? 70.0 : 16.0),
        child: FloatingActionButton.extended(
          onPressed: _pickFiles,
          label: const Text('Dosya Ekle'),
          icon: const Icon(Icons.add_rounded),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: Column(
        children: [
          // --- DOSYA LİSTESİ ---
          Expanded(
            child: hasFiles
                ? ListView.builder(
                    itemCount: _selectedFiles.length,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemBuilder: (context, index) {
                      final file = _selectedFiles[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.file_present),
                          ),
                          title: Text(file.name),
                          subtitle: Text(
                            _formatSize(file.size),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => _removeFile(index),
                          ),
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Henüz dosya seçilmedi',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Aşağıdaki butondan veya paylaşımla dosya ekleyin',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
          ),

          // --- ALT KISIM (YÜKLE BUTONU) ---
          if (hasFiles)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _startUpload,
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: Text('Dosyaları Yükle (${_selectedFiles.length})'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
