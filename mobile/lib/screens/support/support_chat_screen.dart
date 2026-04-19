import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    try {
      final res = await api.getSupportMessages();
      if (!mounted) return;
      final msgs = List<Map<String, dynamic>>.from(res['messages'] as List? ?? []);
      setState(() { _messages = msgs; _loading = false; });
      if (msgs.isNotEmpty) _scrollToBottom();
    } catch (_) {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final api  = ApiService(auth.token!);
    _msgCtrl.clear();
    setState(() => _sending = true);
    try {
      final res = await api.sendSupportMessage(text);
      if (!mounted) return;
      setState(() {
        _messages.add(Map<String, dynamic>.from(res));
        _sending = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Myraba Support'),
            Text('We typically reply within a few hours',
              style: TextStyle(fontSize: 11, color: context.mc.textHint,
                fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildBubble(_messages[i]),
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: MyrabaColors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.support_agent_rounded,
                color: MyrabaColors.green, size: 36),
            ),
            const SizedBox(height: 20),
            Text('How can we help?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: context.mc.textPrimary)),
            const SizedBox(height: 8),
            Text('Send us a message and our support team will get back to you as soon as possible.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.mc.textSecond, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final isUser = msg['sender'] == 'USER';
    final content = msg['content'] as String? ?? '';
    final createdAt = msg['createdAt'] as String?;

    String timeStr = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        timeStr = DateFormat('h:mm a').format(dt);
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: MyrabaColors.green.withValues(alpha: 0.15),
              child: Icon(Icons.support_agent_rounded,
                color: MyrabaColors.green, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                      ? MyrabaColors.green
                      : context.mc.surface,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(16),
                      topRight:    const Radius.circular(16),
                      bottomLeft:  Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser ? null : Border.all(color: context.mc.surfaceLine),
                  ),
                  child: Text(content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUser ? Colors.white : context.mc.textPrimary,
                      height: 1.4,
                    )),
                ),
                if (timeStr.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(timeStr,
                      style: TextStyle(fontSize: 10, color: context.mc.textHint)),
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 8,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: context.mc.surface,
        border: Border(top: BorderSide(color: context.mc.surfaceLine)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              maxLines: null,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Type a message…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: context.mc.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: MyrabaColors.green,
                shape: BoxShape.circle,
              ),
              child: _sending
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
