import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId =
        context.read<AuthController>().user?.id ?? '';
    _loadMessages();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
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
      setState(() => _messages = msgs);
      _scrollToEnd(animated: false);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        await _sendMedia(image);
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

  Future<void> _sendMedia(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });
      final resp = await ApiService.instance.dio.post(
        '/chat/threads/${widget.threadId}/media',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = ApiService.instance.dio.options.baseUrl.isNotEmpty
          ? resp.data
          : resp.data;
      // Backend may return the created message directly or just the URL
      final raw = data is Map<String, dynamic> ? data : <String, dynamic>{};
      final body = raw['data'];
      if (body is Map<String, dynamic>) {
        final msg = ChatMessage.fromJson(body, currentUserId: _currentUserId);
        if (mounted) setState(() => _messages.add(msg));
      }
      _scrollToEnd();
    } on DioException catch (_) {
      // If media endpoint doesn't exist, fall back to sending filename as text
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.18),
              child: Text(
                widget.title.isNotEmpty ? widget.title[0] : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CallScreen(
                  contactName: widget.title,
                  threadId: widget.threadId,
                ),
              ),
            ),
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
                              Icon(Icons.error_outline_rounded,
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
                                style: TextStyle(
                                  color: t.brightness == Brightness.dark
                                      ? AppColors.darkSubtext
                                      : AppColors.lightSubtext,
                                ),
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: t.scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: t.dividerColor)),
              ),
              child: Row(
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
                      setState(
                          () => _showEmojiPicker = !_showEmojiPicker);
                    },
                    tooltip: _showEmojiPicker ? 'Keyboard' : 'Emoji',
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
                          setState(() => _showEmojiPicker = false);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: t.dividerColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: t.dividerColor),
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
                              : AppColors.primary.withValues(alpha: 0.4),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _send,
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(Icons.send_rounded,
                                  color: Colors.white, size: 18),
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
          contactName: widget.title,
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

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final void Function(String url)? onMeetingTap;

  const _Bubble({required this.msg, this.onMeetingTap});

  bool get _isImage {
    final b = msg.body.toLowerCase();
    return b.startsWith('http') &&
        (b.endsWith('.jpg') ||
            b.endsWith('.jpeg') ||
            b.endsWith('.png') ||
            b.endsWith('.gif') ||
            b.endsWith('.webp'));
  }

  String? get _meetingUrl {
    final m = _jaasRe.firstMatch(msg.body) ?? _jitsiRe.firstMatch(msg.body);
    return m?.group(0);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final time = DateFormat('HH:mm').format(msg.createdAt);
    final bubbleColor = msg.mine
        ? AppColors.primary
        : (t.brightness == Brightness.dark
            ? AppColors.darkCard
            : AppColors.lightCard);
    final textColor = msg.mine
        ? Colors.white
        : (t.brightness == Brightness.dark
            ? AppColors.darkText
            : AppColors.lightText);

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
                  // Image attachment
                  if (_isImage) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        msg.body,
                        width: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            size: 40),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ]
                  // Meeting link
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
                  // Plain text
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
