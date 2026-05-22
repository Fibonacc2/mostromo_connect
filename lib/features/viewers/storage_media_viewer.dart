import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Gerekli modelleri ve servisleri import edin
import 'package:shared_core/models/file_model.dart';
import 'package:shared_core/services/file_download_service.dart';
import 'package:common_ui/views/widgets/custom_video_player.dart'; // Mevcut video player'ınızı varsayıyorum

class StorageMediaViewerPage extends StatefulWidget {
  // Sadece tek bir FileItem alacak şekilde güncellendi
  final FileItem item;

  const StorageMediaViewerPage({super.key, required this.item});

  @override
  State<StorageMediaViewerPage> createState() => _StorageMediaViewerPageState();
}

class _StorageMediaViewerPageState extends State<StorageMediaViewerPage> {
  // Yakınlaştırma için TransformationController hala gerekli
  late final TransformationController _transformController;
  bool _isZoomed = false;

  // Mevcut FileItem'ı kolayca almak için getter
  FileItem get _currentFileItem => widget.item;
  bool get _isCurrentVideo => _currentFileItem.fileType == "media/video";

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _transformController.addListener(_onZoomUpdate);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onZoomUpdate);
    _transformController.dispose();
    super.dispose();
  }

  // Zoom dinleyicisi
  void _onZoomUpdate() {
    final double scale = _transformController.value.getMaxScaleOnAxis();
    final bool currentlyZoomed = (scale - 1.0).abs() > 0.01;

    if (currentlyZoomed != _isZoomed) {
      setState(() {
        _isZoomed = currentlyZoomed;
      });
    }
  }

  // İndirme fonksiyonu
  void _downloadCurrentFile() {
    FileDownloadService.requestDownload(_currentFileItem);
  }

  // Bilgi paneli fonksiyonu
  void _showInfoPanel() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _currentFileItem.fileName,
          style: const TextStyle(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tür: ${_currentFileItem.fileType}'),
            Text('Boyut: ${_formatFileSize(_currentFileItem.fileSize)}'),
            Text('Oluşturulma: ${_formatDate(_currentFileItem.createdAt)}'),
            Text('Uzantı: ${_currentFileItem.fileExtension.toUpperCase()}'),
            if (_currentFileItem.webpUrl != null) const Text('WebP: Mevcut'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildMediaContent(),
          _buildBackButton(),
          _buildTopRightButtons(),
        ],
      ),
    );
  }

  // PageView kaldırıldı, doğrudan tek bir medya widget'ı oluşturuluyor
  Widget _buildMediaContent() {
    final item = widget.item;

    if (item.fileType == "media/video") {
      return CustomVideoPlayer(
        key: ValueKey(item.fileUrl), // URL'yi anahtar olarak kullan
        videoUrl: item.fileUrl,
        posterUrl: item.webpExtraUrl,
        autoPlay: true, // Sayfa tek olduğu için oto-başlat
        looping: true,
        fit: BoxFit.contain,
      );
    } else if (item.fileType == "media/img") {
      return _buildImageContent(item, _transformController);
    } else {
      return _buildErrorWidget('Desteklenmeyen dosya türü');
    }
  }

  Widget _buildImageContent(
    FileItem mediaItem,
    TransformationController controller,
  ) {
    final imageUrl =
        mediaItem.fileUrl; //mediaItem.webpUrl ?? mediaItem.fileUrl;
    if (imageUrl.isEmpty) return _buildErrorWidget('Resim URL\'si bulunamadı');

    return InteractiveViewer(
      transformationController: controller,
      panEnabled: true,
      minScale: 1.0,
      maxScale: 4.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          errorWidget: (context, url, error) =>
              _buildErrorWidget('Resim yüklenemedi'),
          progressIndicatorBuilder: (context, url, progress) {
            return Center(
              child: CircularProgressIndicator(
                value: progress.progress,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((255 * 0.4).round()),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
    );
  }

  // Sayaç kaldırıldı
  Widget _buildTopRightButtons() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 10,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _isZoomed ? 0.0 : 1.0,
        child: Row(
          children: [
            // İndir Butonu
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((255 * 0.4).round()),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                onPressed: _downloadCurrentFile,
              ),
            ),
            const SizedBox(width: 8),

            // Bilgi Butonu
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((255 * 0.4).round()),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white),
                onPressed: _showInfoPanel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, size: 60, color: Colors.white),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  // --- YARDIMCI METODLAR ---

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const units = ["B", "KB", "MB", "GB"];
    final digitGroups = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, digitGroups)).toStringAsFixed(1)} ${units[digitGroups]}";
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd.MM.yyyy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }
}
