import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Thrown when every model on the alternative provider failed.
class AlternativeAiException implements Exception {
  final int? statusCode;
  final String message;

  AlternativeAiException(this.message, {this.statusCode});

  @override
  String toString() => 'AlternativeAiException($statusCode): $message';
}

/// Vision/OCR extraction through any OpenAI-compatible `chat/completions`
/// endpoint. Defaults to OpenRouter, which can route to many vision models
/// (Qwen-VL, Llama 4, GPT-4o, Claude…) and accepts both images and PDFs.
///
/// Configure in `.env`:
///   ALT_AI_API_KEY=sk-or-...                     (required to enable)
///   ALT_AI_BASE_URL=https://openrouter.ai/api/v1 (optional)
///   ALT_AI_MODELS=nvidia/nemotron-3.5-super-vl:free,openrouter/free (optional, comma separated, tried in order)
///
/// `OPENROUTER_API_KEY` is accepted as an alias for `ALT_AI_API_KEY`.
/// Groq / OpenAI / Together etc. work too by changing the base URL and models
/// (note: only providers that accept `file` parts can read PDFs).
class AlternativeVisionAiService {
  final String apiKey;
  final String baseUrl;
  final List<String> models;
  final http.Client? httpClient;
  final Duration timeout;

  static const String defaultBaseUrl = 'https://openrouter.ai/api/v1';

  /// Free (`:free`) OpenRouter vision models, tried in order. The free roster
  /// changes often; override with ALT_AI_MODELS in .env.
  static const List<String> defaultModels = [
    'nvidia/nemotron-3.5-super-vl:free',
    'google/gemma-4-31b-it:free',
    'google/gemma-4-26b-a4b-it:free',
    'openrouter/free',
  ];

  AlternativeVisionAiService({
    required this.apiKey,
    this.baseUrl = defaultBaseUrl,
    this.models = defaultModels,
    this.httpClient,
    this.timeout = const Duration(seconds: 45),
  });

  bool get isOpenRouter => baseUrl.contains('openrouter.ai');

  /// Builds the service from `.env` / `--dart-define`; returns null when no key is configured.
  static AlternativeVisionAiService? fromEnvironment({http.Client? httpClient}) {
    String? read(String name) {
      try {
        if (dotenv.isInitialized) {
          final v = dotenv.maybeGet(name);
          if (v != null && v.trim().isNotEmpty) return v.trim();
        }
      } catch (_) {}
      return null;
    }

    const defineKey = String.fromEnvironment('ALT_AI_API_KEY', defaultValue: '');
    final key = read('ALT_AI_API_KEY') ?? read('OPENROUTER_API_KEY') ?? (defineKey.isNotEmpty ? defineKey : null);
    if (key == null) return null;

    final modelsRaw = read('ALT_AI_MODELS');
    final models = modelsRaw == null
        ? defaultModels
        : modelsRaw.split(',').map((m) => m.trim()).where((m) => m.isNotEmpty).toList();

    return AlternativeVisionAiService(
      apiKey: key,
      baseUrl: (read('ALT_AI_BASE_URL') ?? defaultBaseUrl).replaceAll(RegExp(r'/+$'), ''),
      models: models.isEmpty ? defaultModels : models,
      httpClient: httpClient,
    );
  }

  /// Sends the document + prompt and returns the decoded JSON object.
  Future<Map<String, dynamic>> extractJson({
    required String prompt,
    required Uint8List fileBytes,
    required String mimeType,
    required String fileName,
  }) async {
    if (isQuotaExhausted) {
      throw AlternativeAiException('Alternative AI daily quota exhausted', statusCode: 429);
    }
    final dataUrl = 'data:$mimeType;base64,${base64Encode(fileBytes)}';
    final Map<String, dynamic> filePart = mimeType == 'application/pdf'
        ? {
            'type': 'file',
            'file': {'filename': fileName, 'file_data': dataUrl},
          }
        : {
            'type': 'image_url',
            'image_url': {'url': dataUrl, 'detail': 'high'},
          };

    final client = httpClient ?? http.Client();
    int? lastStatus;
    String lastBody = '';

    try {
      for (final model in models) {
        final payload = <String, dynamic>{
          'model': model,
          'temperature': 0,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                filePart,
              ],
            },
          ],
        };

        // One retry on transient errors per model, then move on.
        for (int attempt = 0; attempt < 2; attempt++) {
          http.Response response;
          try {
            response = await client
                .post(
                  Uri.parse('$baseUrl/chat/completions'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $apiKey',
                    if (isOpenRouter) 'X-Title': 'Smart Medi',
                  },
                  body: jsonEncode(payload),
                )
                .timeout(timeout);
          } on TimeoutException {
            lastStatus = 504;
            lastBody = 'Timeout';
            continue;
          } catch (e) {
            lastStatus = 503;
            lastBody = e.toString();
            continue;
          }

          lastStatus = response.statusCode;
          lastBody = response.body;
          if (kDebugMode) {
            debugPrint('[AltVisionAI] model=$model HTTP ${response.statusCode}');
          }

          if (response.statusCode == 200) {
            try {
              return _parseResponse(response.body);
            } on AlternativeAiException {
              break; // malformed output from this model -> try the next model
            }
          }
          if (response.statusCode == 401 || response.statusCode == 403) {
            // Bad key: no other model will work either.
            throw AlternativeAiException('Alternative AI key rejected', statusCode: response.statusCode);
          }
          if (response.statusCode == 429 && _isAccountQuotaExhausted(response.body)) {
            // Daily/account quota used up: every model will fail, so park this
            // provider until the quota resets and let the caller switch to Gemini.
            _exhaustedUntil = _resetTime(response.headers);
            debugPrint('[AltVisionAI] Daily quota exhausted; skipping until $_exhaustedUntil');
            throw AlternativeAiException('Alternative AI daily quota exhausted', statusCode: 429);
          }
          if (response.statusCode >= 500 || (response.statusCode == 429 && attempt == 0)) {
            await Future<void>.delayed(const Duration(milliseconds: 1500));
            continue;
          }
          break; // 400/402/404/429-again -> next model
        }
      }
    } finally {
      if (httpClient == null) client.close();
    }

    throw AlternativeAiException(
      kDebugMode ? 'All alternative models failed: $lastBody' : 'All alternative models failed',
      statusCode: lastStatus,
    );
  }

  /// Set when the provider reports its daily/account quota is used up.
  static DateTime? _exhaustedUntil;

  static bool get isQuotaExhausted => _exhaustedUntil != null && DateTime.now().isBefore(_exhaustedUntil!);

  @visibleForTesting
  static void resetQuotaState() => _exhaustedUntil = null;

  static bool _isAccountQuotaExhausted(String body) {
    final b = body.toLowerCase();
    return b.contains('per-day') || b.contains('per day') || b.contains('daily') || b.contains('free-models-per');
  }

  /// OpenRouter sends X-RateLimit-Reset as epoch milliseconds; default to 1 hour.
  static DateTime _resetTime(Map<String, String> headers) {
    final raw = headers['x-ratelimit-reset'];
    final ms = raw == null ? null : int.tryParse(raw);
    if (ms != null && ms > 0) {
      final t = DateTime.fromMillisecondsSinceEpoch(ms);
      if (t.isAfter(DateTime.now())) return t;
    }
    return DateTime.now().add(const Duration(hours: 1));
  }

  static Map<String, dynamic> _parseResponse(String body) {
    final decoded = jsonDecode(body);
    final choices = decoded is Map ? decoded['choices'] : null;
    if (choices is! List || choices.isEmpty) {
      throw AlternativeAiException('Empty response');
    }
    final content = choices.first['message']?['content'];
    String text;
    if (content is String) {
      text = content;
    } else if (content is List) {
      text = content.map((p) => p is Map ? (p['text'] ?? '') : '').join();
    } else {
      throw AlternativeAiException('No message content');
    }
    final json = extractJsonObject(text);
    if (json == null) throw AlternativeAiException('Model did not return JSON');
    return json;
  }

  /// Pulls the first top-level JSON object out of free text / markdown fences.
  static Map<String, dynamic>? extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final v = jsonDecode(text.substring(start, end + 1));
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }
}
