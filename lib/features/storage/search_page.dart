// apps/mostromo_connect/lib/features/search/search_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/nav_event_provider.dart'; // ✅ Yeni eklenen
import '../storage/viewmodels/storage_view_model.dart';
import 'package:shared_core/models/file_model.dart';
import 'package:shared_core/models/folder_model.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(); // ✅ Odağı yönetmek için
  String _query = '';
  late NavEventProvider _navEventProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavEventProvider>().addListener(_handleNavEvent);
    });
  }

  // ✅ 2. Referansı güvenli bir aşamada alın
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navEventProvider = context.read<NavEventProvider>();
  }

  void _handleNavEvent() {
    if (_navEventProvider.activeTab == 1 && mounted) {
      _searchFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    // ✅ 3. Kaydedilen referans üzerinden dinleyiciyi kaldırın
    _navEventProvider.removeListener(_handleNavEvent);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openFileViewer(BuildContext context, FileItem file) {
    switch (file.fileType) {
      case 'media/img':
      case 'media/video':
        context.push('/media_viewer', extra: file);
        break;
      case 'document/pdf':
        context.push('/pdf_viewer', extra: file);
        break;
      case 'document/text':
      case 'code':
        context.push('/text_viewer', extra: file);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${file.fileName}" için görüntüleyici yok.')),
        );
    }
  }

  void _navigateToFolder(
    BuildContext context,
    StorageViewModel viewModel,
    FolderItem folder,
  ) {
    viewModel.navigateToFolder(folder);
    StatefulNavigationShell.of(context).goBranch(0); // Dosyalarım sekmesine dön
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arama'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Center(
              child: SizedBox(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode, // ✅ FocusNode bağlandı
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Dosya veya klasör adı...',
                    prefixIcon: const Icon(Icons.search, color: Colors.blue),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 100,
              color: Colors.blue.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hızlıca bulmak için yazmaya başlayın',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Consumer<StorageViewModel>(
      builder: (context, viewModel, child) {
        final folderResults = viewModel.allFolders
            .where((f) => f.folderName.toLowerCase().contains(_query))
            .toList();
        final fileResults = viewModel.allFiles
            .where((f) => f.fileName.toLowerCase().contains(_query))
            .toList();

        if (folderResults.isEmpty && fileResults.isEmpty) {
          return const Center(child: Text('Eşleşen öğe bulunamadı.'));
        }

        return Center(
          child: SizedBox(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (folderResults.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 12, top: 16, bottom: 8),
                    child: Text(
                      'Klasörler',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  ...folderResults.map(
                    (folder) => _buildResultCard(
                      icon: Icons.folder,
                      color: Colors.blue,
                      title: folder.folderName,
                      subtitle: 'Klasör',
                      onTap: () =>
                          _navigateToFolder(context, viewModel, folder),
                    ),
                  ),
                ],
                if (fileResults.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 12, top: 16, bottom: 8),
                    child: Text(
                      'Dosyalar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  ...fileResults.map(
                    (file) => _buildResultCard(
                      icon: _getFileIcon(file.fileType),
                      color: Colors.orange,
                      title: file.fileName,
                      subtitle: 'Dosya',
                      onTap: () => _openFileViewer(context, file),
                    ),
                  ),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getFileIcon(String fileType) {
    if (fileType.startsWith('media/img')) return Icons.image;
    if (fileType.startsWith('media/video')) return Icons.videocam;
    if (fileType == 'document/pdf') return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  Widget _buildResultCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        onTap: onTap,
      ),
    );
  }
}
