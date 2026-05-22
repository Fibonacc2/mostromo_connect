// apps/mostromo_connect/lib/features/storage/services/local_bridge_server.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:mostromo_connect/features/storage/viewmodels/storage_view_model.dart';

class LocalBridgeServer {
  final StorageViewModel storageViewModel;
  HttpServer? _server;
  bool _isRunning = false;

  LocalBridgeServer({required this.storageViewModel});

  Future<void> start() async {
    if (_isRunning) return;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 4545);
      _isRunning = true;
      debugPrint("🚀 Mostromo Local Bridge çalışıyor: http://127.0.0.1:4545");

      _server!.listen((HttpRequest request) async {
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        request.response.headers.add(
          'Access-Control-Allow-Methods',
          'GET, POST, OPTIONS',
        );
        request.response.headers.add(
          'Access-Control-Allow-Headers',
          'Origin, Content-Type, X-Auth-Token',
        );

        if (request.method == 'OPTIONS') {
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          return;
        }

        final path = request.uri.path;

        if (path == '/status' && request.method == 'GET') {
          _sendJsonResponse(request, {
            'isConnected': true,
            'isUploading': storageViewModel.isUploading,
            'progress': storageViewModel.uploadProgress,
            'currentFile': storageViewModel.currentlyUploadingName,
            'queueCount': storageViewModel.pendingUploads.length,
          });
        } else if (path == '/sync' && request.method == 'POST') {
          await _handleSyncRequest(request);
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });
    } catch (e) {
      debugPrint("❌ Yerel sunucu başlatılamadı: $e");
    }
  }

  Future<void> _handleSyncRequest(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final Map<String, dynamic> data = jsonDecode(body);

      final String? filePath = data['filePath'];
      final bool isManual = data['isManual'] == true;

      if (filePath == null || filePath.isEmpty) {
        _sendJsonResponse(request, {
          'success': false,
          'message': 'Yol eksik.',
        }, statusCode: HttpStatus.badRequest);
        return;
      }

      final normalizedPath = filePath.replaceAll('\\', '/');
      final matchedWorkspace = storageViewModel.findWorkspaceByPath(
        normalizedPath,
      );

      if (matchedWorkspace == null) {
        _sendJsonResponse(request, {
          'success': false,
          'message': 'Çalışma alanı bulunamadı.',
        }, statusCode: HttpStatus.notFound);
        return;
      }

      if (!matchedWorkspace.autoSync && !isManual) {
        _sendJsonResponse(request, {
          'success': true,
          'ignored': true,
          'message': 'Auto-Sync kapalı.',
        });
        return;
      }

      final entityType = FileSystemEntity.typeSync(normalizedPath);
      if (entityType == FileSystemEntityType.notFound) {
        _sendJsonResponse(request, {
          'success': false,
          'message': 'Yerel diskte bulunamadı.',
        }, statusCode: HttpStatus.notFound);
        return;
      }

      String wLocalPath = matchedWorkspace.localPath.replaceAll('\\', '/');
      if (wLocalPath.endsWith('/'))
        wLocalPath = wLocalPath.substring(0, wLocalPath.length - 1);

      // 🌟 SİHİRLİ DOKUNUŞ: Büyük/Küçük harfe duyarsız yol ayıklayıcı (C:/ vs c:/ sorununu çözer!)
      String getRelativePath(String fullPath) {
        final fLower = fullPath.toLowerCase();
        final wLower = wLocalPath.toLowerCase();
        if (fLower.startsWith(wLower)) {
          String rel = fullPath.substring(wLocalPath.length);
          if (rel.startsWith('/')) rel = rel.substring(1);
          return rel;
        }
        return '';
      }

      List<File> filesToUpload = [];

      if (entityType == FileSystemEntityType.directory) {
        String dirRelativePath = getRelativePath(normalizedPath);

        // Ana klasörü de oluşturulacaklar listesine ekle
        storageViewModel.addProgrammaticUpload(
          file: XFile(normalizedPath),
          targetFolderId: matchedWorkspace.remoteFolderId,
          targetFolderName: dirRelativePath.isEmpty
              ? matchedWorkspace.remoteFolderName
              : dirRelativePath.split('/').last,
          isFolder: true,
          relativePathForTree: dirRelativePath,
        );

        final dir = Directory(normalizedPath);
        final entities = dir.listSync(recursive: true);
        for (var entity in entities) {
          if (entity is File) {
            filesToUpload.add(entity);
          } else if (entity is Directory) {
            // Alt klasörleri de ağaç yapısına kaydet
            String subDirRel = getRelativePath(
              entity.path.replaceAll('\\', '/'),
            );
            storageViewModel.addProgrammaticUpload(
              file: XFile(entity.path),
              targetFolderId: matchedWorkspace.remoteFolderId,
              targetFolderName: subDirRel.split('/').last,
              isFolder: true,
              relativePathForTree: subDirRel,
            );
          }
        }
      } else if (entityType == FileSystemEntityType.file) {
        filesToUpload.add(File(normalizedPath));
      }

      if (filesToUpload.isEmpty) {
        _sendJsonResponse(request, {
          'success': false,
          'message': 'Klasör boş veya gönderilecek dosya bulunamadı.',
        });
        return;
      }

      for (var file in filesToUpload) {
        String entityNormPath = file.path.replaceAll('\\', '/');
        String relativeFilePath = getRelativePath(entityNormPath);

        String relativeDir = '';
        if (relativeFilePath.contains('/')) {
          relativeDir = relativeFilePath.substring(
            0,
            relativeFilePath.lastIndexOf('/'),
          );
        }

        storageViewModel.addProgrammaticUpload(
          file: XFile(entityNormPath),
          targetFolderId: matchedWorkspace.remoteFolderId,
          targetFolderName: relativeDir.isEmpty
              ? matchedWorkspace.remoteFolderName
              : relativeDir.split('/').last,
          isFolder: false,
          relativePathForTree: relativeDir,
        );
      }

      storageViewModel.startUpload();

      final message = filesToUpload.length > 1
          ? '${filesToUpload.length} dosya klasörleriyle birlikte kuyruğa alındı.'
          : '${filesToUpload.first.uri.pathSegments.last} kuyruğa alındı.';

      _sendJsonResponse(request, {
        'success': true,
        'workspace': matchedWorkspace.name,
        'message': message,
      });
    } catch (e) {
      _sendJsonResponse(request, {
        'success': false,
        'message': 'Hata: $e',
      }, statusCode: HttpStatus.internalServerError);
    }
  }

  void _sendJsonResponse(
    HttpRequest request,
    Map<String, dynamic> responseData, {
    int statusCode = HttpStatus.ok,
  }) {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(responseData));
    request.response.close();
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    await _server?.close(force: true);
    _isRunning = false;
    debugPrint("🛑 Mostromo Local Bridge durduruldu.");
  }
}
