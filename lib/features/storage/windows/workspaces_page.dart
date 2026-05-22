// lib/features/storage/windows/workspaces_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:common_ui/data/theme_colors.dart';
import 'package:file_picker/file_picker.dart';
import '../viewmodels/storage_view_model.dart';
import '../viewmodels/workspace_model.dart';

class WorkspacesPage extends StatefulWidget {
  const WorkspacesPage({super.key});

  @override
  State<WorkspacesPage> createState() => _WorkspacesPageState();
}

class _WorkspacesPageState extends State<WorkspacesPage> {
  @override
  void initState() {
    super.initState();
    // Sayfa açıldığında çalışma alanlarını güncel olarak çekiyoruz
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StorageViewModel>().fetchWorkspaces();
    });
  }

  // 🌟 YENİ: BULUT KLASÖRÜ SEÇME DİYALOGU
  void _pickRemoteFolder(
    BuildContext context,
    StorageViewModel viewModel,
    Function(int, String) onSelected,
  ) {
    showDialog(
      context: context,
      barrierColor: ThemeColors.background.withOpacity(0.5),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: AlertDialog(
          backgroundColor: ThemeColors.floatingPanelColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.cloud_rounded, color: ThemeColors.primary),
              const SizedBox(width: 10),
              Text(
                "Bulut Klasörü Seç",
                style: TextStyle(
                  color: ThemeColors.titleText,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 350,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Senkronize edilecek hedef bulut klasörünü seçin.",
                  style: TextStyle(color: ThemeColors.captionText),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: ThemeColors.background.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ThemeColors.titleText.withOpacity(0.05),
                      ),
                    ),
                    child: ListView.separated(
                      itemCount:
                          viewModel.allFolders.length + 1, // +1 Ana Dizin için
                      separatorBuilder: (c, i) => Divider(
                        height: 1,
                        color: ThemeColors.titleText.withOpacity(0.05),
                      ),
                      itemBuilder: (context, index) {
                        // İlk seçenek her zaman 'Ana Dizin' olsun
                        if (index == 0) {
                          return ListTile(
                            leading: const Icon(
                              Icons.cloud_circle_rounded,
                              color: Colors.blueAccent,
                              size: 28,
                            ),
                            title: Text(
                              "Ana Dizin",
                              style: TextStyle(
                                color: ThemeColors.titleText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              onSelected(0, "Ana Dizin");
                              Navigator.pop(ctx);
                            },
                          );
                        }

                        // Diğer klasörler
                        final folder = viewModel.allFolders[index - 1];
                        return ListTile(
                          leading: const Icon(
                            Icons.folder_rounded,
                            color: Colors.orangeAccent,
                            size: 28,
                          ),
                          title: Text(
                            folder.folderName,
                            style: TextStyle(
                              color: ThemeColors.titleText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            onSelected(folder.folderId, folder.folderName);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "İptal",
                style: TextStyle(
                  color: ThemeColors.captionText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 YENİ ÇALIŞMA ALANI BAĞLAMA DİYALOGU (MODAL - GLASSMORPHISM)
  void _showAddWorkspaceDialog(
    BuildContext context,
    StorageViewModel viewModel,
  ) {
    final nameController = TextEditingController();
    final pathController = TextEditingController();

    // Varsayılan hedef klasör değerleri
    int selectedRemoteFolderId = 0;
    String selectedRemoteFolderName = "Ana Dizin";
    bool autoSyncValue = true;

    showDialog(
      context: context,
      barrierColor: ThemeColors.background.withOpacity(0.5),
      barrierDismissible: false,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            backgroundColor: ThemeColors.floatingPanelColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 20,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ThemeColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_link_rounded,
                    color: ThemeColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "Yeni Çalışma Alanı Bağla",
                  style: TextStyle(
                    color: ThemeColors.titleText,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Yerel bir klasörü, Mostromo bulutundaki bir hedef klasörle senkronize edin.",
                      style: TextStyle(
                        color: ThemeColors.captionText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 1. Alan Adı
                    _buildDialogTextField(
                      label: "Çalışma Alanı Adı",
                      hint: "Örn: Mostromo Web Projesi",
                      controller: nameController,
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 16),

                    // 2. Yerel Klasör Yolu (Seçicili)
                    Text(
                      "Yerel Klasör Yolu",
                      style: TextStyle(
                        color: ThemeColors.titleText,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pathController,
                            readOnly: true,
                            style: TextStyle(
                              color: ThemeColors.titleText,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: "Klasör seçin...",
                              hintStyle: TextStyle(
                                color: ThemeColors.captionText.withOpacity(0.6),
                              ),
                              prefixIcon: Icon(
                                Icons.computer_rounded,
                                color: ThemeColors.captionText,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: ThemeColors.background.withOpacity(
                                0.5,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeColors.primary.withOpacity(
                              0.1,
                            ),
                            foregroundColor: ThemeColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            String? path = await FilePicker.platform
                                .getDirectoryPath(
                                  dialogTitle:
                                      'Senkronize Edilecek Yerel Klasörü Seçin',
                                );
                            if (path != null) {
                              setModalState(() {
                                pathController.text = path;
                                if (nameController.text.isEmpty) {
                                  nameController.text = path
                                      .split('/')
                                      .last
                                      .split('\\')
                                      .last;
                                }
                              });
                            }
                          },
                          child: const Icon(
                            Icons.folder_open_rounded,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. Bulut Hedef Klasörü (Butonlu Seçici)
                    Text(
                      "Bulut Hedef Klasörü",
                      style: TextStyle(
                        color: ThemeColors.titleText,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: ThemeColors.background.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cloud_queue_rounded,
                                  color: ThemeColors.captionText,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    selectedRemoteFolderName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: ThemeColors.titleText,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeColors.primary.withOpacity(
                              0.1,
                            ),
                            foregroundColor: ThemeColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            _pickRemoteFolder(context, viewModel, (id, name) {
                              setModalState(() {
                                selectedRemoteFolderId = id;
                                selectedRemoteFolderName = name;
                              });
                            });
                          },
                          child: const Icon(Icons.cloud_sync_rounded, size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 4. Otomatik Senkronizasyon Anahtarı
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ThemeColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ThemeColors.primary.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Anlık Senkronizasyon (Auto-Sync)",
                                  style: TextStyle(
                                    color: ThemeColors.titleText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Ctrl+S yapıldığında otomatik yüklenir.",
                                  style: TextStyle(
                                    color: ThemeColors.captionText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: autoSyncValue,
                            activeColor: Colors.green,
                            onChanged: (val) {
                              setModalState(() => autoSyncValue = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.all(24),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  "İptal",
                  style: TextStyle(
                    color: ThemeColors.captionText,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: ThemeColors.primary.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  if (nameController.text.trim().isEmpty ||
                      pathController.text.trim().isEmpty) {
                    return;
                  }

                  Navigator.pop(ctx);

                  await viewModel.createWorkspace(
                    name: nameController.text.trim(),
                    localPath: pathController.text.trim(),
                    remoteFolderId: selectedRemoteFolderId,
                    remoteFolderName: selectedRemoteFolderName,
                    autoSync: autoSyncValue,
                  );
                },
                child: const Text(
                  "Alanı Bağla",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: ThemeColors.titleText,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: ThemeColors.titleText, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: ThemeColors.captionText.withOpacity(0.5),
            ),
            prefixIcon: Icon(icon, color: ThemeColors.captionText, size: 20),
            filled: true,
            fillColor: ThemeColors.background.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<StorageViewModel>();
    final list = viewModel.workspaces;

    return Scaffold(
      backgroundColor: ThemeColors.background,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ÜST BAR (Başlık ve Ekle Butonu) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Geliştirici Çalışma Alanları",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.titleText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Yerel projelerinizi Mostromo Bulut dizinleri ile köprüleyin.",
                      style: TextStyle(
                        color: ThemeColors.captionText,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: ThemeColors.primary.withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _showAddWorkspaceDialog(context, viewModel),
                  icon: const Icon(Icons.add_box_rounded, size: 22),
                  label: const Text(
                    "Yeni Alan Bağla",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // --- DURUM BİLGİSİ (Ağdan dönen mesajlar için) ---
            if (viewModel.syncStatus.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: ThemeColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ThemeColors.primary.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: ThemeColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      viewModel.syncStatus,
                      style: TextStyle(
                        color: ThemeColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            // --- ANA İÇERİK ALANI ---
            Expanded(
              child: list.isEmpty
                  ? _buildEmptyState(context, viewModel)
                  : _buildWorkspaceGrid(list, viewModel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, StorageViewModel viewModel) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: ThemeColors.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: ThemeColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business_center_outlined,
                size: 80,
                color: ThemeColors.primary.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Bağlı Çalışma Alanı Yok",
              style: TextStyle(
                fontSize: 24,
                color: ThemeColors.titleText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "VS Code eklentinizin çalışabilmesi için yerel bir klasör bağlamalısınız.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: ThemeColors.captionText),
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: () => _showAddWorkspaceDialog(context, viewModel),
              icon: Icon(
                Icons.add_link_rounded,
                color: ThemeColors.primary,
                size: 24,
              ),
              label: Text(
                "İlk Köprüyü Şimdi Kur",
                style: TextStyle(
                  color: ThemeColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceGrid(
    List<WorkspaceItem> list,
    StorageViewModel viewModel,
  ) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 480,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.45,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return Container(
          decoration: BoxDecoration(
            color: ThemeColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ThemeColors.titleText.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ThemeColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.business_center_rounded,
                      color: ThemeColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.titleText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildPathRow(
                Icons.computer_rounded,
                "Yerel Dizin:",
                item.localPath,
              ),
              const SizedBox(height: 12),
              _buildPathRow(
                Icons.cloud_done_rounded,
                "Bulut Hedef:",
                item.remoteFolderName,
                iconColor: Colors.blueAccent,
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: ThemeColors.titleText.withOpacity(0.05),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 28,
                          child: Switch(
                            value: item.autoSync,
                            activeColor: Colors.green,
                            onChanged: (val) {
                              viewModel.toggleWorkspaceSync(item.id, val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.autoSync ? "Sync Aktif" : "Sync Pasif",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: item.autoSync
                                ? Colors.green
                                : ThemeColors.captionText,
                          ),
                        ),
                      ],
                    ),

                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierColor: ThemeColors.background.withOpacity(0.5),
                          builder: (ctx) => BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                            child: AlertDialog(
                              backgroundColor: ThemeColors.floatingPanelColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: const Text("Köprüyü Kaldır"),
                              content: Text(
                                "'${item.name}' çalışma alanını kaldırmak istiyor musunuz?\n\nNot: Yerel diskteki veya buluttaki dosyalarınız silinmez, sadece aradaki otomatik bağlantı kesilir.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text(
                                    "İptal",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    viewModel.deleteWorkspace(item.id);
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text("Kaldır"),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.link_off_rounded,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        "Kaldır",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPathRow(
    IconData icon,
    String label,
    String path, {
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: iconColor ?? ThemeColors.captionText.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ThemeColors.captionText,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            path,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: ThemeColors.titleText.withOpacity(0.9),
              fontFamily: 'Consolas',
            ),
          ),
        ),
      ],
    );
  }
}
