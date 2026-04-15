import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'call_screen.dart';

// ─── Lightweight models for this screen ──────────────────────────────────────

class _Agent {
  final String id;
  final String name;
  final String email;
  _Agent({required this.id, required this.name, required this.email});

  factory _Agent.fromJson(Map<String, dynamic> j) {
    final user = j['user'] is Map ? j['user'] as Map<String, dynamic> : j;
    final fn = (user['firstName'] ?? j['firstName'])?.toString() ?? '';
    final ln = (user['lastName'] ?? j['lastName'])?.toString() ?? '';
    final email = (user['email'] ?? j['email'])?.toString() ?? '';
    var name = '$fn $ln'.trim();
    if (name.isEmpty) name = j['name']?.toString() ?? email;
    if (name.isEmpty) name = 'Agent';
    return _Agent(id: j['id']?.toString() ?? '', name: name, email: email);
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d, y').format(dt);
}

Color _statusColor(String s) {
  switch (s.toUpperCase()) {
    case 'COMPLETED':
      return AppColors.success;
    case 'IN_PROGRESS':
    case 'ASSIGNED':
      return AppColors.primary;
    case 'CANCELLED':
    case 'FAILED':
    case 'REJECTED':
      return AppColors.danger;
    case 'UNDER_REVIEW':
    case 'SUBMITTED':
    case 'ON_HOLD':
      return AppColors.warn;
    default:
      return AppColors.lightSubtext;
  }
}

Color _priorityColor(String p) {
  switch (p.toUpperCase()) {
    case 'URGENT':
      return AppColors.danger;
    case 'HIGH':
      return const Color(0xFFEA580C);
    case 'MEDIUM':
      return AppColors.warn;
    default:
      return AppColors.lightSubtext;
  }
}

String _agentNameFromMap(Map<String, dynamic>? agent) {
  if (agent == null) return 'Unassigned';
  final fn = agent['firstName']?.toString() ?? '';
  final ln = agent['lastName']?.toString() ?? '';
  final name = '$fn $ln'.trim();
  if (name.isNotEmpty) return name;
  return agent['name']?.toString() ?? agent['email']?.toString() ?? 'Agent';
}

/// Extract the assigned agent name from the task's `assignments` array.
/// Falls back to the flat `agent` map if `assignments` is empty.
String _agentNameFromTask(Map<String, dynamic> task) {
  final assignments = task['assignments'];
  if (assignments is List && assignments.isNotEmpty) {
    // Prefer the accepted assignment, otherwise take the latest
    Map<String, dynamic>? accepted;
    for (final a in assignments) {
      if (a is Map<String, dynamic> && a['status'] == 'ACCEPTED') {
        accepted = a;
        break;
      }
    }
    accepted ??= assignments.last is Map<String, dynamic>
        ? assignments.last as Map<String, dynamic>
        : null;
    if (accepted != null) {
      final agentNode = accepted['agent'];
      if (agentNode is Map<String, dynamic>) {
        final userNode = agentNode['user'];
        if (userNode is Map<String, dynamic>) {
          final name = userNode['name']?.toString();
          if (name != null && name.isNotEmpty) return name;
          final fn = userNode['firstName']?.toString() ?? '';
          final ln = userNode['lastName']?.toString() ?? '';
          final full = '$fn $ln'.trim();
          if (full.isNotEmpty) return full;
        }
        return _agentNameFromMap(agentNode);
      }
    }
  }
  // Fallback to flat agent map
  final agent = task['agent'] is Map
      ? task['agent'] as Map<String, dynamic>
      : null;
  return _agentNameFromMap(agent);
}

/// Extract the agent email from the task's `assignments` array.
String? _agentEmailFromTask(Map<String, dynamic> task) {
  final assignments = task['assignments'];
  if (assignments is List && assignments.isNotEmpty) {
    Map<String, dynamic>? accepted;
    for (final a in assignments) {
      if (a is Map<String, dynamic> && a['status'] == 'ACCEPTED') {
        accepted = a;
        break;
      }
    }
    accepted ??= assignments.last is Map<String, dynamic>
        ? assignments.last as Map<String, dynamic>
        : null;
    if (accepted != null) {
      final agentNode = accepted['agent'];
      if (agentNode is Map<String, dynamic>) {
        final userNode = agentNode['user'];
        if (userNode is Map<String, dynamic>) {
          return userNode['email']?.toString();
        }
        return agentNode['email']?.toString();
      }
    }
  }
  final agent = task['agent'] is Map
      ? task['agent'] as Map<String, dynamic>
      : null;
  return agent?['email']?.toString();
}

List<dynamic> _extractList(dynamic data, [String? key]) {
  if (data is List) return data;
  if (data is Map) {
    if (key != null && data[key] is List) return data[key] as List;
    if (data['items'] is List) return data['items'] as List;
  }
  return [];
}

// ─── Main Screen ─────────────────────────────────────────────────────────────

class AdminTaskDetailScreen extends StatefulWidget {
  final String taskId;
  const AdminTaskDetailScreen({super.key, required this.taskId});

  @override
  State<AdminTaskDetailScreen> createState() => _AdminTaskDetailScreenState();
}

class _AdminTaskDetailScreenState extends State<AdminTaskDetailScreen> {
  Map<String, dynamic>? _task;
  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _activity = [];
  List<Map<String, dynamic>> _messages = [];
  String? _conversationId;
  bool _loading = true;
  String? _error;
  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();
  bool _sendingChat = false;
  bool _showEmojiPicker = false;
  File? _pendingImage;
  bool _uploadingImage = false;

  // Voice recording state
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _recordedFilePath;
  int _recordedDuration = 0; // seconds
  bool _sendingVoice = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _chatScroll.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ─── Voice recording helpers ──────────────────────────────────────────────

  String _formatDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final path =
        '${Directory.systemTemp.path}/ws_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
      _recordedFilePath = null;
      _recordedDuration = 0;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final path = await _recorder.stop();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
        _recordedDuration = _recordingSeconds;
        _recordingSeconds = 0;
      });
    }
  }

  void _discardRecording() {
    if (_recordedFilePath != null) {
      try {
        File(_recordedFilePath!).deleteSync();
      } catch (_) {}
    }
    setState(() {
      _recordedFilePath = null;
      _recordedDuration = 0;
    });
  }

  Future<void> _sendVoiceMessage() async {
    final filePath = _recordedFilePath;
    if (filePath == null) return;
    setState(() => _sendingVoice = true);
    try {
      await _ensureConversation();
      if (_conversationId == null) {
        throw ApiException('Could not create conversation');
      }
      // Upload
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        ),
      });
      final uploadResp = await ApiService.instance.dio.post(
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
      // Send VOICE message
      await ApiService.instance.post(
        '/communication/conversations/$_conversationId/messages',
        body: {
          'type': 'VOICE',
          'attachmentUrl': uploadedUrl,
          'body': '',
        },
      );
      setState(() {
        _recordedFilePath = null;
        _recordedDuration = 0;
      });
      await _reloadMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanError(e)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingVoice = false);
    }
  }

  bool _isVoiceUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg');
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.instance.get('/tasks/${widget.taskId}'),
        ApiService.instance
            .get('/tasks/${widget.taskId}/submissions')
            .catchError((_) => <String, dynamic>{'success': true, 'data': []}),
        ApiService.instance
            .get('/tasks/${widget.taskId}/history')
            .catchError((_) => <String, dynamic>{'success': true, 'data': []}),
      ]);

      final taskData = unwrap<Map<String, dynamic>>(results[0]);
      final subData = unwrap<dynamic>(results[1]);
      final actData = unwrap<dynamic>(results[2]);

      // Find or create a conversation for this task
      List<Map<String, dynamic>> messages = [];
      try {
        final convResp = await ApiService.instance.get('/communication/conversations');
        final convRaw = unwrap<dynamic>(convResp);
        final convList = convRaw is List ? convRaw : (convRaw is Map ? (convRaw['items'] ?? []) : []);
        // Find conversation linked to this task
        for (final c in convList) {
          if (c is Map && c['taskId']?.toString() == widget.taskId) {
            _conversationId = c['id']?.toString();
            break;
          }
        }
        // Load messages if conversation exists
        if (_conversationId != null) {
          final msgResp = await ApiService.instance
              .get('/communication/conversations/$_conversationId/messages');
          final msgData = unwrap<dynamic>(msgResp);
          messages = _extractList(msgData, 'messages')
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      } catch (_) {
        // Chat not available — that's OK
      }

      setState(() {
        _task = taskData;
        _submissions = _extractList(subData, 'submissions')
            .whereType<Map<String, dynamic>>()
            .toList();
        _activity = _extractList(actData, 'activity')
            .whereType<Map<String, dynamic>>()
            .toList();
        _messages = messages;
      });
    } catch (e) {
      setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _status =>
      _task?['status']?.toString().toUpperCase() ?? 'PENDING';

  Future<void> _patchTask(Map<String, dynamic> body,
      {String? successMsg}) async {
    try {
      // Status changes go to /transition endpoint
      final isStatusChange = body.containsKey('status') && body.length == 1;
      final path = isStatusChange
          ? '/tasks/${widget.taskId}/transition'
          : '/tasks/${widget.taskId}';
      final resp = await ApiService.instance.patch(path, body: body);
      final updated = unwrap<Map<String, dynamic>>(resp);
      if (!mounted) return;
      setState(() => _task = updated);
      _loadAll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg ?? 'Task updated'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanError(e)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatCtrl.text.trim();
    final image = _pendingImage;
    if (text.isEmpty && image == null) return;

    setState(() {
      _sendingChat = true;
      _showEmojiPicker = false;
    });

    try {
      await _ensureConversation();
      if (_conversationId == null) {
        throw ApiException('Could not create conversation');
      }

      // Upload image first if present
      if (image != null) {
        setState(() {
          _pendingImage = null;
          _uploadingImage = true;
        });
        await _uploadAndSendImage();
      }

      // Send text message
      if (text.isNotEmpty) {
        await ApiService.instance.post(
          '/communication/conversations/$_conversationId/messages',
          body: {'body': text, 'type': 'TEXT'},
        );
        _chatCtrl.clear();
      }

      await _reloadMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanError(e)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingChat = false;
          _uploadingImage = false;
        });
      }
    }
  }

  void _scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScroll.hasClients) return;
      _chatScroll.animateTo(
        _chatScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _pickChatImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() => _pendingImage = File(picked.path));
  }

  Future<void> _uploadAndSendImage() async {
    final image = _pendingImage;
    if (image == null) return;
    setState(() {
      _uploadingImage = true;
      _pendingImage = null;
    });
    try {
      // Ensure conversation exists
      if (_conversationId == null) {
        await _ensureConversation();
      }
      if (_conversationId == null) {
        throw ApiException('Could not create conversation');
      }

      // Upload to /media/upload
      final fileName = image.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(image.path, filename: fileName),
      });
      final uploadResp = await ApiService.instance.dio.post(
        '/media/upload',
        data: formData,
        queryParameters: {'kind': 'chat'},
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

      // Send message with IMAGE type
      await ApiService.instance.post(
        '/communication/conversations/$_conversationId/messages',
        body: {
          'type': 'IMAGE',
          'attachmentUrl': uploadedUrl,
          'body': '',
        },
      );

      // Reload messages
      await _reloadMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanError(e)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  /// Ensures _conversationId is set (creates one if needed).
  Future<void> _ensureConversation() async {
    if (_conversationId != null) return;
    final participantIds = <String>[];
    final assignments = _task?['assignments'];
    if (assignments is List) {
      for (final a in assignments) {
        final uid = a?['agent']?['userId']?.toString();
        if (uid != null && uid.isNotEmpty) {
          participantIds.add(uid);
          break;
        }
      }
    }
    if (participantIds.isEmpty) {
      final cid = _task?['createdById']?.toString();
      if (cid != null && cid.isNotEmpty) participantIds.add(cid);
    }
    if (participantIds.isEmpty) {
      try {
        final me = unwrap<Map<String, dynamic>>(
            await ApiService.instance.get('/auth/me'));
        final myId = me['id']?.toString();
        if (myId != null) participantIds.add(myId);
      } catch (_) {}
    }
    final convResp = await ApiService.instance.post(
      '/communication/conversations',
      body: {
        'type': 'DIRECT',
        'title': _task?['title']?.toString() ?? 'Task chat',
        'taskId': widget.taskId,
        'participantUserIds': participantIds,
      },
    );
    final convData = unwrap<Map<String, dynamic>>(convResp);
    _conversationId = convData['id']?.toString();
  }

  Future<void> _reloadMessages() async {
    if (_conversationId == null) return;
    final resp = await ApiService.instance
        .get('/communication/conversations/$_conversationId/messages');
    final data = unwrap<dynamic>(resp);
    if (mounted) {
      setState(() {
        _messages = _extractList(data, 'messages')
            .whereType<Map<String, dynamic>>()
            .toList();
      });
      _scrollChatToEnd();
    }
  }

  void _insertEmoji(String emoji) {
    final text = _chatCtrl.text;
    final sel = _chatCtrl.selection;
    final start = sel.baseOffset >= 0 ? sel.baseOffset : text.length;
    final end = sel.extentOffset >= 0 ? sel.extentOffset : text.length;
    final newText = text.replaceRange(start, end, emoji);
    _chatCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  void _openCallScreen() {
    final agentName = _task != null ? _agentNameFromTask(_task!) : 'Agent';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CallScreen(contactName: agentName),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  void _showReassignSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReassignAgentSheet(
        currentAgentId: _task?['assignedAgentId']?.toString(),
        onPicked: (id, name) async {
          Navigator.pop(context);
          if (id == null) return;
          try {
            await ApiService.instance.post(
              '/tasks/${widget.taskId}/assign',
              body: {'agentId': id},
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Assigned to $name'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            _loadAll();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(cleanError(e)),
                backgroundColor: AppColors.danger,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _showReviewSheet(Map<String, dynamic> submission) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReviewSubmissionSheet(
        taskId: widget.taskId,
        submissionId: submission['id']?.toString() ?? '',
        onDone: () {
          Navigator.pop(context);
          _loadAll();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task details')),
        body: const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (_error != null || _task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task details')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(_error ?? 'Failed to load task',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 12),
              TextButton(onPressed: _loadAll, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final task = _task!;
    final title = task['title']?.toString() ?? 'Untitled';
    final status = _status;
    final priority = task['priority']?.toString() ?? '';
    final description = task['description']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clone') {
                _patchTask({'clone': true}, successMsg: 'Task cloned');
              } else if (v == 'force_fail') {
                _patchTask(
                    {'status': 'FAILED'}, successMsg: 'Task marked as failed');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clone',
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Clone'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'force_fail',
                child: Row(
                  children: [
                    Icon(Icons.dangerous_rounded,
                        size: 18, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Force fail',
                        style: TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            // ── 1. Status + Priority badges ──────────────────────
            Row(
              children: [
                StatusPill(
                  label: status.replaceAll('_', ' '),
                  color: _statusColor(status),
                ),
                if (priority.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  StatusPill(
                    label: priority,
                    color: _priorityColor(priority),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),

            // ── 2. Details card ──────────────────────────────────
            _buildDetailsCard(task, t, subtext),
            const SizedBox(height: 18),

            // ── 3. Description ───────────────────────────────────
            if (description.isNotEmpty) ...[
              const SectionHeader(title: 'Description'),
              const SizedBox(height: 8),
              Text(description,
                  style: t.textTheme.bodyMedium?.copyWith(height: 1.5)),
              const SizedBox(height: 18),
            ],

            // ── 4. Agent assignment ──────────────────────────────
            _buildAgentSection(task, t, subtext),
            const SizedBox(height: 18),

            // ── 5. Status controls ───────────────────────────────
            _buildStatusControls(status),
            const SizedBox(height: 18),

            // ── 6. Work submissions ──────────────────────────────
            _buildSubmissionsSection(t, subtext),
            const SizedBox(height: 18),

            // ── 7. Activity timeline ─────────────────────────────
            _buildActivitySection(t, subtext),
            const SizedBox(height: 18),

            // ── 8. Chat section ──────────────────────────────────
            _buildChatSection(t, subtext, isDark),
          ],
        ),
      ),
    );
  }

  // ─── Details card ────────────────────────────────────────────────────────

  Widget _buildDetailsCard(
      Map<String, dynamic> task, ThemeData t, Color subtext) {
    final sla = task['slaMinutes'];
    final agentName = _agentNameFromTask(task);
    final skill = task['skill']?.toString() ??
        task['category']?.toString() ??
        '';
    final startedAt = _parseDate(task['startedAt']);
    final completedAt = _parseDate(task['completedAt']);
    final job = task['job'] is Map
        ? (task['job'] as Map)['title']?.toString()
        : task['jobId']?.toString();
    final qaScore = task['qaScore'];
    final dueAt = _parseDate(task['dueAt'] ?? task['deadline']);
    final priority = task['priority']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.dividerColor),
      ),
      child: Column(
        children: [
          // Row 1
          Row(
            children: [
              Expanded(child: _detailItem('Priority', priority, subtext)),
              Expanded(
                child: _detailItem(
                  'SLA',
                  sla != null ? '$sla min' : '--',
                  subtext,
                ),
              ),
              Expanded(
                child: _detailItem(
                  'Agent',
                  agentName,
                  subtext,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Row 2
          Row(
            children: [
              Expanded(
                child: _detailItem(
                  'Skill',
                  skill.isNotEmpty
                      ? skill.replaceAll('_', ' ')
                      : '--',
                  subtext,
                ),
              ),
              Expanded(
                child: _detailItem(
                  'Started',
                  startedAt != null
                      ? DateFormat('MMM d, HH:mm').format(startedAt)
                      : '--',
                  subtext,
                ),
              ),
              Expanded(
                child: _detailItem(
                  'Completed',
                  completedAt != null
                      ? DateFormat('MMM d, HH:mm').format(completedAt)
                      : '--',
                  subtext,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Row 3
          Row(
            children: [
              Expanded(
                child: _detailItem(
                  'Job',
                  job ?? '--',
                  subtext,
                ),
              ),
              Expanded(
                child: _detailItem(
                  'QA score',
                  qaScore != null ? '$qaScore' : '--',
                  subtext,
                ),
              ),
              Expanded(
                child: _detailItem(
                  'Due date',
                  dueAt != null
                      ? DateFormat('MMM d, HH:mm').format(dueAt)
                      : '--',
                  subtext,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value, Color subtext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: subtext,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ─── Agent assignment ───────────────────────────────────────────────────

  Widget _buildAgentSection(
      Map<String, dynamic> task, ThemeData t, Color subtext) {
    final agentName = _agentNameFromTask(task);
    final agentEmail = _agentEmailFromTask(task);
    final initial = agentName.isNotEmpty ? agentName[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agentName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                if (agentEmail != null)
                  Text(
                    agentEmail,
                    style: TextStyle(color: subtext, fontSize: 12),
                  ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _showReassignSheet,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text('Reassign'),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Status controls ────────────────────────────────────────────────────

  Widget _buildStatusControls(String status) {
    final List<Widget> buttons = [];

    switch (status) {
      case 'PENDING':
      case 'AVAILABLE':
        buttons.add(
          Expanded(
            child: FilledButton.icon(
              onPressed: _showReassignSheet,
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Assign'),
            ),
          ),
        );
        break;

      case 'ASSIGNED':
      case 'IN_PROGRESS':
        buttons.add(
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _patchTask(
                {'status': 'FAILED'},
                successMsg: 'Task marked as failed',
              ),
              icon: const Icon(Icons.dangerous_rounded,
                  size: 18, color: AppColors.danger),
              label: const Text('Force fail',
                  style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
              ),
            ),
          ),
        );
        buttons.add(const SizedBox(width: 10));
        buttons.add(
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _patchTask(
                {'status': 'ON_HOLD'},
                successMsg: 'Task put on hold',
              ),
              icon: const Icon(Icons.pause_circle_rounded, size: 18),
              label: const Text('Put on hold'),
            ),
          ),
        );
        break;

      case 'UNDER_REVIEW':
      case 'SUBMITTED':
        buttons.add(
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _patchTask(
                {'status': 'ASSIGNED'},
                successMsg: 'Task rejected, sent back to agent',
              ),
              icon: const Icon(Icons.replay_rounded,
                  size: 18, color: AppColors.danger),
              label: const Text('Reject',
                  style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
              ),
            ),
          ),
        );
        buttons.add(const SizedBox(width: 10));
        buttons.add(
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _patchTask(
                {'status': 'COMPLETED'},
                successMsg: 'Task approved and completed',
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Approve'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
            ),
          ),
        );
        break;

      case 'ON_HOLD':
        buttons.add(
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _patchTask(
                {'status': 'IN_PROGRESS'},
                successMsg: 'Task resumed',
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Resume'),
            ),
          ),
        );
        break;

      default:
        // COMPLETED, FAILED, CANCELLED — no actions
        return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Actions'),
        const SizedBox(height: 8),
        Row(children: buttons),
      ],
    );
  }

  // ─── Submissions ────────────────────────────────────────────────────────

  Widget _buildSubmissionsSection(ThemeData t, Color subtext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Work submissions (${_submissions.length})',
        ),
        const SizedBox(height: 8),
        if (_submissions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.dividerColor),
            ),
            child: Text(
              'No submissions yet.',
              style: TextStyle(color: subtext, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...List.generate(_submissions.length, (i) {
            final sub = _submissions[i];
            return _buildSubmissionTile(sub, i + 1, t, subtext);
          }),
      ],
    );
  }

  Widget _buildSubmissionTile(
    Map<String, dynamic> sub,
    int round,
    ThemeData t,
    Color subtext,
  ) {
    final type = sub['type']?.toString() ?? 'text';
    final content = sub['content']?.toString() ??
        sub['url']?.toString() ??
        '';
    final fileUrl = sub['fileUrl']?.toString() ?? '';
    final notes = sub['notes']?.toString() ?? '';
    final subStatus = sub['status']?.toString().toUpperCase() ?? '';
    final reviewer = sub['reviewer'] is Map
        ? _agentNameFromMap(sub['reviewer'] as Map<String, dynamic>)
        : sub['reviewerName']?.toString();
    final createdAt = _parseDate(sub['createdAt']);

    final hasFileUrl = fileUrl.isNotEmpty;
    final isFileImage = hasFileUrl && _isImageUrl(fileUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Round $round',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: subtext.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: subtext,
                  ),
                ),
              ),
              const Spacer(),
              if (subStatus.isNotEmpty)
                StatusPill(
                  label: subStatus.replaceAll('_', ' '),
                  color: _statusColor(subStatus),
                ),
            ],
          ),

          // File attachment — image thumbnail or file link
          if (hasFileUrl) ...[
            const SizedBox(height: 10),
            if (isFileImage)
              GestureDetector(
                onTap: () => _launchUrl(fileUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    fileUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: subtext.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, size: 32),
                      ),
                    ),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => _launchUrl(fileUrl),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.attach_file_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          fileUrl.split('/').last,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.open_in_new_rounded,
                          size: 14, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
          ],

          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content,
              style: t.textTheme.bodySmall?.copyWith(height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Notes: $notes',
              style: TextStyle(
                  color: subtext, fontSize: 12, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (reviewer != null) ...[
                Icon(Icons.person_outline_rounded, size: 12, color: subtext),
                const SizedBox(width: 3),
                Text(
                  reviewer,
                  style: TextStyle(color: subtext, fontSize: 11),
                ),
                const SizedBox(width: 12),
              ],
              if (createdAt != null) ...[
                Icon(Icons.schedule_rounded, size: 12, color: subtext),
                const SizedBox(width: 3),
                Text(
                  _relativeTime(createdAt),
                  style: TextStyle(color: subtext, fontSize: 11),
                ),
              ],
              const Spacer(),
              SizedBox(
                height: 30,
                child: OutlinedButton(
                  onPressed: () => _showReviewSheet(sub),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Review'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Activity timeline ──────────────────────────────────────────────────

  Widget _buildActivitySection(ThemeData t, Color subtext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Activity (${_activity.length})'),
        const SizedBox(height: 8),
        if (_activity.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.dividerColor),
            ),
            child: Text(
              'No activity yet.',
              style: TextStyle(color: subtext, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...List.generate(_activity.length, (i) {
            final entry = _activity[i];
            return _buildActivityEntry(entry, i, t, subtext);
          }),
      ],
    );
  }

  Widget _buildActivityEntry(
    Map<String, dynamic> entry,
    int index,
    ThemeData t,
    Color subtext,
  ) {
    final action = entry['action']?.toString() ??
        entry['description']?.toString() ??
        entry['type']?.toString() ??
        'Activity';
    final actorMap = entry['actor'] is Map
        ? entry['actor'] as Map<String, dynamic>
        : null;
    final actor = actorMap != null
        ? _agentNameFromMap(actorMap)
        : entry['actorName']?.toString() ?? '';
    final ts = _parseDate(entry['createdAt'] ?? entry['timestamp']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary, width: 2),
                  ),
                ),
                if (index < _activity.length - 1)
                  Container(
                    width: 2,
                    height: 32,
                    color: t.dividerColor,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: t.textTheme.bodySmall?.copyWith(height: 1.3),
                      children: [
                        if (actor.isNotEmpty)
                          TextSpan(
                            text: '$actor ',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                        TextSpan(text: action),
                      ],
                    ),
                  ),
                  if (ts != null)
                    Text(
                      _relativeTime(ts),
                      style: TextStyle(
                          color: subtext, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Chat section ───────────────────────────────────────────────────────

  Widget _buildChatSection(ThemeData t, Color subtext, bool isDark) {
    final agentName = _task != null ? _agentNameFromTask(_task!) : 'Agent';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chat header with call button
        Row(
          children: [
            Text(
              'Chat (${_messages.length})',
              style:
                  t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            IconButton(
              onPressed: _openCallScreen,
              icon: const Icon(Icons.call_rounded, size: 20),
              tooltip: 'Call $agentName',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.success.withValues(alpha: 0.12),
                foregroundColor: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 450),
          decoration: BoxDecoration(
            color: t.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.dividerColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Messages list
              if (_messages.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No messages yet.',
                    style: TextStyle(color: subtext, fontSize: 13),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    controller: _chatScroll,
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) =>
                        _buildChatBubble(_messages[i], t, subtext, isDark),
                  ),
                ),

              // Pending image preview
              if (_pendingImage != null)
                Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.dividerColor)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _pendingImage!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _pendingImage!.path.split('/').last,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: subtext),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () =>
                            setState(() => _pendingImage = null),
                      ),
                    ],
                  ),
                ),

              // Input bar with attachment + emoji + mic buttons
              Container(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: t.dividerColor)),
                ),
                child: _isRecording
                    // ── Recording state: red strip ──────────────────
                    ? Row(
                        children: [
                          const SizedBox(width: 8),
                          _PulsingDot(),
                          const SizedBox(width: 8),
                          Text(
                            'Recording...',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(_recordingSeconds),
                            style: TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _stopRecording,
                            icon: const Icon(Icons.stop_rounded,
                                color: AppColors.danger, size: 28),
                            tooltip: 'Stop recording',
                          ),
                        ],
                      )
                    : _recordedFilePath != null
                        // ── Preview state: play + waveform + send ───
                        ? Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  final uri = Uri.file(_recordedFilePath!);
                                  launchUrl(uri);
                                },
                                icon: const Icon(Icons.play_arrow_rounded,
                                    color: AppColors.primary, size: 24),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
                                tooltip: 'Play',
                              ),
                              Expanded(child: _VoiceWaveform()),
                              const SizedBox(width: 4),
                              Text(
                                _formatDuration(_recordedDuration),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: subtext,
                                ),
                              ),
                              IconButton(
                                onPressed: _discardRecording,
                                icon: const Icon(Icons.close_rounded,
                                    size: 20),
                                tooltip: 'Discard',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
                              ),
                              _sendingVoice
                                  ? const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    )
                                  : IconButton(
                                      onPressed: _sendVoiceMessage,
                                      icon: const Icon(
                                          Icons.send_rounded,
                                          color: AppColors.primary,
                                          size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 36, minHeight: 36),
                                      tooltip: 'Send voice note',
                                    ),
                            ],
                          )
                        // ── Default state: clean input bar ──────────
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Text field with icons inside
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkSurface
                                        : AppColors.lightBg,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: t.dividerColor,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      // Emoji toggle
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 4, bottom: 4),
                                        child: IconButton(
                                          onPressed: () => setState(() =>
                                              _showEmojiPicker =
                                                  !_showEmojiPicker),
                                          icon: Icon(
                                            _showEmojiPicker
                                                ? Icons.keyboard_rounded
                                                : Icons
                                                    .emoji_emotions_outlined,
                                            size: 20,
                                            color: subtext,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints:
                                              const BoxConstraints(
                                                  minWidth: 32,
                                                  minHeight: 32),
                                        ),
                                      ),
                                      // Text input
                                      Expanded(
                                        child: TextField(
                                          controller: _chatCtrl,
                                          decoration:
                                              const InputDecoration(
                                            hintText: 'Message...',
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 10),
                                            isDense: true,
                                          ),
                                          maxLines: 4,
                                          minLines: 1,
                                          textInputAction:
                                              TextInputAction.send,
                                          onSubmitted: (_) =>
                                              _sendMessage(),
                                          onTap: () {
                                            if (_showEmojiPicker) {
                                              setState(() =>
                                                  _showEmojiPicker =
                                                      false);
                                            }
                                          },
                                        ),
                                      ),
                                      // Attachment
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 4),
                                        child: IconButton(
                                          onPressed: _uploadingImage
                                              ? null
                                              : _pickChatImage,
                                          icon: Icon(
                                              Icons.attach_file_rounded,
                                              size: 20,
                                              color: subtext),
                                          padding: EdgeInsets.zero,
                                          constraints:
                                              const BoxConstraints(
                                                  minWidth: 32,
                                                  minHeight: 32),
                                        ),
                                      ),
                                      // Mic
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            right: 4, bottom: 4),
                                        child: IconButton(
                                          onPressed: _startRecording,
                                          icon: Icon(
                                              Icons.mic_rounded,
                                              size: 20,
                                              color: subtext),
                                          padding: EdgeInsets.zero,
                                          constraints:
                                              const BoxConstraints(
                                                  minWidth: 32,
                                                  minHeight: 32),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Send button — circular
                              (_sendingChat || _uploadingImage)
                                  ? Container(
                                      width: 42,
                                      height: 42,
                                      margin: const EdgeInsets.only(
                                          bottom: 2),
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    )
                                  : Container(
                                      margin: const EdgeInsets.only(
                                          bottom: 2),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        onPressed: _sendMessage,
                                        icon: const Icon(
                                            Icons.send_rounded,
                                            color: Colors.white,
                                            size: 18),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 42, minHeight: 42),
                                      ),
                                    ),
                            ],
                          ),
              ),

              // Emoji picker
              if (_showEmojiPicker)
                _AdminEmojiGrid(onEmojiSelected: _insertEmoji),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble(
    Map<String, dynamic> msg,
    ThemeData t,
    Color subtext,
    bool isDark,
  ) {
    final senderMap = msg['sender'] is Map
        ? msg['sender'] as Map<String, dynamic>
        : null;
    final senderName = senderMap != null
        ? _agentNameFromMap(senderMap)
        : msg['senderName']?.toString() ?? '';
    final body = msg['body']?.toString() ?? msg['text']?.toString() ?? '';
    final attachmentUrl = msg['attachmentUrl']?.toString() ?? '';
    final msgType = msg['type']?.toString().toUpperCase() ?? 'TEXT';
    final ts = _parseDate(msg['createdAt'] ?? msg['timestamp']);
    final isAdmin = msg['isAdmin'] == true ||
        msg['senderRole']?.toString().toUpperCase() == 'ADMIN' ||
        msg['senderRole']?.toString().toUpperCase() == 'BUSINESS';
    final align = isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isAdmin
        ? AppColors.primary.withValues(alpha: 0.12)
        : (isDark ? AppColors.darkCard : const Color(0xFFF3F4F6));

    final isVoice = msgType == 'VOICE' ||
        (attachmentUrl.isNotEmpty && _isVoiceUrl(attachmentUrl));
    final hasImage = !isVoice &&
        attachmentUrl.isNotEmpty &&
        (msgType == 'IMAGE' || _isImageUrl(attachmentUrl));
    final hasFile = attachmentUrl.isNotEmpty && !hasImage && !isVoice;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (senderName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                senderName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: subtext,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Voice note
                if (isVoice) ...[
                  GestureDetector(
                    onTap: () {
                      if (attachmentUrl.isNotEmpty) {
                        _launchUrl(attachmentUrl);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded,
                            color: AppColors.primary, size: 22),
                        const SizedBox(width: 6),
                        _VoiceWaveform(compact: true),
                        const SizedBox(width: 6),
                        Text(
                          'Voice note',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subtext,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
                // Image attachment
                else if (hasImage) ...[
                  GestureDetector(
                    onTap: () => _launchUrl(attachmentUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        attachmentUrl,
                        width: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            size: 40),
                      ),
                    ),
                  ),
                  if (body.isNotEmpty) const SizedBox(height: 6),
                ]
                // File attachment
                else if (hasFile) ...[
                  GestureDetector(
                    onTap: () => _launchUrl(attachmentUrl),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_file_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            attachmentUrl.split('/').last,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (body.isNotEmpty) const SizedBox(height: 6),
                ]
                // Body text
                else ...[
                  if (body.isNotEmpty)
                    Text(body, style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
          if (ts != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _relativeTime(ts),
                style: TextStyle(fontSize: 10, color: subtext),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Reassign Agent Bottom Sheet ─────────────────────────────────────────────

class _ReassignAgentSheet extends StatefulWidget {
  final String? currentAgentId;
  final void Function(String? id, String? name) onPicked;

  const _ReassignAgentSheet({
    required this.currentAgentId,
    required this.onPicked,
  });

  @override
  State<_ReassignAgentSheet> createState() => _ReassignAgentSheetState();
}

class _ReassignAgentSheetState extends State<_ReassignAgentSheet> {
  final _searchCtrl = TextEditingController();
  List<_Agent> _agents = [];
  List<_Agent> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    try {
      final resp =
          await ApiService.instance.get('/agents', query: {'limit': '100'});
      final data = unwrap<dynamic>(resp);
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['items'] is List) {
        list = data['items'] as List;
      } else if (data is Map && data['agents'] is List) {
        list = data['agents'] as List;
      } else {
        list = [];
      }
      if (!mounted) return;
      setState(() {
        _agents = list
            .whereType<Map<String, dynamic>>()
            .map(_Agent.fromJson)
            .toList();
        _filtered = _agents;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter(String q) {
    final query = q.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _agents;
      } else {
        _filtered = _agents
            .where((a) =>
                a.name.toLowerCase().contains(query) ||
                a.email.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Reassign agent',
                    style: t.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => widget.onPicked(null, null),
                    child: const Text('Unassign'),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon:
                      const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _filter('');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
            // Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filtered.length} agent${_filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(color: subtext, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Agent list
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(strokeWidth: 2.5))
                  : _filtered.isEmpty
                      ? Center(
                          child: Text('No agents found',
                              style: TextStyle(color: subtext)),
                        )
                      : ListView.builder(
                          itemCount: _filtered.length,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          itemBuilder: (_, i) {
                            final a = _filtered[i];
                            final selected =
                                a.id == widget.currentAgentId;
                            return ListTile(
                              selected: selected,
                              selectedTileColor:
                                  AppColors.primary.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary
                                    .withValues(alpha: 0.15),
                                child: Text(
                                  a.name.isNotEmpty
                                      ? a.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              title: Text(a.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              subtitle: Text(a.email,
                                  style: TextStyle(
                                      color: subtext, fontSize: 12)),
                              trailing: selected
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.primary,
                                      size: 20)
                                  : null,
                              onTap: () =>
                                  widget.onPicked(a.id, a.name),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Review Submission Bottom Sheet ──────────────────────────────────────────

class _ReviewSubmissionSheet extends StatefulWidget {
  final String taskId;
  final String submissionId;
  final VoidCallback onDone;

  const _ReviewSubmissionSheet({
    required this.taskId,
    required this.submissionId,
    required this.onDone,
  });

  @override
  State<_ReviewSubmissionSheet> createState() =>
      _ReviewSubmissionSheetState();
}

class _ReviewSubmissionSheetState extends State<_ReviewSubmissionSheet> {
  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _review(String verdict) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiService.instance.patch(
        '/tasks/${widget.taskId}/submissions/${widget.submissionId}',
        body: {
          'verdict': verdict,
          'note': _noteCtrl.text.trim(),
        },
      );
      widget.onDone();
    } catch (e) {
      setState(() {
        _error = cleanError(e);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomNav = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding:
          EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset + bottomNav),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Review submission',
                style: t.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),

            // Note field
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'Review note',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add review comments...',
              ),
            ),
            const SizedBox(height: 16),

            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => _review('REJECTED'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    child: const Text('Reject',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => _review('REVISION_REQUESTED'),
                    child: const Text('Request revision',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting
                        ? null
                        : () => _review('APPROVED'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Approve',
                            style:
                                TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Emoji Picker Grid (admin task chat) ────────────────────────────────────

const _adminCommonEmojis = [
  // Smileys
  '\u{1F600}', '\u{1F602}', '\u{1F605}', '\u{1F60A}', '\u{1F60D}',
  '\u{1F60E}', '\u{1F609}', '\u{1F617}', '\u{1F618}', '\u{1F61C}',
  '\u{1F914}', '\u{1F60F}', '\u{1F612}', '\u{1F644}', '\u{1F62D}',
  '\u{1F621}', '\u{1F92F}', '\u{1F631}', '\u{1F622}', '\u{1F62E}',
  // Gestures
  '\u{1F44D}', '\u{1F44E}', '\u{1F44F}', '\u{1F64F}', '\u{1F4AA}',
  '\u{270C}\u{FE0F}', '\u{1F44B}', '\u{1F91D}', '\u{1F446}', '\u{1F447}',
  // Objects & symbols
  '\u{2764}\u{FE0F}', '\u{1F525}', '\u{1F389}', '\u{1F38A}', '\u{2705}',
  '\u{274C}', '\u{2B50}', '\u{1F4A1}', '\u{1F4AC}', '\u{1F4E2}',
  '\u{1F4C8}', '\u{1F680}', '\u{1F3AF}', '\u{1F4DD}', '\u{1F4BC}',
  '\u{2708}\u{FE0F}', '\u{1F4B0}', '\u{1F4F1}', '\u{2615}', '\u{1F37A}',
];

class _AdminEmojiGrid extends StatelessWidget {
  final void Function(String emoji) onEmojiSelected;
  const _AdminEmojiGrid({required this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: t.cardColor,
        border: Border(top: BorderSide(color: t.dividerColor)),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: _adminCommonEmojis.length,
        itemBuilder: (_, i) {
          final emoji = _adminCommonEmojis[i];
          return GestureDetector(
            onTap: () => onEmojiSelected(emoji),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        },
      ),
    );
  }
}

// ─── Pulsing red dot for recording indicator ────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.4 + _ctrl.value * 0.6),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Voice waveform placeholder (decorative bars) ───────────────────────────

class _VoiceWaveform extends StatelessWidget {
  final bool compact;
  const _VoiceWaveform({this.compact = false});

  static const _barHeights = [6.0, 12.0, 8.0, 16.0, 10.0, 14.0, 7.0, 13.0, 9.0, 15.0, 8.0, 11.0, 6.0, 14.0, 10.0];

  @override
  Widget build(BuildContext context) {
    final bars = compact ? _barHeights.sublist(0, 10) : _barHeights;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: bars.map((h) {
        return Container(
          width: 3,
          height: h,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }
}
