import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/auth_controller.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String threadId;
  final String title;
  const ChatScreen({super.key, required this.threadId, required this.title});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  File? _pendingImage;
  bool _showEmojiPicker = false;

  // Derived contact name (from messages if title is generic)
  String _resolvedTitle = '';

  late String _currentUserId;

  // Voice recording state
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _recordedFilePath;
  int _recordedDuration = 0;
  bool _sendingVoice = false;

  @override
  void initState() {
    super.initState();
    _currentUserId =
        context.read<AuthController>().user?.id ?? '';
    _resolvedTitle = widget.title;
    _loadMessages();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final msgs = await ChatService().messages(
        widget.threadId,
        currentUserId: _currentUserId,
      );
      setState(() {
        _messages = msgs;
        _deriveTitle();
      });
      _scrollToEnd(animated: false);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// If the title is generic ("Chat" or empty), derive from the other
  /// participant's name in the message list.
  void _deriveTitle() {
    if (widget.title.isNotEmpty &&
        widget.title != 'Chat' &&
        widget.title != 'chat') {
      _resolvedTitle = widget.title;
      return;
    }
    // Find the first message that is not ours and has a sender name
    for (final msg in _messages) {
      if (!msg.mine && msg.senderName != null && msg.senderName!.isNotEmpty) {
        _resolvedTitle = msg.senderName!;
        return;
      }
    }
    _resolvedTitle = widget.title;
  }

  void _scrollToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (animated) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  // ─── Voice recording helpers ────────────────────────────────────────────────

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
      final msg = await ChatService().sendVoice(
        widget.threadId,
        File(filePath),
        currentUserId: _currentUserId,
      );
      setState(() {
        _messages.add(msg);
        _recordedFilePath = null;
        _recordedDuration = 0;
      });
      _scrollToEnd();
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

  // ─── Send text / image ──────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _input.text.trim();
    final image = _pendingImage;
    if (text.isEmpty && image == null) return;

    setState(() {
      _sending = true;
      _pendingImage = null;
      _showEmojiPicker = false;
    });
    _input.clear();

    try {
      if (image != null) {
        await _sendImage(image);
      }
      if (text.isNotEmpty) {
        final msg = await ChatService().send(
          widget.threadId,
          text,
          currentUserId: _currentUserId,
        );
        setState(() => _messages.add(msg));
        _scrollToEnd();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Upload image to /media/upload, then send as IMAGE message.
  Future<void> _sendImage(File file) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });
      final uploadResp = await ApiService.instance.dio.post(
        '/media/upload',
        data: formData,
        queryParameters: {'kind': 'IMAGE'},
        options: Options(
          contentType: 'multipart/form-data',
          headers: {'Content-Type': 'multipart/form-data'},
        ),
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
      // Send as IMAGE type
      final resp = await ApiService.instance.post(
        '/communication/conversations/${widget.threadId}/messages',
        body: {
          'type': 'IMAGE',
          'attachmentUrl': uploadedUrl,
          'body': '',
        },
      );
      final data = unwrap<Map<String, dynamic>>(resp);
      final msg = ChatMessage.fromJson(data, currentUserId: _currentUserId);
      if (mounted) {
        setState(() => _messages.add(msg));
      }
      _scrollToEnd();
    } on DioException catch (_) {
      // Fallback: send filename as text if media endpoint fails
      final name = file.path.split('/').last;
      final msg = await ChatService().send(
        widget.threadId,
        '[Image] $name',
        currentUserId: _currentUserId,
      );
      if (mounted) setState(() => _messages.add(msg));
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await _showImageSourceSheet();
    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() => _pendingImage = File(picked.path));
  }

  Future<ImageSource?> _showImageSourceSheet() async {
    return showModalBottomSheet<ImageSource>(
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
  }

  void _insertEmoji(String emoji) {
    final text = _input.text;
    final sel = _input.selection;
    final start = sel.baseOffset >= 0 ? sel.baseOffset : text.length;
    final end = sel.extentOffset >= 0 ? sel.extentOffset : text.length;
    final newText = text.replaceRange(start, end, emoji);
    _input.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.18),
              child: Text(
                _resolvedTitle.isNotEmpty ? _resolvedTitle[0] : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_resolvedTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadMessages,
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: () async {
              // Create call and send meeting link to the chat
              try {
                final resp = await ApiService.instance.post(
                  '/communication/calls',
                  body: {
                    'threadId': widget.threadId,
                    'type': 'VIDEO',
                  },
                );
                final data = unwrap<Map<String, dynamic>>(resp);
                final meetingUrl = data['meetingUrl']?.toString() ??
                    data['jitsiUrl']?.toString() ??
                    data['url']?.toString() ?? '';

                // Send the meeting link as a message so others can join
                if (meetingUrl.isNotEmpty) {
                  ApiService.instance.post(
                    '/communication/conversations/${widget.threadId}/messages',
                    body: {
                      'body': '📞 Meeting started — tap to join:\n$meetingUrl',
                      'type': 'TEXT',
                    },
                  ).catchError((_) => <String, dynamic>{});
                }

                if (!mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CallScreen(
                      contactName: _resolvedTitle,
                      meetingUrl: meetingUrl.isNotEmpty ? meetingUrl : null,
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not start call: ${cleanError(e)}'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Message list ───────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_showEmojiPicker) {
                  setState(() => _showEmojiPicker = false);
                }
              },
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppColors.danger, size: 40),
                              const SizedBox(height: 12),
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppColors.danger)),
                              const SizedBox(height: 12),
                              TextButton(
                                  onPressed: _loadMessages,
                                  child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _messages.isEmpty
                          ? Center(
                              child: Text(
                                'No messages yet. Say hi!',
                                style: TextStyle(color: subtext),
                              ),
                            )
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (_, i) {
                                final msg = _messages[i];
                                final showDate = i == 0 ||
                                    !_sameDay(_messages[i].createdAt,
                                        _messages[i - 1].createdAt);
                                return Column(
                                  children: [
                                    if (showDate)
                                      _dateSeparator(msg.createdAt, t),
                                    _Bubble(
                                      msg: msg,
                                      onMeetingTap: _joinMeeting,
                                      onLaunchUrl: _launchUrl,
                                    ),
                                  ],
                                );
                              },
                            ),
            ),
          ),

          // ── Pending image preview ──────────────────────────
          if (_pendingImage != null)
            Container(
              height: 90,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.cardColor,
                border: Border(top: BorderSide(color: t.dividerColor)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _pendingImage!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pendingImage!.path.split('/').last,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () =>
                        setState(() => _pendingImage = null),
                  ),
                ],
              ),
            ),

          // ── Input bar ──────────────────────────────────────
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
              decoration: BoxDecoration(
                color: t.scaffoldBackgroundColor,
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
                              icon:
                                  const Icon(Icons.close_rounded, size: 20),
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
                                    icon: const Icon(Icons.send_rounded,
                                        color: AppColors.primary, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 36, minHeight: 36),
                                    tooltip: 'Send voice note',
                                  ),
                          ],
                        )
                      // ── Default state: normal input bar ──────────
                      : Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.attach_file_rounded),
                              onPressed: _pickImage,
                              tooltip: 'Attach image',
                            ),
                            IconButton(
                              icon: Icon(
                                _showEmojiPicker
                                    ? Icons.keyboard_rounded
                                    : Icons.emoji_emotions_outlined,
                              ),
                              onPressed: () {
                                setState(() =>
                                    _showEmojiPicker = !_showEmojiPicker);
                              },
                              tooltip:
                                  _showEmojiPicker ? 'Keyboard' : 'Emoji',
                            ),
                            IconButton(
                              icon: Icon(Icons.mic_rounded,
                                  color: subtext, size: 22),
                              onPressed: _startRecording,
                              tooltip: 'Record voice note',
                            ),
                            Expanded(
                              child: TextField(
                                controller: _input,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                onTap: () {
                                  if (_showEmojiPicker) {
                                    setState(
                                        () => _showEmojiPicker = false);
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: 'Message...',
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(24),
                                    borderSide:
                                        BorderSide(color: t.dividerColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(24),
                                    borderSide:
                                        BorderSide(color: t.dividerColor),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _sending
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5),
                                    ),
                                  )
                                : Material(
                                    color: (_input.text.isNotEmpty ||
                                            _pendingImage != null)
                                        ? AppColors.primary
                                        : AppColors.primary
                                            .withValues(alpha: 0.4),
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: _send,
                                      child: const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Icon(Icons.send_rounded,
                                            color: Colors.white,
                                            size: 18),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
            ),
          ),

          // ── Emoji picker ───────────────────────────────────
          if (_showEmojiPicker)
            _EmojiGrid(onEmojiSelected: _insertEmoji),
        ],
      ),
    );
  }

  void _joinMeeting(String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CallScreen(
          contactName: _resolvedTitle,
          meetingUrl: url,
        ),
      ),
    );
  }

  Widget _dateSeparator(DateTime d, ThemeData t) {
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final now = DateTime.now();
    final label = _sameDay(d, now)
        ? 'Today'
        : _sameDay(d, now.subtract(const Duration(days: 1)))
            ? 'Yesterday'
            : DateFormat('MMM d, yyyy').format(d);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: t.cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 11, color: subtext)),
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─── Emoji Picker Grid ──────────────────────────────────────────────────────

const _commonEmojis = [
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

class _EmojiGrid extends StatelessWidget {
  final void Function(String emoji) onEmojiSelected;
  const _EmojiGrid({required this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: t.cardColor,
        border: Border(top: BorderSide(color: t.dividerColor)),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: _commonEmojis.length,
        itemBuilder: (_, i) {
          final emoji = _commonEmojis[i];
          return GestureDetector(
            onTap: () => onEmojiSelected(emoji),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          );
        },
      ),
    );
  }
}

// ─── Bubble ─────────────────────────────────────────────────────────────────

// Detects JaaS / Jitsi meeting URLs embedded in a message body
final _jaasRe = RegExp(r'https://8x8\.vc/[^/\s]+/([^\s/?#]+)');
final _jitsiRe = RegExp(r'https://meet\.jit\.si/([^\s/?#]+)');

bool _isImageUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp');
}

bool _isVoiceUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith('.m4a') ||
      lower.endsWith('.aac') ||
      lower.endsWith('.mp3') ||
      lower.endsWith('.wav') ||
      lower.endsWith('.ogg');
}

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final void Function(String url)? onMeetingTap;
  final Future<void> Function(String url)? onLaunchUrl;

  const _Bubble({required this.msg, this.onMeetingTap, this.onLaunchUrl});

  String? get _meetingUrl {
    final m = _jaasRe.firstMatch(msg.body) ?? _jitsiRe.firstMatch(msg.body);
    return m?.group(0);
  }

  /// Whether this message is a voice note.
  bool get _isVoice {
    if (msg.isVoice) return true;
    final url = msg.attachmentUrl ?? '';
    return msg.type.toUpperCase() == 'VOICE' ||
        (url.isNotEmpty && _isVoiceUrl(url));
  }

  /// Whether this message is an image (by type, attachmentUrl, or body URL).
  bool get _isImage {
    if (msg.type.toUpperCase() == 'IMAGE') return true;
    final url = msg.attachmentUrl ?? '';
    if (url.isNotEmpty && _isImageUrl(url)) return true;
    // Legacy: body itself is an image URL
    final b = msg.body.toLowerCase();
    return b.startsWith('http') &&
        (b.endsWith('.jpg') ||
            b.endsWith('.jpeg') ||
            b.endsWith('.png') ||
            b.endsWith('.gif') ||
            b.endsWith('.webp'));
  }

  /// The best image URL to display.
  String get _imageUrl {
    final url = msg.attachmentUrl ?? '';
    if (url.isNotEmpty && _isImageUrl(url)) return url;
    if (msg.type.toUpperCase() == 'IMAGE' && url.isNotEmpty) return url;
    // Legacy: body is the URL
    return msg.body;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final time = DateFormat('HH:mm').format(msg.createdAt);
    final bubbleColor = msg.mine
        ? AppColors.primary
        : (isDark ? AppColors.darkCard : AppColors.lightCard);
    final textColor = msg.mine
        ? Colors.white
        : (isDark ? AppColors.darkText : AppColors.lightText);
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            msg.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.mine ? 16 : 4),
                  bottomRight: Radius.circular(msg.mine ? 4 : 16),
                ),
                border: msg.mine
                    ? null
                    : Border.all(color: t.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Voice note ──────────────────────────────
                  if (_isVoice) ...[
                    GestureDetector(
                      onTap: () {
                        final url = msg.attachmentUrl ?? '';
                        if (url.isNotEmpty) {
                          onLaunchUrl?.call(url);
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              color: msg.mine
                                  ? Colors.white
                                  : AppColors.primary,
                              size: 22),
                          const SizedBox(width: 6),
                          _VoiceWaveform(
                              compact: true,
                              color: msg.mine
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : null),
                          const SizedBox(width: 6),
                          Text(
                            'Voice note',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: msg.mine
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : subtext,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ]
                  // ── Image attachment ────────────────────────
                  else if (_isImage) ...[
                    GestureDetector(
                      onTap: () => onLaunchUrl?.call(_imageUrl),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _imageUrl,
                          width: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              size: 40),
                        ),
                      ),
                    ),
                    if (msg.body.isNotEmpty &&
                        !msg.body.toLowerCase().startsWith('http') &&
                        !msg.body.startsWith('[Image]'))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(msg.body,
                            style: TextStyle(color: textColor)),
                      ),
                    const SizedBox(height: 4),
                  ]
                  // ── Meeting link ────────────────────────────
                  else if (_meetingUrl != null) ...[
                    Text(msg.body,
                        style: TextStyle(color: textColor, fontSize: 13)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => onMeetingTap?.call(_meetingUrl!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.success
                                  .withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.video_call_rounded,
                                color: AppColors.success, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Join call',
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ]
                  // ── Plain text ──────────────────────────────
                  else ...[
                    Text(msg.body,
                        style: TextStyle(color: textColor)),
                  ],
                  // Timestamp
                  Text(
                    time,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.65),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
  final Color? color;
  const _VoiceWaveform({this.compact = false, this.color});

  static const _barHeights = [
    6.0, 12.0, 8.0, 16.0, 10.0, 14.0, 7.0, 13.0, 9.0, 15.0, 8.0, 11.0, 6.0,
    14.0, 10.0,
  ];

  @override
  Widget build(BuildContext context) {
    final bars = compact ? _barHeights.sublist(0, 10) : _barHeights;
    final barColor = color ?? AppColors.primary.withValues(alpha: 0.5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: bars.map((h) {
        return Container(
          width: 3,
          height: h,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }
}
