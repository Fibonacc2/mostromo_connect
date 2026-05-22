// lib/features/storage/models/workspace_model.dart

class WorkspaceItem {
  final String id;
  final String name;
  final String localPath;
  final int remoteFolderId;
  final String remoteFolderName;
  final bool autoSync;

  WorkspaceItem({
    required this.id,
    required this.name,
    required this.localPath,
    required this.remoteFolderId,
    required this.remoteFolderName,
    this.autoSync = true,
  });

  // ✅ YENİ: Anlık UI güncellemesi için copyWith metodu eklendi
  WorkspaceItem copyWith({
    String? id,
    String? name,
    String? localPath,
    int? remoteFolderId,
    String? remoteFolderName,
    bool? autoSync,
  }) {
    return WorkspaceItem(
      id: id ?? this.id,
      name: name ?? this.name,
      localPath: localPath ?? this.localPath,
      remoteFolderId: remoteFolderId ?? this.remoteFolderId,
      remoteFolderName: remoteFolderName ?? this.remoteFolderName,
      autoSync: autoSync ?? this.autoSync,
    );
  }

  factory WorkspaceItem.fromJson(Map<String, dynamic> json) {
    return WorkspaceItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'İsimsiz Çalışma Alanı',
      localPath: json['localPath']?.toString() ?? '',
      remoteFolderId: json['remoteFolderId'] is int
          ? json['remoteFolderId']
          : int.tryParse(json['remoteFolderId']?.toString() ?? '0') ?? 0,
      remoteFolderName: json['remoteFolderName']?.toString() ?? '',
      autoSync:
          json['autoSync'] == true ||
          json['autoSync'] == 1 ||
          json['autoSync'] == '1',
    );
  }
}
