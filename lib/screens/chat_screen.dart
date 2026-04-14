import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'call_screen.dart';

class _Msg {
  final String body;
  final bool mine;
  final DateTime at;
  final bool read;
  _Msg(this.body, this.mine, this.at, {this.read = false});
}

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
  final List<_Msg> _messages = [];
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _messages.addAll([
      _Msg('Hi! Are you ready to start batch 42?', false,
          now.subtract(const Duration(minutes: 18))),
      _Msg('Yes, reviewing the call script now.', true,
          now.subtract(const Duration(minutes: 15)),
          read: true),
      _Msg('Great — start when you are. Deadline is 5pm.', false,
          now.subtract(const Duration(minutes: 14))),
      _Msg('On it. Will ping once first 5 calls are done.', true,
          now.subtract(const Duration(minutes: 12)),
          read: true),
    ]);
    _scrollToEnd(animated: false);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        if (animated) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        } else {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      }
    });
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Msg(text, true, DateTime.now()));
      _input.clear();
    });
    _scrollToEnd();
    // Simulate typing indicator + reply
    setState(() => _typing = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _messages.add(
            _Msg('Got it, thanks!', false, DateTime.now()));
      });
      _scrollToEnd();
    });
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
              backgroundColor: AppColors.accent.withValues(alpha: 0.18),
              child: Text(
                widget.title.isNotEmpty ? widget.title[0] : '?',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(
                    _typing ? 'typing...' : 'online',
                    style: TextStyle(
                      fontSize: 11,
                      color: _typing ? AppColors.accent : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CallScreen(contactName: widget.title),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_typing ? 1 : 0),
              itemBuilder: (_, i) {
                if (_typing && i == _messages.length) {
                  return _typingIndicator(t);
                }
                final msg = _messages[i];
                // Show date separator when day changes
                final showDate = i == 0 ||
                    !_sameDay(
                        _messages[i].at, _messages[i - 1].at);
                return Column(
                  children: [
                    if (showDate) _dateSeparator(msg.at, t),
                    _Bubble(msg: msg),
                  ],
                );
              },
            ),
          ),
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
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Attachments coming soon')),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.mic_rounded),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Voice notes coming soon')),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
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
                  Material(
                    color: AppColors.accent,
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
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

  Widget _typingIndicator(ThemeData t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Padding(
                  padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(
                          alpha: 0.3 + (i * 0.2)),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final time = DateFormat('HH:mm').format(msg.at);
    final bubbleColor = msg.mine
        ? AppColors.accent
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.mine ? 16 : 4),
                  bottomRight: Radius.circular(msg.mine ? 4 : 16),
                ),
                border:
                    msg.mine ? null : Border.all(color: t.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(msg.body, style: TextStyle(color: textColor)),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                      if (msg.mine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.read
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 14,
                          color: msg.read
                              ? Colors.lightBlueAccent
                              : textColor.withValues(alpha: 0.5),
                        ),
                      ],
                    ],
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
