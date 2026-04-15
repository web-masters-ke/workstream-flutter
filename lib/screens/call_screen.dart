import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

enum _CallState { preparing, launched, error }

/// Full-screen call UI.
///
/// If [meetingUrl] is provided the call is a real JaaS/Jitsi session:
///   - we launch the URL in the device browser immediately
///   - the screen stays open as a "return" anchor while the user is in-call
///
/// If no meetingUrl: start a backend call session for the contact (by
/// threadId/contactId), get back a JaaS token + url, then launch.
class CallScreen extends StatefulWidget {
  final String contactName;
  final String? meetingUrl;
  final String? threadId;

  const CallScreen({
    super.key,
    required this.contactName,
    this.meetingUrl,
    this.threadId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  _CallState _state = _CallState.preparing;
  String? _resolvedUrl;
  String? _errorMsg;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (widget.meetingUrl != null && widget.meetingUrl!.isNotEmpty) {
      _resolvedUrl = widget.meetingUrl;
      await _launch();
      return;
    }

    // No URL provided — create a call session via backend
    try {
      final resp = await ApiService.instance.post('/communication/calls', body: {
        if (widget.threadId != null) 'threadId': widget.threadId,
        'type': 'VIDEO',
      });
      final data = unwrap<Map<String, dynamic>>(resp);
      final url = data['meetingUrl']?.toString() ??
          data['jitsiUrl']?.toString() ??
          data['url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('No meeting URL returned by server');
      }
      _resolvedUrl = url;
      await _launch();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _CallState.error;
        _errorMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    }
  }

  Future<void> _launch() async {
    final url = _resolvedUrl!;
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (launched) {
      setState(() => _state = _CallState.launched);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
      });
    } else {
      setState(() {
        _state = _CallState.error;
        _errorMsg = 'Could not open the meeting link. '
            'Please install a browser and try again.';
      });
    }
  }

  Future<void> _openAgain() async {
    if (_resolvedUrl == null) return;
    await launchUrl(
      Uri.parse(_resolvedUrl!),
      mode: LaunchMode.externalApplication,
    );
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
            // ── Back / close ───────────────────────────────────
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const Spacer(flex: 2),

            // ── Avatar ─────────────────────────────────────────
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              child: Text(
                widget.contactName.isNotEmpty
                    ? widget.contactName[0].toUpperCase()
                    : 'C',
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

            // ── Status label ───────────────────────────────────
            if (_state == _CallState.preparing)
              Text(
                'Starting call...',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
              )
            else if (_state == _CallState.launched)
              Text(
                'In call · $_timeLabel',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8), fontSize: 15),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMsg ?? 'Something went wrong',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.danger.withValues(alpha: 0.9),
                      fontSize: 14),
                ),
              ),

            if (_state == _CallState.preparing)
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

            // ── Action buttons ─────────────────────────────────
            if (_state == _CallState.launched)
              Column(
                children: [
                  // Re-open the meeting link
                  TextButton.icon(
                    onPressed: _openAgain,
                    icon: const Icon(Icons.open_in_new_rounded,
                        color: AppColors.primary),
                    label: const Text(
                      'Re-open meeting',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _endBtn('End call'),
                ],
              )
            else if (_state == _CallState.error)
              Column(
                children: [
                  TextButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppColors.primary),
                    label: const Text(
                      'Retry',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _endBtn('Go back'),
                ],
              ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _endBtn(String label) {
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
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.call_end_rounded,
                color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
      ],
    );
  }
}
