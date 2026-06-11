// lib/features/storage/shared_preview_page.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:common_ui/data/theme_colors.dart';
import 'package:shared_core/models/file_model.dart';
import 'package:shared_core/models/folder_model.dart';
import 'viewmodels/storage_view_model.dart';

class SharedPreviewPage extends StatefulWidget {
  final String token;
  const SharedPreviewPage({super.key, required this.token});

  @override
  State<SharedPreviewPage> createState() => _SharedPreviewPageState();
}

class _SharedPreviewPageState extends State<SharedPreviewPage> {
  bool _isLoading = true;
  bool _isLocked = false;
  String _errorMessage = '';
  Map<String, dynamic>? _fileData;

  final TextEditingController _passwordController = TextEditingController();

  // Klasör Gezintisi İçin Gerekli Değişkenler
  int? _currentFolderId;
  List<Map<String, dynamic>> _breadcrumb = [];

  @override
  void initState() {
    super.initState();
    _fetchFileInfo();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchFileInfo() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com/connect/android/share_info.php"),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'token': widget.token,
          'password': _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _fileData = data;
            _isLocked = false;
            _errorMessage = '';
            _isLoading = false;

            // Eğer klasörse gezinme ağacını başlat
            if (_fileData!['item_type'] == 'folder') {
              _currentFolderId = _fileData!['root_folder_id'];
              _breadcrumb = [
                {
                  'id': _currentFolderId,
                  'name': _fileData!['root_folder_name'],
                },
              ];
            }
          });
        } else {
          setState(() {
            if (data['is_locked'] == true) {
              _isLocked = true;
              _errorMessage =
                  data['message'] ?? 'Bu içerik şifre ile korunmaktadır.';
            } else {
              _isLocked = false;
              _errorMessage = data['message'] ?? 'Bilinmeyen bir hata oluştu.';
            }
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

  void _downloadSingleFile(Map<String, dynamic> data) {
    final fileExt =
        (data['file_Extension'] ?? data['file_Name'].toString().split('.').last)
            .toString()
            .toLowerCase();
    String fType = data['file_Type'] ?? 'other';

    // Uygulamanın API dizininde değilse mutlak yolu oluştur
    String absoluteUrl = data['file_url'] ?? data['file_URL'];
    if (!absoluteUrl.startsWith('http'))
      absoluteUrl = 'https://mostromo.com/connect/$absoluteUrl';

    final dummyFile = FileItem(
      fileName: data['file_Name'] ?? data['file_name'],
      fileUrl: absoluteUrl,
      fileSize: data['file_Size'] ?? data['file_size'] ?? 0,
      fileExtension: fileExt,
      fileType: fType,
      folderId: data['folder_id'] ?? 0,
      createdAt: data['createdDate'] ?? DateTime.now().toIso8601String(),
    );

    context.read<StorageViewModel>().startDownload(dummyFile);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('İndirme arka planda başlatıldı.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _downloadEntireFolder() {
    final dummyFolder = FolderItem(
      folderId: _fileData!['root_folder_id'],
      folderName: _fileData!['root_folder_name'],
      parentId: 0,
    );
    context.read<StorageViewModel>().startFolderDownload(dummyFolder);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Klasör ZIP olarak iniyor...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFolderExplorer =
        _fileData != null && _fileData!['item_type'] == 'folder' && !_isLocked;

    return PopScope(
      canPop: !isFolderExplorer || _breadcrumb.length <= 1,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // Android geri tuşuna basıldığında uygulamadan çıkmak yerine bir üst klasöre dön!
        setState(() {
          _breadcrumb.removeLast();
          _currentFolderId = _breadcrumb.last['id'];
        });
      },
      child: Scaffold(
        backgroundColor: ThemeColors.background,
        appBar: AppBar(
          backgroundColor: ThemeColors.surface,
          elevation: 0,
          title: Text(
            isFolderExplorer ? _breadcrumb.last['name'] : "Mostromo Paylaşım",
            style: TextStyle(color: ThemeColors.titleText, fontSize: 16),
          ),
          leading: IconButton(
            icon: Icon(
              isFolderExplorer && _breadcrumb.length > 1
                  ? Icons.arrow_back_rounded
                  : Icons.close_rounded,
              color: ThemeColors.titleText,
            ),
            onPressed: () {
              if (isFolderExplorer && _breadcrumb.length > 1) {
                setState(() {
                  _breadcrumb.removeLast();
                  _currentFolderId = _breadcrumb.last['id'];
                });
              } else {
                context.go('/');
              }
            },
          ),
          actions: [
            if (isFolderExplorer)
              IconButton(
                icon: const Icon(
                  Icons.archive_rounded,
                  color: Colors.blueAccent,
                ),
                tooltip: "Tümünü İndir",
                onPressed: _downloadEntireFolder,
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isLocked
            ? Center(child: _buildLockCard())
            : _errorMessage.isNotEmpty
            ? Center(child: _buildErrorCard())
            : isFolderExplorer
            ? _buildFolderExplorer()
            : Center(child: _buildFilePreviewCard()),
      ),
    );
  }

  // ==========================================
  // 📁 KLASÖR GEZGİNİ ARAYÜZÜ (Sanki kendi klasörü gibi)
  // ==========================================
  Widget _buildFolderExplorer() {
    final folders = (_fileData!['folders'] as List)
        .where((f) => f['parent_id'] == _currentFolderId)
        .toList();
    final files = (_fileData!['files'] as List)
        .where((f) => f['folder_id'] == _currentFolderId)
        .toList();

    return Column(
      children: [
        // Ekmek Kırıntısı (Breadcrumb) Yolu
        Container(
          height: 48,
          width: double.infinity,
          decoration: BoxDecoration(
            color: ThemeColors.surface,
            border: Border(
              bottom: BorderSide(
                color: ThemeColors.titleText.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _breadcrumb.length,
            separatorBuilder: (c, i) => Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: ThemeColors.captionText,
            ),
            itemBuilder: (c, i) {
              final b = _breadcrumb[i];
              final isLast = i == _breadcrumb.length - 1;
              return TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: isLast
                      ? ThemeColors.titleText
                      : ThemeColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () {
                  setState(() {
                    _currentFolderId = b['id'];
                    _breadcrumb = _breadcrumb.sublist(0, i + 1);
                  });
                },
                child: Text(
                  b['name'],
                  style: TextStyle(
                    fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: folders.isEmpty && files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 64,
                        color: ThemeColors.captionText.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Bu klasör boş",
                        style: TextStyle(color: ThemeColors.captionText),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    ...folders.map((f) => _buildFolderItem(f)),
                    ...files.map((f) => _buildFileItem(f)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFolderItem(Map<String, dynamic> f) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: ThemeColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeColors.titleText.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.folder_rounded, color: Colors.amber),
        ),
        title: Text(
          f['folder_name'],
          style: TextStyle(
            color: ThemeColors.titleText,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: ThemeColors.captionText,
        ),
        onTap: () {
          setState(() {
            _currentFolderId = f['folder_id'];
            _breadcrumb.add({'id': f['folder_id'], 'name': f['folder_name']});
          });
        },
      ),
    );
  }

  Widget _buildFileItem(Map<String, dynamic> f) {
    final ext = (f['file_Extension'] ?? f['file_Name'].split('.').last)
        .toString()
        .toLowerCase();

    IconData iconData = Icons.insert_drive_file_rounded;
    Color iconColor = ThemeColors.primary;
    if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      iconData = Icons.image_rounded;
      iconColor = Colors.green;
    } else if (ext == 'pdf') {
      iconData = Icons.picture_as_pdf_rounded;
      iconColor = Colors.redAccent;
    } else if (['mp4', 'avi', 'mkv'].contains(ext)) {
      iconData = Icons.videocam_rounded;
      iconColor = Colors.orange;
    } else if (['zip', 'rar'].contains(ext)) {
      iconData = Icons.archive_rounded;
      iconColor = Colors.brown;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: ThemeColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeColors.titleText.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(iconData, color: iconColor),
        ),
        title: Text(
          f['file_Name'],
          style: TextStyle(
            color: ThemeColors.titleText,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatSize(f['file_Size'] ?? 0),
          style: TextStyle(color: ThemeColors.captionText, fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(Icons.download_rounded, color: ThemeColors.primary),
          onPressed: () => _downloadSingleFile(f),
        ),
        onTap: () {
          // Medya dosyalarını direkt uygulamada aç, diğerlerini indir
          if ([
            'jpg',
            'jpeg',
            'png',
            'webp',
            'mp4',
            'pdf',
            'txt',
          ].contains(ext)) {
            String absoluteUrl = f['file_URL'].toString().startsWith('http')
                ? f['file_URL']
                : 'https://mostromo.com/connect/${f['file_URL']}';

            // 🌟 HATA BURADAYDI: folderId eklendi!
            final dummy = FileItem(
              fileName: f['file_Name'],
              fileUrl: absoluteUrl,
              fileSize: f['file_Size'],
              fileExtension: ext,
              fileType: f['file_Type'] ?? 'other',
              folderId: f['folder_id'] ?? 0, // <--- EKSİK OLAN PARAMETRE
              createdAt: '',
            );

            if (ext == 'pdf')
              context.push('/pdf_viewer', extra: dummy);
            else if (ext == 'txt')
              context.push('/text_viewer', extra: dummy);
            else
              context.push('/media_viewer', extra: dummy);
          } else {
            _downloadSingleFile(f);
          }
        },
      ),
    );
  }

  // ==========================================
  // 🔒 KİLİT EKRANI KARTI
  // ==========================================
  Widget _buildLockCard() {
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
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 48,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "İçerik Şifrelenmiş",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 14, color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ThemeColors.titleText,
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                decoration: InputDecoration(
                  hintText: "Şifreyi Girin",
                  hintStyle: TextStyle(
                    letterSpacing: 0,
                    fontWeight: FontWeight.normal,
                    color: ThemeColors.captionText.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: ThemeColors.background.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onSubmitted: (_) => _fetchFileInfo(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _fetchFileInfo,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text(
                    "Kilidi Aç",
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

  // ==========================================
  // 📄 TEK DOSYA AÇIK EKRAN (ÖNİZLEME)
  // ==========================================
  Widget _buildFilePreviewCard() {
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
                _fileData!['file_name'] ?? _fileData!['file_Name'],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Boyut: ${_formatSize(_fileData!['file_size'] ?? _fileData!['file_Size'] ?? 0)}",
                style: TextStyle(fontSize: 15, color: ThemeColors.captionText),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _downloadSingleFile(_fileData!),
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
            child: const Text("Kapat"),
          ),
        ],
      ),
    );
  }
}
