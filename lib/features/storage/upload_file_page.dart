// apps/mostromo_connect/lib/features/storage/upload_file_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // MethodChannel için
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/services/upload_controller.dart';

class UploadFilePage extends StatelessWidget {
  final int folderId;

  const UploadFilePage({super.key, required this.folderId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // ✅ DRIVE İÇİN ÖZEL AYARLAR (Url ve Parametreler)
      create: (_) => UploadController(
        uploadUrl: "https://mostromo.com/connect/android/upload.php",
        additionalFields: {
          "uploadLocation": "myStorage", // Drive dosyaları buraya
          "folder_id": folderId.toString(),
        },
      ),
      // Alt widget'ı Stateful yaparak initState kullanabiliyoruz
      child: const _UploadFileView(),
    );
  }
}

class _UploadFileView extends StatefulWidget {
  const _UploadFileView();

  @override
  State<_UploadFileView> createState() => _UploadFileViewState();
}

class _UploadFileViewState extends State<_UploadFileView> {
  // ✅ DRIVE İÇİN KANAL ADI
  static const platform = MethodChannel('mostromo_connect/share');

  @override
  void initState() {
    super.initState();
    // Sayfa açıldığında paylaşılan dosya var mı kontrol et
    _checkSharedFiles();
  }

  // Native taraftan paylaşılan dosyaları alıp Controller'a ekler
  Future<void> _checkSharedFiles() async {
    try {
      final bool? hasShare = await platform.invokeMethod('hasPendingShare');

      if (hasShare == true) {
        final List<dynamic>? sharedPaths = await platform.invokeMethod(
          'getSharedFiles',
        );

        if (sharedPaths != null && sharedPaths.isNotEmpty && mounted) {
          // Controller'a eriş ve dosyaları ekle
          final controller = context.read<UploadController>();
          await controller.addFilesFromPaths(sharedPaths.cast<String>());

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

  @override
  Widget build(BuildContext context) {
    // Controller'ı dinle (watch)
    final controller = context.watch<UploadController>();
    final hasFiles = controller.selectedFiles.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dosya Yükleme'),
        centerTitle: true,
        actions: [
          // Yükleme sırasında silme butonunu devre dışı bırak
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded),
            onPressed: (hasFiles && !controller.isUploading)
                ? () => controller.clearAll()
                : null,
          ),
        ],
      ),

      // Dosya Ekleme Butonu (FAB)
      // Yükleme sırasında gizlenir
      floatingActionButton: !controller.isUploading
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: EdgeInsets.only(bottom: hasFiles ? 70.0 : 16.0),
              child: FloatingActionButton.extended(
                onPressed: () async {
                  final picked = await controller.pickFiles();
                  if (picked == 0 && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dosya seçilmedi.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                label: const Text('Dosya Ekle'),
                icon: const Icon(Icons.add_rounded),
              ),
            )
          : null, // Yükleme yapılıyorsa FAB'ı gizle
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: Column(
        children: [
          // --- DOSYA LİSTESİ ---
          Expanded(
            child: hasFiles
                ? ListView.builder(
                    itemCount: controller.selectedFiles.length,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemBuilder: (context, index) {
                      final file = controller.selectedFiles[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.file_present),
                          ),
                          title: Text(file.name),
                          subtitle: Text(
                            controller.formatFileSize(file.size),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: !controller.isUploading
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () =>
                                      controller.removeFileAt(index),
                                )
                              : null, // Yükleme sırasında silinemez
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

          // --- ALT KISIM (BUTON veya PROGRESS) ---
          if (hasFiles)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              // Yükleme sırasında alan biraz daha geniş olabilir
              height: controller.isUploading ? 100 : 80,
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
                  child: controller.isUploading
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ✅ İLERLEME ÇUBUĞU
                            LinearProgressIndicator(
                              value: controller.currentProgress,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Arka planda yükleniyor... %${(controller.currentProgress * 100).toInt()}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : ElevatedButton.icon(
                          onPressed: () async {
                            // Yüklemeyi başlat
                            await controller.uploadFiles();

                            // Yükleme bitince native cache'i temizle
                            await _clearNativeSharedFiles();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Yükleme başlatıldı. Arka planda devam edecek.',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              // İstersen işlem başlayınca sayfayı kapatabilirsin:
                              // context.pop();
                            }
                          },
                          icon: const Icon(Icons.cloud_upload_rounded),
                          label: Text(
                            'Dosyaları Yükle (${controller.selectedFiles.length})',
                          ),
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
