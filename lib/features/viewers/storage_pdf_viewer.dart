// lib/views/pages/pdf_viewer_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:shared_core/models/file_model.dart';

class PdfViewerPage extends StatefulWidget {
  final FileItem file;
  const PdfViewerPage({super.key, required this.file});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final PdfViewerController _pdfController = PdfViewerController();

  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = true;
  String? _error;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final response = await http.get(Uri.parse(widget.file.fileUrl));

      if (response.statusCode == 200) {
        _pdfBytes = response.bodyBytes;
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        throw Exception("HTTP ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Hata: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openExternally() async {
    if (_pdfBytes == null) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${widget.file.fileName}';
      final file = File(filePath);
      await file.writeAsBytes(_pdfBytes!);
      await OpenFilex.open(filePath);
    } catch (e) {
      debugPrint("Açma hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.fileName, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: _isLoading ? null : _openExternally,
          ),
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    return PdfViewer.data(
      _pdfBytes!,
      // ✅ sourceName zorunlu bir parametredir, dosya adını veriyoruz.
      sourceName: widget.file.fileName,
      controller: _pdfController,
      params: PdfViewerParams(
        // ✅ onDocumentLoaded hatası yerine en garanti yol: onViewerReady
        // Bu fonksiyon döküman yüklendiğinde tetiklenir ve bize dökümanı verir.
        onViewerReady: (controller, document) {
          setState(() {
            _totalPages = document.pages.length;
          });
        },
        // Sayfa değişimlerini dinlemek için:
        onPageChanged: (page) {
          if (page != null) {
            setState(() {
              _currentPage = page;
            });
          }
        },
        // Masaüstü için zoom sınırı
        maxScale: 8.0,
      ),
    );
  }
}



/*
import 'dart:io'; // ✅ YENİ: Dosya yazma işlemleri için (File)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart'; // ✅ YENİ: Temp klasörü için
import 'package:open_filex/open_filex.dart'; // ✅ YENİ: "Birlikte Aç" için
import 'package:shared_core/models/file_model.dart';

class PdfViewerPage extends StatefulWidget {
  final FileItem file;
  const PdfViewerPage({super.key, required this.file});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  PdfControllerPinch? _pdfController;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = true;
  String? _error;

  // ✅ YENİ: PDF'i hafızada (RAM) tutmak için
  // (Bunu 'Birlikte Aç' için dosyaya yazarken kullanacağız)
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final byteData = await NetworkAssetBundle(
        Uri.parse(widget.file.fileUrl),
      ).load(widget.file.fileUrl);

      final bytes = byteData.buffer.asUint8List();

      // ✅ YENİ: İndirilen byte'ları state'e kaydet
      _pdfBytes = bytes;

      _pdfController = PdfControllerPinch(
        document: PdfDocument.openData(bytes),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "PDF yüklenirken hata oluştu: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  // ✅ YENİ: "Birlikte Aç" Fonksiyonu
  Future<void> _openExternally() async {
    // PDF henüz yüklenmediyse (veya hata varsa) işlem yapma
    if (_pdfBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dosya henüz yüklenmedi.')));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Dosya hazırlanıyor...')));

    try {
      // 1. Geçici (temp) klasörün yolunu bul
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${widget.file.fileName}';

      // 2. Hafızadaki PDF byte'larını bu yola fiziksel bir dosya olarak yaz
      final file = File(filePath);
      await file.writeAsBytes(_pdfBytes!);

      // 3. open_filex'e bu dosyayı açmasını söyle
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya açılamadı: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
          // ✅ YENİ: "Birlikte Aç" Butonu
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Birlikte Aç',
            // Butonu, PDF yüklendikten sonra aktif et
            onPressed: _isLoading ? null : _openExternally,
          ),

          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 5.0,
          children: [
            Text('Dosya Hazırlanıyor...'),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      );
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

    return PdfViewPinch(
      controller: _pdfController!,
      onPageChanged: (page) {
        setState(() {
          _currentPage = page;
        });
      },
      onDocumentLoaded: (doc) {
        setState(() {
          _totalPages = doc.pagesCount;
        });
      },
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(
          child: Column(
            children: [
              Text('Dosya Hazırlanıyor...'),
              CircularProgressIndicator(),
            ],
          ),
        ),
        pageLoaderBuilder: (_) => const Center(
          child: Column(
            children: [
              Text(
                'Dosya Hazırlanıyor...',
                style: TextStyle(color: Colors.white),
              ),
              CircularProgressIndicator(),
            ],
          ),
        ),
        errorBuilder: (_, error) =>
            Center(child: Text('PDF gösterilirken hata oluştu: $error')),
      ),
    );
  }
}
 */