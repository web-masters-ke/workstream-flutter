import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum _CallState { connecting, connected, ended }

/// Placeholder call UI. No actual VoIP — just the visual flow.
class CallScreen extends StatefulWidget {
  final String contactName;
  const CallScreen({super.key, required this.contactName});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  _CallState _state = _CallState.connecting;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Simulate connection delay
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _state = _CallState.connected);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _end() {
    _timer?.cancel();
    setState(() => _state = _CallState.ended);
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  String get _timeLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDeep,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              child: Text(
                widget.contactName.isNotEmpty
                    ? widget.contactName[0].toUpperCase()
                    : 'B',
                style: const TextStyle(
                    fontSize: 36,
                    color: Colors.white,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.contactName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _state == _CallState.connecting
                  ? 'Connecting...'
                  : _state == _CallState.connected
                      ? _timeLabel
                      : 'Call ended',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
            ),
            if (_state == _CallState.connecting)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                        Colors.white.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            const Spacer(flex: 3),
            if (_state != _CallState.ended)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _callBtn(Icons.mic_off_rounded, 'Mute', () {}),
                  _callBtn(Icons.volume_up_rounded, 'Speaker', () {}),
                  _endBtn(),
                ],
              )
            else
              const SizedBox.shrink(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _callBtn(IconData icon, String label, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: onTap,
            icon: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
      ],
    );
  }

  Widget _endBtn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.danger,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _end,
            icon: const Icon(Icons.call_end_rounded,
                color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text('End',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
      ],
    );
  }
}
