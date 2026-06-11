// lib/features/storage/shared_links_page.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:common_ui/data/theme_colors.dart';
import 'package:shared_core/models/file_model.dart';
import 'viewmodels/storage_view_model.dart';

class SharedLinksPage extends StatefulWidget {
  const SharedLinksPage({super.key});

  @override
  State<SharedLinksPage> createState() => _SharedLinksPageState();
}

class _SharedLinksPageState extends State<SharedLinksPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _links = [];

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  // 🌟 GÜNCELLENDİ: Hata Ayıklama (Debug) Motoru Eklendi
  Future<void> _loadLinks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 0;

      debugPrint("🔍 [PAYLAŞILANLAR] İstek başlıyor... UserID: $userId");

      if (userId != 0) {
        final response = await http
            .post(
              Uri.parse(
                "https://mostromo.com/connect/android/share_manager.php",
              ),
              headers: {
                'Content-Type': 'application/json',
              }, // 🌟 GÜVENLİK İÇİN EKLENDİ
              body: json.encode({'action': 'list', 'user_id': userId}),
            )
            .timeout(const Duration(seconds: 15));

        debugPrint(
          "📥 [PAYLAŞILANLAR] Sunucu Yanıt Kodu: ${response.statusCode}",
        );
        debugPrint(
          "📥 [PAYLAŞILANLAR] Sunucu Gelen Raw Veri: ${response.body}",
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          debugPrint("🧩 [PAYLAŞILANLAR] Çözümlenen JSON: $data");

          if (data['success'] == true && data['links'] != null) {
            final rawLinks = data['links'] as List;
            debugPrint(
              "✅ [PAYLAŞILANLAR] Başarılı! Bulunan Link Sayısı: ${rawLinks.length}",
            );

            if (mounted) {
              setState(() {
                _links = rawLinks
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
                _isLoading = false;
              });
              return;
            }
          } else {
            debugPrint(
              "⚠️ [PAYLAŞILANLAR] Sunucu success: false döndürdü veya links boş.",
            );
          }
        }
      } else {
        debugPrint(
          "❌ [PAYLAŞILANLAR] UserID 0! Kullanıcı giriş yapmamış görünüyor.",
        );
      }
    } catch (e) {
      debugPrint("❌ [PAYLAŞILANLAR] ÇÖKME HATASI (Exception): $e");
    }

    if (mounted) {
      setState(() {
        _links = [];
        _isLoading = false;
      });
    }
  }

  void _revokeLink(Map<String, dynamic> linkData) async {
    final fileExt = (linkData['file_Extension'] ?? '').toString().toLowerCase();
    String fType = 'other';
    if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(fileExt))
      fType = 'image';
    else if (['mp4', 'avi', 'mov', 'mkv'].contains(fileExt))
      fType = 'video';
    else if (['pdf', 'txt', 'doc', 'docx'].contains(fileExt))
      fType = 'document';
    else if (fileExt == 'folder')
      fType = 'folder';

    final dummyFile = FileItem(
      fileName: linkData['file_Name'] ?? 'Bilinmeyen',
      fileUrl: linkData['file_url'] ?? '',
      fileSize: int.tryParse(linkData['file_Size'].toString()) ?? 0,
      fileExtension: fileExt,
      fileType: fType,
      folderId: int.tryParse(linkData['folder_id'].toString()) ?? 0,
      createdAt: '',
    );

    final success = await context.read<StorageViewModel>().revokeShareLink(
      dummyFile,
    );
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paylaşım durduruldu.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      _loadLinks();
    }
  }

  IconData _getIconForType(String ext) {
    if (ext == 'folder') return Icons.folder_rounded;
    if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext))
      return Icons.image_rounded;
    if (['mp4', 'avi', 'mov', 'mkv'].contains(ext))
      return Icons.video_collection_rounded;
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf_rounded;
    if (['zip', 'rar', '7z'].contains(ext)) return Icons.folder_zip_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _getColorForType(String ext) {
    if (ext == 'folder') return Colors.amber;
    if (['pdf', 'zip', 'rar'].contains(ext)) return Colors.redAccent;
    if (['jpg', 'jpeg', 'png'].contains(ext)) return Colors.blueAccent;
    return ThemeColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background,
      appBar: AppBar(
        backgroundColor: ThemeColors.sidePanelColor.withValues(alpha: 0.8),
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15 * 0.5, sigmaY: 15 * 0.5),
            child: Container(
              color: ThemeColors.sidePanelColor.withValues(alpha: 0.8),
            ),
          ),
        ),
        title: Text(
          "Paylaşılanlar Merkezi",
          style: TextStyle(
            color: ThemeColors.titleText,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: ThemeColors.titleText),
            onPressed: _loadLinks,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: ThemeColors.primary))
          : RefreshIndicator(
              color: ThemeColors.primary,
              backgroundColor: ThemeColors.surface,
              onRefresh: _loadLinks,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: _links.isEmpty
                      ? _buildEmptyState()
                      : CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(child: _buildDashboardStats()),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) =>
                                      _buildLinkCard(_links[index]),
                                  childCount: _links.length,
                                ),
                              ),
                            ),
                            const SliverPadding(
                              padding: EdgeInsets.only(bottom: 120),
                            ),
                          ],
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildDashboardStats() {
    int protectedCount = _links
        .where(
          (l) => l['password'] != null && l['password'].toString().isNotEmpty,
        )
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              children: [
                _buildStatCard(
                  "Aktif Paylaşım",
                  _links.length.toString(),
                  Icons.podcasts_rounded,
                  ThemeColors.primary,
                ),
                const SizedBox(height: 16),
                _buildStatCard(
                  "Şifre Korumalı",
                  protectedCount.toString(),
                  Icons.lock_person_rounded,
                  Colors.orangeAccent,
                ),
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "Aktif Paylaşım",
                    _links.length.toString(),
                    Icons.podcasts_rounded,
                    ThemeColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    "Şifre Korumalı",
                    protectedCount.toString(),
                    Icons.lock_person_rounded,
                    Colors.orangeAccent,
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ThemeColors.titleText.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ThemeColors.titleText,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: ThemeColors.captionText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(Map<String, dynamic> link) {
    final token = link['token'];
    final shareUrl = "https://mostromo.com/connect/s?t=$token";
    final hasPassword =
        link['password'] != null && link['password'].toString().isNotEmpty;
    final hasExpire = link['expires_at'] != null;
    final isFolder = link['item_type'] == 'folder';

    final fileExt = (link['file_Extension'] ?? '').toString().toLowerCase();
    final iconData = _getIconForType(isFolder ? 'folder' : fileExt);
    final iconColor = _getColorForType(isFolder ? 'folder' : fileExt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: ThemeColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ThemeColors.titleText.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(iconData, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link['file_Name'] ?? 'Bilinmeyen Öğe',
                        style: TextStyle(
                          fontSize: 16,
                          color: ThemeColors.titleText,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFolder ? "Klasör Paylaşımı" : "Dosya Paylaşımı",
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeColors.captionText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 22),
                      color: ThemeColors.primary,
                      tooltip: "Bağlantıyı Kopyala",
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bağlantı panoya kopyalandı!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.block_rounded, size: 22),
                      color: Colors.redAccent,
                      tooltip: "Paylaşımı Durdur",
                      onPressed: () => _showRevokeConfirmDialog(link),
                    ),
                  ],
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hasPassword)
                  _buildChip(
                    Icons.lock_rounded,
                    "Şifreli: ${link['password']}",
                    Colors.orangeAccent,
                  )
                else
                  _buildChip(
                    Icons.public_rounded,
                    "Herkese Açık",
                    Colors.green,
                  ),

                if (hasExpire)
                  _buildChip(
                    Icons.timer_rounded,
                    link['expires_at'].toString().substring(0, 16),
                    Colors.redAccent,
                  )
                else
                  _buildChip(
                    Icons.all_inclusive_rounded,
                    "Sınırsız",
                    ThemeColors.primary,
                  ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: ThemeColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ThemeColors.titleText.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 16,
                    color: ThemeColors.captionText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shareUrl,
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showRevokeConfirmDialog(Map<String, dynamic> link) {
    showDialog(
      context: context,
      barrierColor: ThemeColors.background.withValues(alpha: 0.5),
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.floatingPanelColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.block_rounded, color: Colors.redAccent),
            ),
            const SizedBox(width: 12),
            Text(
              "Paylaşımı Durdur",
              style: TextStyle(
                color: ThemeColors.titleText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          "Bu öğenin paylaşımını durdurmak istediğinize emin misiniz? Oluşturulan bağlantı artık çalışmayacak.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "İptal",
              style: TextStyle(color: ThemeColors.captionText),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _revokeLink(link);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Durdur",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: ThemeColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.podcasts_rounded,
                      size: 80,
                      color: ThemeColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Paylaşılan İçerik Yok",
                    style: TextStyle(
                      fontSize: 22,
                      color: ThemeColors.titleText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Dosya veya klasörlerinize sağ tıklayıp\n\"Paylaş\" diyerek dış dünyaya açabilirsiniz.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ThemeColors.captionText,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
