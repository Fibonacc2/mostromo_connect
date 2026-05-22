package com.example.mostromo_connect

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import java.io.File
import java.io.InputStream
import java.io.FileOutputStream
import android.util.Log
import android.webkit.MimeTypeMap
import android.content.ContentResolver

class MainActivity: FlutterActivity() {
    // Kanal adı 'mostromo_connect' için ayarlandı
    private val CHANNEL = "mostromo_connect/shareFile"
    private var sharedUris: List<Uri> = emptyList()
    private var hasPendingShare = false
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedFiles" -> {
                    handleGetSharedFiles(call, result)
                }
                "clearSharedFiles" -> {
                    handleClearSharedFiles(call, result)
                }
                "hasPendingShare" -> {
                    result.success(hasPendingShare)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, true)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent, false)
    }

    private fun handleIntent(intent: Intent, appAlreadyRunning: Boolean) {
        val action = intent.action
        val type = intent.type

        Log.d("ShareIntent", "Action: $action, Type: $type")

        // Tek dosya paylaşımı (HER TÜRÜ KABUL ET)
        if (Intent.ACTION_SEND == action && type != null) {
            val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            if (uri != null) {
                Log.d("ShareIntent", "Single file URI: $uri")
                sharedUris = listOf(uri)
                hasPendingShare = true
                
                if (appAlreadyRunning) {
                    notifyFlutterToNavigate()
                }
            }
        } 
        // Çoklu dosya paylaşımı (HER TÜRÜ KABUL ET)
        else if (Intent.ACTION_SEND_MULTIPLE == action && type != null) {
            val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            if (uris != null) {
                Log.d("ShareIntent", "Multiple files: ${uris.size}")
                sharedUris = uris
                hasPendingShare = true
                
                if (appAlreadyRunning) {
                    notifyFlutterToNavigate()
                }
            }
        }
    }

    private fun notifyFlutterToNavigate() {
        try {
            methodChannel?.invokeMethod("navigateToUpload", null)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun handleGetSharedFiles(call: MethodCall, result: MethodChannel.Result) {
        try {
            val filePaths = mutableListOf<String>()
            
            Log.d("ShareIntent", "Processing ${sharedUris.size} shared files")
            
            for (uri in sharedUris) {
                val filePath = getFilePathFromUri(uri)
                if (filePath != null) {
                    Log.d("ShareIntent", "File path: $filePath")
                    filePaths.add(filePath)
                } else {
                    Log.e("ShareIntent", "Failed to get path for URI: $uri")
                }
            }
            
            result.success(filePaths)
            hasPendingShare = false
            
        } catch (e: Exception) {
            Log.e("ShareIntent", "Error getting shared files: ${e.message}")
            result.error("SHARED_FILES_ERROR", "Dosyalar alınamadı: ${e.message}", null)
        }
    }

    private fun getFilePathFromUri(uri: Uri): String? {
        return try {
            when {
                uri.scheme == "content" -> getFileFromContentUri(uri)
                uri.scheme == "file" -> uri.path
                else -> copyFileToCache(uri)
            }
        } catch (e: Exception) {
            Log.e("ShareIntent", "Error getting file path: ${e.message}")
            null
        }
    }

    private fun getFileFromContentUri(uri: Uri): String? {
        return try {
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            if (inputStream != null) {
                val cacheDir = applicationContext.cacheDir
                // Storage uygulaması olduğu için uzantıyı dinamik alıyoruz
                val ext = getFileExtension(uri)
                val fileName = "shared_${System.currentTimeMillis()}.$ext"
                val outputFile = File(cacheDir, fileName)
                
                FileOutputStream(outputFile).use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
                inputStream.close()
                
                outputFile.absolutePath
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e("ShareIntent", "Error copying content URI: ${e.message}")
            null
        }
    }

    // ✅ GÜNCELLENDİ: Storage için daha kapsamlı uzantı bulucu
    private fun getFileExtension(uri: Uri): String {
        return try {
            val mimeType = contentResolver.getType(uri)
            if (mimeType != null) {
                // Android'in kendi MimeType haritasını kullan
                MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType) ?: "file"
            } else {
                // MimeType yoksa dosya adından çıkarmaya çalış
                val path = uri.path
                if (path != null && path.contains(".")) {
                    path.substring(path.lastIndexOf(".") + 1)
                } else {
                    "file"
                }
            }
        } catch (e: Exception) {
            "file"
        }
    }

    private fun copyFileToCache(uri: Uri): String? {
        return try {
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            if (inputStream != null) {
                val cacheDir = applicationContext.cacheDir
                val fileName = "shared_${System.currentTimeMillis()}_unknown"
                val outputFile = File(cacheDir, fileName)
                
                FileOutputStream(outputFile).use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
                inputStream.close()
                outputFile.absolutePath
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun handleClearSharedFiles(call: MethodCall, result: MethodChannel.Result) {
        sharedUris = emptyList()
        hasPendingShare = false
        clearCacheFiles() 
        result.success(null)
    }

    private fun clearCacheFiles() {
        try {
            val cacheDir = applicationContext.cacheDir
            if (cacheDir.exists() && cacheDir.isDirectory) {
                val files = cacheDir.listFiles()
                files?.forEach { file ->
                    if (file.name.startsWith("shared_")) {
                        file.delete()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("ShareIntent", "Error clearing cache: ${e.message}")
        }
    }
}