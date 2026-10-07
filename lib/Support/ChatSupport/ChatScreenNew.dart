import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'ChatService.dart';

class ChatScreenNew extends StatefulWidget {
  const ChatScreenNew({super.key});

  @override
  State<ChatScreenNew> createState() => _ChatScreenNewState();
}

class _ChatScreenNewState extends State<ChatScreenNew> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final GetStorage _storage = GetStorage();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  int _lastMessageId = 0;
  int _tempMessageSeq = 0;
  Timer? _pollingTimer;
  /// Push transition can finish after first layout; one-time scroll when it completes.
  bool _didSubscribeRouteAnimation = false;

  /// Max real (server) message id for polling — ignores optimistic negative ids.
  int _maxRealMessageId() {
    var maxId = 0;
    for (final m in _messages) {
      if (m.id > 0 && m.id > maxId) maxId = m.id;
    }
    return maxId;
  }

  void _sortMessagesInPlace() {
    _messages.sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageFocusNode.addListener(_onMessageFocusChanged);
    print('[ChatScreen] Initializing Chat Screen...');
    _loadChatHistory();
    _startPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSubscribeRouteAnimation) return;
    final route = ModalRoute.of(context);
    final anim = route?.animation;
    if (anim == null || anim.status == AnimationStatus.completed) return;
    _didSubscribeRouteAnimation = true;
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        anim.removeStatusListener(listener);
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
    anim.addStatusListener(listener);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageFocusNode.removeListener(_onMessageFocusChanged);
    _messageFocusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  /// Keyboard open/close or IME metrics — keep latest messages in view (WhatsApp-like).
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _scheduleScrollAboveKeyboard();
  }

  void _onMessageFocusChanged() {
    if (_messageFocusNode.hasFocus) {
      _scheduleScrollAboveKeyboard();
    }
  }

  void _scheduleScrollAboveKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom(animated: false);
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (mounted) _scrollToBottom(animated: true);
      });
    });
  }

  /// Load chat history from server
  Future<void> _loadChatHistory() async {
    setState(() => _isLoading = true);

    try {
      final messages = await _chatService.getChatHistory();
      if (!mounted) return;
      // Single setState: avoids extra rebuild after scroll (last msg stayed mid-screen).
      setState(() {
        _messages = List<ChatMessage>.from(messages);
        _sortMessagesInPlace();
        _lastMessageId = _maxRealMessageId();
        _isLoading = false;
      });

      // Opening this screen / refresh: keep latest bubble visible after route + list layout.
      _snapListToLatestMessage();
      print('[ChatScreen] Loaded ${messages.length} messages from history');
    } catch (e) {
      print('[ChatScreen] Error loading chat history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Start polling for new messages every 3 seconds
  void _startPolling() {
    print('[ChatScreen] Starting Poll for new messages...');
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _checkForNewMessages();
    });
  }

  /// Check for new messages from admin
  Future<void> _checkForNewMessages() async {
    try {
      final newMessages = await _chatService.getNewMessages(
        lastMessageId: _lastMessageId,
      );

      if (newMessages.isNotEmpty && mounted) {
        print('[ChatScreen] Received ${newMessages.length} new messages');
        setState(() {
          final existing = _messages.map((m) => m.id).toSet();
          for (final m in newMessages) {
            if (!existing.contains(m.id)) {
              _messages.add(m);
              existing.add(m.id);
            }
          }
          _sortMessagesInPlace();
          _lastMessageId = _maxRealMessageId();
        });

        // Auto-scroll to bottom when new messages arrive
        _scrollToBottomAfterLayout();
      }
    } catch (e) {
      log('[ChatScreen] Error checking new messages: $e');
    }
  }

  /// Pick Media using Native Phone Picker
  Future<void> _pickNativeMedia() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.media,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final extension = path.extension(filePath).toLowerCase();

        String type = 'image';
        if (['.mp4', '.mov', '.avi', '.mkv'].contains(extension)) {
          type = 'video';
        }

        _sendMessage(filePath: filePath, type: type);
      }
    } catch (e) {
      log('[ChatScreen] Error picking native media: $e');
      _showSnackBar('Error picking media');
    }
  }

  /// Pick Image or Video
  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    try {
      XFile? file;
      if (isVideo) {
        file = await _picker.pickVideo(source: source);
      } else {
        file = await _picker.pickImage(source: source, imageQuality: 70);
      }

      if (file != null) {
        _sendMessage(filePath: file.path, type: isVideo ? 'video' : 'image');
      }
    } catch (e) {
      log('[ChatScreen] Error picking media: $e');
      _showSnackBar('Error picking media');
    }
  }

  /// Paperclip: seedha gallery / media picker (bina beech ke menu ke).
  void _openGalleryPicker() {
    FocusScope.of(context).unfocus();
    _pickNativeMedia();
  }

  /// Send message to admin
  Future<void> _sendMessage({String? filePath, String type = 'text'}) async {
    final message = _messageController.text.trim();
    if (message.isEmpty && filePath == null) return;
    if (_isSending && filePath == null) return; // Allow sending multiple media items sequentially

    setState(() => _isSending = true);

    int? tempId;
    try {
      // Optimistic row: unique negative id so rapid sends don't mix rows
      tempId = --_tempMessageSeq;
      final tempMessage = ChatMessage(
        id: tempId,
        senderId: _chatService.currentUserId ?? 0,
        receiverId: ChatService.adminId,
        message: filePath ?? message, // Show local path for images during sending
        type: type,
        createdAt: DateTime.now(),
      );

      setState(() {
        _messages.add(tempMessage);
      });

      _scrollToBottomAfterLayout();
      if (filePath == null) _messageController.clear();

      // Send to server
      final response = await _chatService.sendMessage(
        message: message,
        type: type,
        filePath: filePath,
      );

      final ok = response['status'] == true ||
          response['status'] == 1 ||
          response['status']?.toString().toLowerCase() == 'true';
      if (ok) {
        log('[ChatScreen] Message sent successfully');
        // API returns payload under `data` (fallback `info`)
        final payload = response['data'] ?? response['info'];
        if (payload != null && payload is Map && payload['id'] != null) {
          final info = payload as Map<String, dynamic>;
          final realId = int.tryParse(info['id'].toString()) ?? 0;
          final realMsg = (info['full_image_url'] ??
                  info['message'] ??
                  (filePath ?? message))
              .toString();
          final createdRaw = info['created_at'] ?? info['createdAt'];
          final serverTime = createdRaw != null
              ? ChatMessage.parseCreatedAt(createdRaw)
              : null;

          final index = _messages.indexWhere((m) => m.id == tempId!);
          if (index != -1 && mounted) {
            setState(() {
              _messages[index] = ChatMessage.fromJson(info);
              _sortMessagesInPlace();
              _lastMessageId = _maxRealMessageId();
            });
            _scrollToBottomAfterLayout();
          }
        }
      } else {
        // Remove failed message
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m.id == tempId!);
          });
        }
        _showSnackBar(
          response['msg']?.toString() ??
              response['message']?.toString() ??
              'Failed to send message',
          isError: true,
        );
      }
    } catch (e) {
      log('[ChatScreen] Error sending message: $e');
      // Remove failed message
      if (mounted) {
        setState(() {
          if (tempId != null) {
            _messages.removeWhere((m) => m.id == tempId);
          }
        });
      }
      _showSnackBar('Error sending message', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  /// Scroll to bottom of chat (latest messages stay above the input bar / keyboard).
  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        maxExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(maxExtent);
    }
  }

  /// After [setState], layout is not ready yet — one frame is often not enough for
  /// [maxScrollExtent] to update. Keeps the last sent/received bubble on screen.
  void _scrollToBottomAfterLayout({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom(animated: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToBottom(animated: animated);
      });
    });
  }

  /// When opening the chat or after refresh: route animation + tall images change extent later.
  void _snapListToLatestMessage() {
    if (_messages.isEmpty) return;

    void jumpIfReady() {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }

    _scrollToBottomAfterLayout(animated: false);
    // Catch layout after push transition and progressive image loads.
    Future<void>.delayed(const Duration(milliseconds: 50), jumpIfReady);
    Future<void>.delayed(const Duration(milliseconds: 180), jumpIfReady);
    Future<void>.delayed(const Duration(milliseconds: 380), jumpIfReady);
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _scrollToBottom(animated: true);
    });
  }

  /// Show snackbar
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  /// Format time
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final bottomFabPadding = MediaQuery.paddingOf(context).bottom;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFFCF7F3),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFB74D), // Darker Peach
                Color(0xFFFFCD91), // Peach
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chat Support',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadChatHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E2F97)),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start a conversation with admin',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        behavior: HitTestBehavior.translucent,
                        child: ListView.builder(
                          controller: _scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            12,
                            16,
                            12,
                            8 + (keyboardOpen ? 4 : 0),
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isCurrentUser =
                                message.senderId == _chatService.currentUserId;

                            return _buildMessageBubble(
                              message: message.message,
                              type: message.type,
                              time: message.createdAt,
                              isCurrentUser: isCurrentUser,
                            );
                          },
                        ),
                      ),
          ),

          // Message input — sits above keyboard; home indicator only when keyboard closed
          Material(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black26,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                8,
                8,
                8,
                8 + (keyboardOpen ? 0 : bottomFabPadding),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Type + paperclip (direct gallery) + camera — ek pill ke andar
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFFFCD91).withOpacity(0.5)),
                      ),
                      padding: const EdgeInsets.only(left: 10, right: 2, top: 2, bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              focusNode: _messageFocusNode,
                              maxLines: 6,
                              minLines: 1,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.newline,
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: Color(0xFF8696A0),
                                  fontSize: 15,
                                ),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 4,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF111B21),
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 44,
                            ),
                            onPressed: _openGalleryPicker,
                            tooltip: 'Gallery',
                            icon: const Icon(
                              Icons.photo_library_outlined,
                              color: Color(0xFF54656F),
                              size: 24,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 44,
                            ),
                            onPressed: () => _pickMedia(ImageSource.camera),
                            icon: const Icon(
                              Icons.photo_camera_outlined,
                              color: Color(0xFF54656F),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: const Color(0xFF1E2F97),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isSending ? null : () => _sendMessage(),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: _isSending
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white, size: 22),
                        ),
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

  Widget _buildMessageBubble({
    required String message,
    required String type,
    required DateTime time,
    required bool isCurrentUser,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFFFB74D).withOpacity(0.2),
              child: const Icon(Icons.support_agent, size: 18, color: Color(0xFFFFB74D)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: type == 'image' 
                  ? const EdgeInsets.all(4) 
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isCurrentUser
                    ? const LinearGradient(
                        colors: [Color(0xFF1E2F97), Color(0xFF3F51B5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isCurrentUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isCurrentUser ? 20 : 4),
                  bottomRight: Radius.circular(isCurrentUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (type == 'image')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _buildImagePreview(message),
                    )
                  else if (type == 'video')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _buildVideoPreview(message),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: isCurrentUser ? Colors.white : Colors.black87,
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 4, left: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(time),
                          style: TextStyle(
                            color: isCurrentUser
                                ? Colors.white70
                                : Colors.grey.shade500,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.done_all,
                            size: 14,
                            color: Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// Build Image Preview
  Widget _buildImagePreview(String imageUrl) {
    // A more robust check for local vs remote
    final bool isLocal = !imageUrl.startsWith('http') && (File(imageUrl).existsSync());
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: () => _showFullScreenMedia(imageUrl, isVideo: false),
        child: isLocal
            ? Image.file(
                File(imageUrl),
                fit: BoxFit.cover,
                width: double.infinity,
                height: 220,
                errorBuilder: (context, error, stackTrace) => _buildImageError(),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 220,
                placeholder: (context, url) => Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1E2F97),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildImageError(),
              ),
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 40),
          const SizedBox(height: 8),
          Text(
            'Failed to load image',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Build Video Preview
  Widget _buildVideoPreview(String videoUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () => _showFullScreenMedia(videoUrl, isVideo: true),
        child: Container(
          width: double.infinity,
          height: 150,
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'VIDEO',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show Full Screen Media
  void _showFullScreenMedia(String url, {required bool isVideo}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenMediaViewer(url: url, isVideo: isVideo),
      ),
    );
  }
}

class FullScreenMediaViewer extends StatefulWidget {
  final String url;
  final bool isVideo;

  const FullScreenMediaViewer({super.key, required this.url, required this.isVideo});

  @override
  State<FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<FullScreenMediaViewer> {
  ChewieController? _chewieController;
  VideoPlayerController? _videoPlayerController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final bool isLocal = !widget.url.startsWith('http');
    _videoPlayerController = isLocal
        ? VideoPlayerController.file(File(widget.url))
        : VideoPlayerController.networkUrl(Uri.parse(widget.url));

    await _videoPlayerController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoPlayerController!.value.aspectRatio,
    );

    setState(() {
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: widget.isVideo
            ? _initialized
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator()
            : InteractiveViewer(
                child: !widget.url.startsWith('http')
                    ? Image.file(File(widget.url))
                    : CachedNetworkImage(
                        imageUrl: widget.url,
                        placeholder: (context, url) => const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                      ),
              ),
      ),
    );
  }
}
