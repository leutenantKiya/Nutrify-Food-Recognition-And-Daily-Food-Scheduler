import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import 'hive_service.dart';

class ApiService {
  ApiService._();

  /// Baca dari Hive (override user) → fallback ke dotenv
  static String _secret(String hiveKey, String dotenvKey, String fallback) {
    final fromHive = HiveService.secretBox.get(hiveKey) as String?;
    if (fromHive != null && fromHive.isNotEmpty) return fromHive;
    return dotenv.env[dotenvKey] ?? fallback;
  }

  static String get _apiKey =>
      _secret(AppConstants.keyHfApiKey, 'HUGGINGFACE_API_KEY', '');
  static String get _modelId =>
      _secret(AppConstants.keyHfModelId, 'HUGGINGFACE_MODEL_ID',
          'deepseek-ai/DeepSeek-V4-Pro:novita');
  static String get _baseUrl =>
      _secret(AppConstants.keyHfBaseUrl, 'HUGGINGFACE_BASE_URL',
          'https://router.huggingface.co/v1/chat/completions');
  static String get photoUrl =>
      _secret(AppConstants.keyPhotoUrl, 'PHOTO_DETECTION_URL', '');

  static bool get _isOpenRouter => _apiKey.startsWith('sk-or-');

  static String get _effectiveBaseUrl {
    final base = _baseUrl;
    if (_isOpenRouter && base == 'https://router.huggingface.co/v1/chat/completions') {
      return 'https://openrouter.ai/api/v1/chat/completions';
    }
    return base;
  }

  static String get _effectiveModelId {
    final model = _modelId;
    if (_isOpenRouter && (model == 'deepseek-ai/DeepSeek-V4-Pro:novita' || model.isEmpty)) {
      return 'google/gemini-2.5-flash';
    }
    return model;
  }

  /// Kirim pesan ke AI via HuggingFace atau OpenRouter (Messages/Chat format)
  static Future<String> sendChatMessage({
    required List<Map<String, String>> messages,
    String? userContext,
  }) async {
    final url = Uri.parse(_effectiveBaseUrl);

    final allMessages = <Map<String, String>>[
      {'role': 'system', 'content': AppConstants.aiSystemPrompt},
      if (userContext != null)
        {'role': 'system', 'content': 'Data pengguna: $userContext'},
      ...messages,
    ];

    // Hanya retry untuk error SEBELUM request sampai ke server (koneksi putus)
    // JANGAN retry TimeoutException — artinya server sudah menerima & sedang proses,
    // jika diretry = kirim request baru = usage terpakai 2x tanpa dapat response
    const maxRetry = 2;

    for (int attempt = 1; attempt <= maxRetry; attempt++) {
      debugPrint('[API] Attempt $attempt/$maxRetry...');
      try {
        final headers = {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        };
        if (_isOpenRouter) {
          headers['HTTP-Referer'] = 'https://nutrify.oyencar.online/analyze_meal';
          headers['X-Title'] = 'NutriFy';
        }

        final response = await http
            .post(
              url,
              headers: headers,
              body: jsonEncode({
                'model': _effectiveModelId,
                'messages': allMessages,
                'max_tokens': 4096,
                'temperature': 0.7,
                'stream': false,
              }),
            )
            .timeout(const Duration(seconds: 90)); // 90s: DeepSeek V4 butuh waktu berpikir

        debugPrint('[API] Status: ${response.statusCode}');
        debugPrint('[API] Body (300 char): ${response.body.substring(0, response.body.length.clamp(0, 300))}...');
        await _saveLastResponse(response.statusCode, response.body);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final message = data['choices']?[0]?['message'];
          final finishReason = data['choices']?[0]?['finish_reason'] ?? '';

          final content = (message?['content'] as String? ?? '').trim();
          final reasoningContent =
              (message?['reasoning_content'] as String? ?? '').trim();

          debugPrint('[AI] finish_reason: $finishReason');
          debugPrint('[AI] content length: ${content.length}');
          debugPrint('[AI] reasoning_content length: ${reasoningContent.length}');

          // Peringatan jika terpotong karena kuota token habis
          if (finishReason == 'length') {
            debugPrint('[AI] ⚠️ Response terpotong (finish_reason: length)!');
          }

          final result = content.isNotEmpty ? content : reasoningContent;
          return result.isNotEmpty ? result : 'Maaf, AI tidak memberikan respons. Coba lagi.';

        } else {
          // Error permanen → langsung return, jangan retry
          if ([401, 403, 404].contains(response.statusCode)) {
            return _handleErrorStatus(response.statusCode, response.body);
          }
          // 429/500/503 → boleh retry karena request belum diproses
          if (attempt < maxRetry) {
            final waitSec = attempt * 5;
            debugPrint('[API] HTTP ${response.statusCode}, retry dalam $waitSec detik...');
            await Future.delayed(Duration(seconds: waitSec));
            continue;
          }
          return _handleErrorStatus(response.statusCode, response.body);
        }

      } catch (e) {
        final err = e.toString();
        debugPrint('[API] Exception attempt $attempt: $err');

        // ⚠️ TimeoutException = server sudah menerima request dan sedang proses
        // JANGAN retry karena akan membuang usage dua kali
        if (err.contains('TimeoutException')) {
          return 'AI membutuhkan lebih dari 90 detik untuk merespons.\n'
              'Request sudah sampai ke server — silakan tunggu sebentar lalu coba lagi.\n'
              '(Keterangan: usage token sudah terpakai di server)';
        }

        // SocketException / connection abort = koneksi terputus SEBELUM sampai server → aman diretry
        final isPreServerError = err.contains('connection abort') ||
            err.contains('Connection reset') ||
            err.contains('SocketException') ||
            err.contains('Failed host lookup');

        if (isPreServerError && attempt < maxRetry) {
          final waitSec = attempt * 3;
          debugPrint('[API] Koneksi terputus (pre-server), retry dalam $waitSec detik...');
          await Future.delayed(Duration(seconds: waitSec));
          continue;
        }

        if (isPreServerError) {
          return 'Gagal terhubung ke server AI. Pastikan koneksi internet stabil lalu coba lagi.';
        }

        return 'Terjadi kesalahan: $e';
      }
    }
    return 'Gagal menghubungi AI. Silakan coba lagi.';

  }

  /// Terjemahkan kode error menjadi pesan Indonesia yang ramah
  static String _handleErrorStatus(int statusCode, String body) {
    try {
      final json = jsonDecode(body);
      if (json['error'] != null) {
        final errorMsg = json['error']['message'] ?? json['error']['code']?.toString();
        if (errorMsg != null && errorMsg.toString().isNotEmpty) {
          return 'Error ($statusCode): $errorMsg';
        }
      }
    } catch (_) {}

    switch (statusCode) {
      case 401:
        return 'API Key tidak valid. Silakan periksa konfigurasi di menu pengaturan rahasia.';
      case 403:
        return 'Akses ditolak atau limit kuota habis. Silakan periksa saldo/izin token Anda.';
      case 404:
        return 'Model tidak ditemukan. Silakan periksa ID Model di pengaturan.';
      case 429:
        return 'Terlalu banyak permintaan. Silakan tunggu sebentar lalu coba lagi.';
      case 503:
        return 'Model sedang dimuat atau server sibuk. Silakan coba lagi dalam beberapa saat.';
      default:
        return 'Gagal mendapatkan respons dari AI (Status $statusCode). '
            'Silakan coba lagi.';
    }
  }

  /// Simpan raw response API ke file last_response.txt
  static Future<void> _saveLastResponse(int statusCode, String body) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/last_response.txt');
      final timestamp = DateTime.now().toIso8601String();
      final content = '[$timestamp] Status: $statusCode\n\n$body\n';
      await file.writeAsString(content);
      debugPrint('[API] Response disimpan ke: ${file.path}');
    } catch (e) {
      debugPrint('[API] Gagal menyimpan response: $e');
    }
  }

  /// Upload foto untuk deteksi ingredient dan dapatkan analisis meal berupa JSON
  static Future<Map<String, dynamic>> uploadPhotoForDetection({
    required Uint8List imageBytes,
    String filename = 'photo.jpg',
  }) async {
    if (photoUrl.isEmpty) {
      throw Exception('URL deteksi foto belum dikonfigurasi di .env');
    }

    final url = Uri.parse(photoUrl);
    final request = http.MultipartRequest('POST', url);

    request.files.add(
      http.MultipartFile.fromBytes(
        'img',
        imageBytes,
        filename: filename,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    try {
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          throw Exception('Format respons server tidak didukung.');
        }
      } else {
        throw Exception(
            'Gagal menganalisis makanan (Status ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Kesalahan analisis foto: $e');
    }
  }
}
