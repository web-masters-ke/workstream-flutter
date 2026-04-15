import 'dart:io';

import 'package:dio/dio.dart';

import '../models/message.dart';
import 'api_service.dart';

class ChatService {
  final _api = ApiService.instance;

  Future<List<ChatThread>> threads() async {
    final r = await _api.get('/communication/conversations');
    final data = unwrap<dynamic>(r);
    final list = data is List ? data : const <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => ChatThread.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ChatMessage>> messages(
    String conversationId, {
    required String currentUserId,
  }) async {
    final r = await _api.get('/communication/conversations/$conversationId/messages');
    final data = unwrap<dynamic>(r);
    // Backend returns { items: [...] } or a plain list
    List<dynamic> list;
    if (data is Map && data['items'] is List) {
      list = data['items'] as List;
    } else if (data is List) {
      list = data;
    } else {
      list = const [];
    }
    return list
        .whereType<Map>()
        .map(
          (e) => ChatMessage.fromJson(
            Map<String, dynamic>.from(e),
            currentUserId: currentUserId,
          ),
        )
        .toList();
  }

  Future<ChatMessage> send(
    String conversationId,
    String body, {
    required String currentUserId,
  }) async {
    final r = await _api.post(
      '/communication/conversations/$conversationId/messages',
      body: {'body': body, 'type': 'TEXT'},
    );
    final data = unwrap<Map<String, dynamic>>(r);
    return ChatMessage.fromJson(data, currentUserId: currentUserId);
  }

  /// Upload a voice recording and send it as a VOICE message.
  Future<ChatMessage> sendVoice(
    String conversationId,
    File audioFile, {
    required String currentUserId,
  }) async {
    // 1. Upload to /media/upload
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audioFile.path,
        filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      ),
    });
    final uploadResp = await _api.dio.post(
      '/media/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final uploadData = uploadResp.data is Map<String, dynamic>
        ? uploadResp.data as Map<String, dynamic>
        : <String, dynamic>{};
    final dataPayload = uploadData['data'];
    final uploadedUrl = (dataPayload is Map
            ? dataPayload['url']?.toString()
            : null) ??
        uploadData['url']?.toString() ??
        '';
    if (uploadedUrl.isEmpty) {
      throw ApiException('Upload returned no URL');
    }

    // 2. Send message with VOICE type
    final r = await _api.post(
      '/communication/conversations/$conversationId/messages',
      body: {
        'type': 'VOICE',
        'attachmentUrl': uploadedUrl,
        'body': '',
      },
    );
    final data = unwrap<Map<String, dynamic>>(r);
    return ChatMessage.fromJson(data, currentUserId: currentUserId);
  }
}
