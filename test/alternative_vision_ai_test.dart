import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_medi/features/medical_onboarding_ai/data/services/alternative_vision_ai_service.dart';
import 'package:smart_medi/features/medical_onboarding_ai/data/services/gemini_ai_service.dart';

const _rxJson = {
  'is_medical_document': true,
  'document_type': 'prescription',
  'patient_name': 'Sajol Hassan',
  'current_medications': [
    {'name': 'Tab. Napa 500mg', 'dose': '1 tab', 'frequency': '1+1+1', 'duration_text': '5 days', 'instructions': 'after meals'},
  ],
};

http.Response _openAiReply(String content) => http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'role': 'assistant', 'content': content},
          },
        ],
      }),
      200,
    );

void main() {
  final bytes = Uint8List.fromList([1, 2, 3, 4]);

  setUp(() {
    GeminiAiService.sleeper = (_) async {};
    GeminiAiService.resetSessionState();
  });

  tearDown(() {
    GeminiAiService.sleeper = Future.delayed;
    GeminiAiService.geminiApiKeys = [];
    GeminiAiService.resetSessionState();
  });

  test('sends image as data URL with bearer auth and parses fenced JSON', () async {
    late Map<String, dynamic> sent;
    late http.Request req;
    final alt = AlternativeVisionAiService(
      apiKey: 'alt-key',
      models: const ['vision-a'],
      httpClient: MockClient((r) async {
        req = r;
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _openAiReply('Here you go:\n```json\n${jsonEncode(_rxJson)}\n```');
      }),
    );

    final out = await alt.extractJson(prompt: 'p', fileBytes: bytes, mimeType: 'image/jpeg', fileName: 'rx.jpg');

    expect(req.url.toString(), 'https://openrouter.ai/api/v1/chat/completions');
    expect(req.headers['Authorization'], 'Bearer alt-key');
    final parts = (sent['messages'] as List).first['content'] as List;
    expect(parts[1]['image_url']['url'], startsWith('data:image/jpeg;base64,'));
    expect(out['document_type'], 'prescription');
  });

  test('PDFs are sent as file parts', () async {
    late Map<String, dynamic> sent;
    final alt = AlternativeVisionAiService(
      apiKey: 'k',
      models: const ['m'],
      httpClient: MockClient((r) async {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _openAiReply(jsonEncode(_rxJson));
      }),
    );
    await alt.extractJson(prompt: 'p', fileBytes: bytes, mimeType: 'application/pdf', fileName: 'rx.pdf');
    final parts = (sent['messages'] as List).first['content'] as List;
    expect(parts[1]['type'], 'file');
    expect(parts[1]['file']['file_data'], startsWith('data:application/pdf;base64,'));
  });

  test('falls through to the next model on 404', () async {
    final calls = <String>[];
    final alt = AlternativeVisionAiService(
      apiKey: 'k',
      models: const ['gone', 'works'],
      httpClient: MockClient((r) async {
        final model = (jsonDecode(r.body) as Map)['model'] as String;
        calls.add(model);
        return model == 'gone' ? http.Response('not found', 404) : _openAiReply(jsonEncode(_rxJson));
      }),
    );
    final out = await alt.extractJson(prompt: 'p', fileBytes: bytes, mimeType: 'image/png', fileName: 'a.png');
    expect(calls, ['gone', 'works']);
    expect(out['is_medical_document'], isTrue);
  });

  test('GeminiAiService uses the alternative provider first and maps instructions', () async {
    GeminiAiService.geminiApiKeys = ['gem-key'];
    var geminiCalls = 0;
    final service = GeminiAiService(
      httpClient: MockClient((_) async {
        geminiCalls++;
        return http.Response('{}', 500);
      }),
      alternativeService: AlternativeVisionAiService(
        apiKey: 'k',
        models: const ['m'],
        httpClient: MockClient((_) async => _openAiReply(jsonEncode(_rxJson))),
      ),
    );

    final data = await service.analyzeMedicalDocument(fileName: 'rx.jpg', fileSizeBytes: 4, fileBytes: bytes);
    expect(geminiCalls, 0);
    expect(GeminiAiService.lastProviderUsed, 'Alternative AI');
    expect(data.currentMedications.single.instructions, 'after meals');
    expect(data.currentMedications.single.frequency, '1+1+1');
  });

  test('daily quota on OpenRouter switches to Gemini and skips OpenRouter on the next scan', () async {
    AlternativeVisionAiService.resetQuotaState();
    GeminiAiService.geminiApiKeys = ['gem-key'];
    var altCalls = 0;
    final geminiBody = jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': jsonEncode(_rxJson)},
            ],
          },
        },
      ],
    });
    final service = GeminiAiService(
      httpClient: MockClient((_) async => http.Response(geminiBody, 200)),
      alternativeService: AlternativeVisionAiService(
        apiKey: 'k',
        models: const ['a', 'b', 'c'],
        httpClient: MockClient((_) async {
          altCalls++;
          return http.Response('{"error":{"message":"Rate limit exceeded: free-models-per-day"}}', 429);
        }),
      ),
    );

    await service.extractMedicalJson(fileName: 'rx.png', fileSizeBytes: 4, fileBytes: bytes);
    expect(altCalls, 1); // stopped after the first quota error, didn't burn the other models
    expect(GeminiAiService.lastProviderUsed, 'Gemini');

    await service.extractMedicalJson(fileName: 'rx.png', fileSizeBytes: 4, fileBytes: bytes);
    expect(altCalls, 1); // second scan goes straight to Gemini
    AlternativeVisionAiService.resetQuotaState();
  });

  test('falls back to Gemini when the alternative provider fails', () async {
    GeminiAiService.geminiApiKeys = ['gem-key'];
    final geminiBody = jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': jsonEncode(_rxJson)},
            ],
          },
        },
      ],
    });
    final service = GeminiAiService(
      httpClient: MockClient((_) async => http.Response(geminiBody, 200)),
      alternativeService: AlternativeVisionAiService(
        apiKey: 'bad',
        models: const ['m'],
        httpClient: MockClient((_) async => http.Response('unauthorized', 401)),
      ),
    );

    final out = await service.extractMedicalJson(fileName: 'rx.png', fileSizeBytes: 4, fileBytes: bytes);
    expect(out['document_type'], 'prescription');
    expect(GeminiAiService.lastProviderUsed, 'Gemini');
  });
}
