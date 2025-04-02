import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'LobbyScreen.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'RecordingManager.dart';

// Custom class to store chat messages without relying on HMSPeer
class ChatMessage {
  final String messageId;
  final String? senderPeerId;
  final String? senderName;
  final String? senderUsername;
  final String message;
  final String type;
  final DateTime time;

  ChatMessage({
    required this.messageId,
    required this.senderPeerId,
    required this.senderName,
    required this.senderUsername,
    required this.message,
    required this.type,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
    'messageId': messageId,
    'senderPeerId': senderPeerId,
    'senderName': senderName,
    'senderUsername': senderUsername,
    'message': message,
    'type': type,
    'time': time.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    messageId: json['messageId'],
    senderPeerId: json['senderPeerId'],
    senderName: json['senderName'],
    senderUsername: json['senderUsername'],
    message: json['message'],
    type: json['type'],
    time: DateTime.parse(json['time']),
  );

  factory ChatMessage.fromHMSMessage(HMSMessage hmsMessage, String? username) => ChatMessage(
    messageId: hmsMessage.messageId,
    senderPeerId: hmsMessage.sender?.peerId,
    senderName: hmsMessage.sender?.name,
    senderUsername: username,
    message: hmsMessage.message,
    type: hmsMessage.type,
    time: hmsMessage.time,
  );
}

class MeetingScreen extends StatefulWidget {
  final HMSSDK hmsSDK;
  final List<HMSPeer> peers;
  final List<HMSVideoTrack> videoTracks;
  final bool initialVideoOn;
  final bool initialAudioOn;
  final String meetingToken;
  final String username;
  final String sessionTitle;

  const MeetingScreen({
    Key? key,
    required this.hmsSDK,
    required this.peers,
    required this.videoTracks,
    required this.initialVideoOn,
    required this.initialAudioOn,
    required this.meetingToken,
    required this.username,
    required this.sessionTitle,
  }) : super(key: key);

  @override
  _MeetingScreenState createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> with TickerProviderStateMixin implements HMSUpdateListener {
  late bool _isVideoOn;
  late bool _isAudioOn;
  late List<HMSPeer> _peers;
  late List<HMSVideoTrack> _videoTracks;
  HMSPeer? _localPeer;
  final Map<String, HMSVideoTrack> _peerIdToTrackMap = {};
  bool _hasLeftMeeting = false;
  bool _isLoading = false;
  bool _isTogglingVideo = false;
  bool _isTogglingAudio = false;
  bool _isInstructor = false;
  bool _isAllMuted = false;
  bool _isMutedByInstructor = false;

  // Chat-related state
  final List<ChatMessage> _messages = [];
  bool _isChatOpen = false;
  int _unreadMessageCount = 0;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _showScrollToBottom = false;

  // Typing indicator state
  final List<String> _typingPeers = [];
  final Map<String, Timer> _typingTimers = {};
  bool _isTyping = false;
  Timer? _typingDebounceTimer;

  // Raise Hand state
  final List<String> _raisedHands = [];

  // Session Timer state
  Timer? _sessionTimer;
  Duration _sessionDuration = Duration.zero;
  DateTime? _joinTime;

  // Recording state
  late RecordingManager _recordingManager;
  bool _isRecording = false;
  bool _isTogglingRecording = false;
  late AnimationController _recordingBlinkController;
  late Animation<double> _recordingBlinkAnimation;

  // Animation for video tiles
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _isVideoOn = widget.initialVideoOn;
    _isAudioOn = widget.initialAudioOn;
    _peers = widget.peers.where((peer) => peer.name.isNotEmpty && peer.name != "Unknown").toSet().toList();
    _videoTracks = List.from(widget.videoTracks);
    _recordingManager = RecordingManager(
      hmsSDK: widget.hmsSDK,
      onRecordingStateChanged: (bool isRecording) {
        setState(() {
          _isRecording = isRecording;
          if (_isRecording) {
            _recordingBlinkController.repeat();
          } else {
            _recordingBlinkController.stop();
          }
        });
      },
    );
    _loadChatMessages();
    _fetchLocalPeerAndSetup();
    widget.hmsSDK.addUpdateListener(listener: this);

    // Initialize recording blink animation
    _recordingBlinkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _recordingBlinkAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _recordingBlinkController, curve: Curves.easeInOut),
    );

    // Initialize fade animation for video tiles
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();

    // Chat scroll listener for "scroll to bottom" button
    _chatScrollController.addListener(() {
      if (_chatScrollController.offset < _chatScrollController.position.maxScrollExtent - 50) {
        setState(() {
          _showScrollToBottom = true;
        });
      } else {
        setState(() {
          _showScrollToBottom = false;
        });
      }
    });
  }

  Future<void> _loadChatMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? messagesJson = prefs.getString('chat_messages_${widget.meetingToken}');
    if (messagesJson != null) {
      try {
        final List<dynamic> messagesList = jsonDecode(messagesJson);
        setState(() {
          _messages.addAll(messagesList.map((msg) => ChatMessage.fromJson(msg)));
        });
      } catch (e) {
        print('Error loading chat messages: $e');
      }
    }
  }

  Future<void> _saveChatMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> messagesList = _messages.map((msg) => msg.toJson()).toList();
    await prefs.setString('chat_messages_${widget.meetingToken}', jsonEncode(messagesList));
  }

  void _startSessionTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedJoinTime = prefs.getString('join_time_${widget.meetingToken}');
    if (storedJoinTime != null) {
      _joinTime = DateTime.parse(storedJoinTime);
    } else {
      _joinTime = DateTime.now();
      await prefs.setString('join_time_${widget.meetingToken}', _joinTime!.toIso8601String());
    }
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _sessionDuration = DateTime.now().difference(_joinTime!);
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Future<void> _fetchLocalPeerAndSetup() async {
    try {
      setState(() {
        _isLoading = true;
      });
      _localPeer = await widget.hmsSDK.getLocalPeer();
      if (_localPeer != null) {
        _isInstructor = _localPeer!.role.name.toLowerCase() == "instructor";
        if (!_isInstructor && _localPeer!.metadata != null && _localPeer!.metadata!.isNotEmpty) {
          try {
            Map<String, dynamic> metadata = jsonDecode(_localPeer!.metadata!);
            if (metadata['handRaised'] == true) {
              _raisedHands.add(_localPeer!.peerId);
            }
          } catch (e) {
            print('Error parsing local peer metadata: $e');
          }
        }
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          bool currentVideoState = await _isVideoCurrentlyOn();
          bool currentAudioState = await _isAudioCurrentlyOn();
          if (currentVideoState != _isVideoOn) {
            await widget.hmsSDK.toggleCameraMuteState();
          }
          if (currentAudioState != _isAudioOn) {
            await widget.hmsSDK.toggleMicMuteState();
          }
          HMSLocalPeer? localPeer = await widget.hmsSDK.getLocalPeer();
          if (localPeer != null) {
            bool videoState = localPeer.videoTrack != null && !localPeer.videoTrack!.isMute;
            bool audioState = localPeer.audioTrack != null && !localPeer.audioTrack!.isMute;
            if (videoState == _isVideoOn && audioState == _isAudioOn) {
              break;
            }
          }
        }
        await _updateLocalTracks();
        HMSLocalPeer? localPeer = await widget.hmsSDK.getLocalPeer();
        if (localPeer != null) {
          setState(() {
            _isVideoOn = localPeer.videoTrack != null && !localPeer.videoTrack!.isMute;
            _isAudioOn = localPeer.audioTrack != null && !localPeer.audioTrack!.isMute;
          });
        }
      }
    } catch (e) {
      print('Error fetching local peer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch local peer: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _isVideoCurrentlyOn() async {
    HMSLocalPeer? localPeer = await widget.hmsSDK.getLocalPeer();
    return localPeer?.videoTrack != null && !localPeer!.videoTrack!.isMute;
  }

  Future<bool> _isAudioCurrentlyOn() async {
    HMSLocalPeer? localPeer = await widget.hmsSDK.getLocalPeer();
    return localPeer?.audioTrack != null && !localPeer!.audioTrack!.isMute;
  }

  @override
  void dispose() {
    widget.hmsSDK.removeUpdateListener(listener: this);
    widget.hmsSDK.toggleCameraMuteState();
    widget.hmsSDK.toggleMicMuteState();
    if (_isInstructor && _isRecording) {
      _recordingManager.stopRecording();
    }
    _recordingManager.dispose();
    _videoTracks.clear();
    _peerIdToTrackMap.clear();
    _peers.clear();
    _localPeer = null;
    _messageController.dispose();
    _chatScrollController.dispose();
    _typingDebounceTimer?.cancel();
    _typingTimers.forEach((_, timer) => timer.cancel());
    _sessionTimer?.cancel();
    _recordingBlinkController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _updateLocalTracks() async {
    try {
      HMSLocalPeer? localPeer = await widget.hmsSDK.getLocalPeer();
      if (localPeer != null && _localPeer != null) {
        setState(() {
          final videoTrack = localPeer.videoTrack;
          if (_isVideoOn && videoTrack != null) {
            _peerIdToTrackMap[_localPeer!.peerId] = videoTrack;
            if (!_videoTracks.contains(videoTrack)) _videoTracks.add(videoTrack);
          } else {
            _peerIdToTrackMap.remove(_localPeer!.peerId);
            _videoTracks.removeWhere((track) => track == _peerIdToTrackMap[_localPeer!.peerId]);
          }
        });
      }
    } catch (e) {
      print('Error updating local tracks: $e');
    }
  }

  Future<void> _toggleVideo() async {
    if (_isTogglingVideo || _isLoading) return;
    setState(() {
      _isTogglingVideo = true;
    });
    try {
      await widget.hmsSDK.toggleCameraMuteState();
      HMSLocalPeer? localPeer = await widget.hmsSDK.getLocalPeer();
      if (localPeer != null) {
        setState(() {
          _isVideoOn = localPeer.videoTrack != null && !localPeer.videoTrack!.isMute;
        });
        await _updateLocalTracks();
      }
    } catch (e) {
      print('Error toggling video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle video: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingVideo = false;
        });
      }
    }
  }

  Future<void> _toggleAudio() async {
    if (_isTogglingAudio || _isLoading) return;
    if (!_isInstructor && _isMutedByInstructor && !_isAudioOn) {
      _showNotification("You cannot unmute yourself while muted by the instructor.");
      return;
    }
    setState(() {
      _isTogglingAudio = true;
    });
    try {
      await widget.hmsSDK.toggleMicMuteState();
      HMSLocalPeer? localPeer = await widget.hmsSDK.getLocalPeer();
      if (localPeer != null) {
        setState(() {
          _isAudioOn = localPeer.audioTrack != null && !localPeer.audioTrack!.isMute;
        });
      }
    } catch (e) {
      print('Error toggling audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle audio: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingAudio = false;
        });
      }
    }
  }

  Future<void> _toggleMuteAll() async {
    try {
      List<HMSRole> roles = await widget.hmsSDK.getRoles();
      List<HMSRole> nonInstructorRoles = roles.where((role) => role.name.toLowerCase() != "instructor").toList();
      if (nonInstructorRoles.isNotEmpty) {
        await widget.hmsSDK.changeTrackStateForRole(
          mute: !_isAllMuted,
          kind: HMSTrackKind.kHMSTrackKindAudio,
          source: "regular",
          roles: nonInstructorRoles,
        );
        await widget.hmsSDK.sendBroadcastMessage(
          message: _isAllMuted ? "unmuted_by_instructor" : "muted_by_instructor",
          type: "control",
        );
        setState(() {
          _isAllMuted = !_isAllMuted;
        });
        _showNotification(_isAllMuted ? "All participants muted" : "All participants unmuted");
      }
    } catch (e) {
      print("Error toggling mute state: $e");
      _showNotification("Error toggling mute state: $e");
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isInstructor || _isTogglingRecording) return;
    setState(() {
      _isTogglingRecording = true;
    });
    try {
      bool success;
      if (_isRecording) {
        success = await _recordingManager.stopRecording();
        if (success) {
          await widget.hmsSDK.sendBroadcastMessage(
            message: "recording_stopped",
            type: "control",
          );
          _showNotification("Recording stopped");
        } else {
          _showNotification("Failed to stop recording");
        }
      } else {
        success = await _recordingManager.startRecording();
        if (success) {
          await widget.hmsSDK.sendBroadcastMessage(
            message: "recording_started",
            type: "control",
          );
          _showNotification("Recording started");
        } else {
          _showNotification("Failed to start recording");
        }
      }
    } catch (e) {
      print('Error toggling recording: $e');
      _showNotification("Error toggling recording: $e");
    } finally {
      setState(() {
        _isTogglingRecording = false;
      });
    }
  }

  Future<void> _checkRecordingState() async {
    bool isRecording = await _recordingManager.checkRecordingState();
    setState(() {
      _isRecording = isRecording;
      if (_isRecording) {
        _recordingBlinkController.repeat();
      }
    });
  }

  Future<void> _leaveMeeting() async {
    try {
      await widget.hmsSDK.leave();
      if (mounted) {
        setState(() {
          _hasLeftMeeting = true;
        });
        _sessionTimer?.cancel();
      }
    } catch (e) {
      print('Error leaving meeting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave meeting: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _rejoinMeeting() {
    setState(() {
      _hasLeftMeeting = false;
      _peers.clear();
      _videoTracks.clear();
      _peerIdToTrackMap.clear();
      _localPeer = null;
      _raisedHands.clear();
      _isAllMuted = false;
      _isMutedByInstructor = false;
      _sessionDuration = Duration.zero;
      _joinTime = null;
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LobbyScreen(
          hmsSDK: widget.hmsSDK,
          meetingToken: widget.meetingToken,
          username: widget.username,
          sessionTitle: widget.sessionTitle,
        ),
      ),
    );
  }

  void _exitToMySessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('join_time_${widget.meetingToken}');
    Navigator.pushNamedAndRemoveUntil(context, '/my_sessions', (Route<dynamic> route) => false);
  }

  void _showParticipantsList() {
    TextEditingController searchController = TextEditingController();
    List<HMSPeer> filteredPeers = List.from(_peers);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Participants',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search participants...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          filteredPeers = _peers
                              .where((peer) => peer.name.toLowerCase().contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredPeers.length,
                      itemBuilder: (context, index) {
                        final peer = filteredPeers[index];
                        bool isMuted = peer.isLocal ? !_isAudioOn : (peer.audioTrack?.isMute ?? true);
                        bool isPeerInstructor = peer.role.name.toLowerCase() == "instructor";
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getPeerColor(peer.name),
                            child: Text(
                              _getInitials(peer.name),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                peer.name,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              if (!isPeerInstructor && _raisedHands.contains(peer.peerId)) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.pan_tool,
                                  color: Colors.yellow,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isMuted ? Icons.mic_off : Icons.mic,
                                color: isMuted ? Colors.red : Colors.green,
                              ),
                              if (_isInstructor && !isPeerInstructor) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    isMuted ? Icons.volume_up : Icons.volume_off,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () async {
                                    await widget.hmsSDK.changeTrackStateForRole(
                                      mute: !isMuted,
                                      kind: HMSTrackKind.kHMSTrackKindAudio,
                                      source: "regular",
                                      roles: [peer.role],
                                    );
                                    _showNotification(isMuted ? "${peer.name} unmuted" : "${peer.name} muted");
                                  },
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showNotification(String message) {
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Color _getPeerColor(String name) {
    final int hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    return Colors.primaries[hash % Colors.primaries.length];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  void _openChat() {
    setState(() {
      _isChatOpen = true;
      _unreadMessageCount = 0;
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildChatBottomSheet(),
    ).whenComplete(() {
      setState(() {
        _isChatOpen = false;
      });
    });
  }

  Future<void> _sendMessage(VoidCallback updateChatUI) async {
    if (_messageController.text.trim().isEmpty) return;
    String messageText = _messageController.text.trim();
    try {
      String tempMessageId = const Uuid().v4();
      ChatMessage sentMessage = ChatMessage(
        messageId: tempMessageId,
        senderPeerId: _localPeer?.peerId,
        senderName: _localPeer?.name,
        senderUsername: widget.username,
        message: messageText,
        type: "chat",
        time: DateTime.now(),
      );
      setState(() {
        _messages.add(sentMessage);
        _messageController.clear();
      });
      await _saveChatMessages();
      updateChatUI();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      await widget.hmsSDK.sendBroadcastMessage(
        message: messageText,
        type: "chat",
      );
      _isTyping = false;
      _typingDebounceTimer?.cancel();
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _sendTypingEvent() {
    if (!_isTyping) {
      _isTyping = true;
      widget.hmsSDK.sendBroadcastMessage(
        message: "typing",
        type: "typing",
      );
    }
    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = Timer(const Duration(seconds: 3), () {
      _isTyping = false;
    });
  }

  Future<void> _toggleRaiseHand() async {
    if (_isInstructor) return;
    try {
      if (_localPeer == null) return;
      bool isHandRaised = _raisedHands.contains(_localPeer!.peerId);
      Map<String, dynamic> currentMetadata;
      if (_localPeer!.metadata == null || _localPeer!.metadata!.isEmpty) {
        currentMetadata = {"isBRBOn": false};
      } else {
        try {
          currentMetadata = jsonDecode(_localPeer!.metadata!) as Map<String, dynamic>;
        } catch (e) {
          currentMetadata = {"isBRBOn": false};
        }
      }
      if (isHandRaised) {
        currentMetadata['handRaised'] = false;
        currentMetadata.remove("handRaisedAt");
        String updatedMetadata = jsonEncode(currentMetadata);
        await widget.hmsSDK.changeMetadata(metadata: updatedMetadata);
        setState(() {
          _raisedHands.remove(_localPeer!.peerId);
        });
      } else {
        currentMetadata['handRaised'] = true;
        currentMetadata["handRaisedAt"] = DateTime.now().millisecondsSinceEpoch;
        String updatedMetadata = jsonEncode(currentMetadata);
        await widget.hmsSDK.changeMetadata(metadata: updatedMetadata);
        setState(() {
          _raisedHands.add(_localPeer!.peerId);
        });
      }
    } catch (e) {
      print('Error toggling raise hand: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle raise hand: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void onJoin({required HMSRoom room}) {
    setState(() {
      _peers = (room.peers ?? []).where((peer) => peer.name.isNotEmpty && peer.name != "Unknown").toSet().toList();
      for (var peer in _peers) {
        if (peer.metadata != null && peer.metadata!.isNotEmpty) {
          try {
            Map<String, dynamic> metadata = jsonDecode(peer.metadata!);
            if (metadata['handRaised'] == true || metadata.containsKey('handRaisedAt')) {
              _raisedHands.add(peer.peerId);
            }
          } catch (e) {
            print('Error parsing metadata for peer ${peer.name}: $e');
          }
        }
      }
    });
    _updateLocalTracks();
    _startSessionTimer();
    if (_isInstructor) {
      _checkRecordingState();
    }
  }

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    if (peer.name.isEmpty || peer.name == "Unknown") return;
    setState(() {
      if (update == HMSPeerUpdate.peerJoined) {
        if (!_peers.any((p) => p.peerId == peer.peerId)) {
          _peers.add(peer);
          if (peer.metadata != null && peer.metadata!.isNotEmpty) {
            try {
              Map<String, dynamic> metadata = jsonDecode(peer.metadata!);
              if (metadata['handRaised'] == true || metadata.containsKey('handRaisedAt')) {
                _raisedHands.add(peer.peerId);
              }
            } catch (e) {
              print('Error parsing metadata for joining peer ${peer.name}: $e');
            }
          }
          _showNotification('${peer.name} joined the meeting');
        }
      } else if (update == HMSPeerUpdate.peerLeft) {
        _peers.removeWhere((p) => p.peerId == peer.peerId);
        _peerIdToTrackMap.remove(peer.peerId);
        _videoTracks.removeWhere((track) => _peerIdToTrackMap[peer.peerId] == track);
        _raisedHands.remove(peer.peerId);
        _showNotification('${peer.name} left the meeting');
      } else if (update == HMSPeerUpdate.handRaiseUpdated || update == HMSPeerUpdate.metadataChanged) {
        bool isHandRaised = false;
        if (peer.metadata != null && peer.metadata!.isNotEmpty) {
          try {
            Map<String, dynamic> metadata = jsonDecode(peer.metadata!);
            if (metadata['handRaised'] == true || metadata.containsKey('handRaisedAt')) {
              isHandRaised = true;
            }
          } catch (e) {
            print('Error parsing metadata for peer ${peer.name}: $e');
          }
        }
        if (isHandRaised) {
          if (!_raisedHands.contains(peer.peerId)) {
            _raisedHands.add(peer.peerId);
            bool isPeerInstructor = peer.role.name.toLowerCase() == "instructor";
            if (!_isInstructor && !isPeerInstructor && peer.peerId != _localPeer?.peerId) {
              _showNotification('${peer.name} raised their hand');
            }
          }
        } else {
          if (_raisedHands.contains(peer.peerId)) {
            _raisedHands.remove(peer.peerId);
          }
        }
      }
      int peerIndex = _peers.indexWhere((p) => p.peerId == peer.peerId);
      if (peerIndex != -1) {
        _peers[peerIndex] = peer;
      }
    });
  }

  @override
  void onTrackUpdate({required HMSTrack track, required HMSTrackUpdate trackUpdate, required HMSPeer peer}) {
    setState(() {
      if (track.kind == HMSTrackKind.kHMSTrackKindVideo) {
        if (trackUpdate == HMSTrackUpdate.trackAdded) {
          final videoTrack = track as HMSVideoTrack;
          if (!_videoTracks.contains(videoTrack)) {
            _videoTracks.add(videoTrack);
            _peerIdToTrackMap[peer.peerId] = videoTrack;
          }
        } else if (trackUpdate == HMSTrackUpdate.trackRemoved) {
          _videoTracks.remove(track);
          _peerIdToTrackMap.remove(peer.peerId);
        }
      } else if (track.kind == HMSTrackKind.kHMSTrackKindAudio) {
        int peerIndex = _peers.indexWhere((p) => p.peerId == peer.peerId);
        if (peerIndex != -1) {
          _peers[peerIndex] = peer;
        }
        if (peer.isLocal) {
          _isAudioOn = !track.isMute;
        }
      }
    });
  }

  @override
  void onMessage({required HMSMessage message, VoidCallback? updateChatUI}) {
    setState(() {
      if (message.type == "typing") {
        if (message.sender != null && message.sender!.peerId != _localPeer?.peerId) {
          String peerId = message.sender!.peerId;
          if (!_typingPeers.contains(peerId)) {
            _typingPeers.add(peerId);
            updateChatUI?.call();
          }
          _typingTimers[peerId]?.cancel();
          _typingTimers[peerId] = Timer(const Duration(seconds: 5), () {
            setState(() {
              _typingPeers.remove(peerId);
              _typingTimers.remove(peerId);
              updateChatUI?.call();
            });
          });
        }
      } else if (message.type == "control") {
        if (message.message == "muted_by_instructor" && !_isInstructor) {
          _isMutedByInstructor = true;
        } else if (message.message == "unmuted_by_instructor" && !_isInstructor) {
          _isMutedByInstructor = false;
        } else if (message.message == "recording_started" && !_isInstructor) {
          _isRecording = true;
          _recordingBlinkController.repeat();
          _showNotification("Recording has started");
        } else if (message.message == "recording_stopped" && !_isInstructor) {
          _isRecording = false;
          _recordingBlinkController.stop();
          _showNotification("Recording has stopped");
        }
      } else {
        bool isDuplicate = _messages.any((msg) =>
        msg.message == message.message &&
            msg.senderPeerId == message.sender?.peerId &&
            msg.time.difference(message.time).inSeconds.abs() < 2);
        if (!isDuplicate) {
          String? usernameToStore = (message.sender?.peerId == _localPeer?.peerId) ? widget.username : null;
          _messages.add(ChatMessage.fromHMSMessage(message, usernameToStore));
          _saveChatMessages();
          if (!_isChatOpen) {
            _unreadMessageCount++;
          }
          updateChatUI?.call();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_chatScrollController.hasClients) {
              _chatScrollController.animateTo(
                _chatScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    });
  }

  @override
  void onRoomUpdate({required HMSRoom room, required HMSRoomUpdate update}) {
    if (update == HMSRoomUpdate.serverRecordingStateUpdated) {
      _recordingManager.checkRecordingState().then((isRecording) {
        setState(() {
          _isRecording = isRecording;
          if (_isRecording) {
            _recordingBlinkController.repeat();
          } else {
            _recordingBlinkController.stop();
          }
        });
      });
    }
  }

  @override
  void onPeerListUpdate({required List<HMSPeer> addedPeers, required List<HMSPeer> removedPeers}) {
    setState(() {
      for (var peer in addedPeers) {
        if (peer.name.isEmpty || peer.name == "Unknown") continue;
        if (!_peers.any((p) => p.peerId == peer.peerId)) {
          _peers.add(peer);
          if (peer.metadata != null && peer.metadata!.isNotEmpty) {
            try {
              Map<String, dynamic> metadata = jsonDecode(peer.metadata!);
              if (metadata['handRaised'] == true || metadata.containsKey('handRaisedAt')) {
                _raisedHands.add(peer.peerId);
              }
            } catch (e) {
              print('Error parsing metadata for added peer ${peer.name}: $e');
            }
          }
          _showNotification('${peer.name} joined the meeting');
        }
      }
      for (var peer in removedPeers) {
        _peers.removeWhere((p) => p.peerId == peer.peerId);
        _peerIdToTrackMap.remove(peer.peerId);
        _videoTracks.removeWhere((track) => _peerIdToTrackMap[peer.peerId] == track);
        _raisedHands.remove(peer.peerId);
        _showNotification('${peer.name} left the meeting');
      }
    });
  }

  @override
  void onRemovedFromRoom({required HMSPeerRemovedFromPeer hmsPeerRemovedFromPeer}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('join_time_${widget.meetingToken}');
    if (mounted) {
      setState(() {
        _hasLeftMeeting = true;
      });
      _sessionTimer?.cancel();
    }
  }

  @override
  void onError({required HMSException error}) {}
  @override
  void onRoleChangeRequest({required HMSRoleChangeRequest roleChangeRequest}) {}
  @override
  void onUpdateSpeakers({required List<HMSSpeaker> updateSpeakers}) {}
  @override
  void onReconnecting() {}
  @override
  void onReconnected() {}
  @override
  void onAudioDeviceChanged({HMSAudioDevice? currentAudioDevice, List<HMSAudioDevice>? availableAudioDevice}) {}
  @override
  void onChangeTrackStateRequest({required HMSTrackChangeRequest hmsTrackChangeRequest}) {}
  @override
  void onHMSError({required HMSException error}) {}
  @override
  void onSessionStoreAvailable({HMSSessionStore? hmsSessionStore}) {}

  @override
  Widget build(BuildContext context) {
    if (_hasLeftMeeting) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.waving_hand, color: Colors.yellow, size: 50),
                const SizedBox(height: 16),
                const Text(
                  'You left the room',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Have a nice day, ${widget.username}!',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Left by mistake? ',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    GestureDetector(
                      onTap: _rejoinMeeting,
                      child: const Text(
                        'Rejoin',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  text: 'Exit',
                  onTap: _exitToMySessions,
                  isLoading: false,
                  gradient: const LinearGradient(colors: [Colors.red, Colors.redAccent]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    HMSPeer? instructorPeer;
    for (var peer in _peers) {
      if (peer.role.name.toLowerCase() == "instructor") {
        instructorPeer = peer;
        break;
      }
    }

    bool isInstructorVideoOn = false;
    if (instructorPeer != null) {
      final videoTrack = _peerIdToTrackMap[instructorPeer.peerId];
      isInstructorVideoOn = videoTrack != null && !videoTrack.isMute;
    }

    List<HMSPeer> nonInstructorPeers = _peers.where((peer) => peer.role.name.toLowerCase() != "instructor").toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Modernized App Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2A2A4A), Color(0xFF1A1A2E)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.sessionTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: MediaQuery.of(context).size.width < 300 ? 16 : 20, // Responsive font size
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8), // Reduced spacing for smaller screens
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isRecording) ...[
                                      FadeTransition(
                                        opacity: _recordingBlinkAnimation,
                                        child: const Icon(
                                          Icons.fiber_manual_record,
                                          color: Colors.red,
                                          size: 14, // Reduced size
                                        ),
                                      ),
                                      const SizedBox(width: 4), // Reduced spacing
                                    ],
                                    Text(
                                      _formatDuration(_sessionDuration),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: MediaQuery.of(context).size.width < 300 ? 14 : 16, // Responsive font size
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _showParticipantsList,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Adjusted padding
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people_alt_outlined, color: Colors.white, size: 18), // Reduced size
                                const SizedBox(width: 6), // Reduced spacing
                                Text(
                                  '${_peers.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _peers.isEmpty
                        ? const Center(
                      child: Text(
                        'No participants in the meeting',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    )
                        : Column(
                      children: [
                        if (instructorPeer != null)
                          FadeTransition(
                            opacity: _fadeController,
                            child: Container(
                              height: MediaQuery.of(context).size.height * 0.3,
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  if (isInstructorVideoOn)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: HMSVideoView(
                                        track: _peerIdToTrackMap[instructorPeer.peerId]!,
                                        setMirror: instructorPeer.peerId == _localPeer?.peerId,
                                        scaleType: ScaleType.SCALE_ASPECT_FIT,
                                      ),
                                    )
                                  else
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            _getPeerColor(instructorPeer.name).withOpacity(0.6),
                                            _getPeerColor(instructorPeer.name).withOpacity(0.3),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _getInitials(instructorPeer.name),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 60,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        instructorPeer.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        instructorPeer.audioTrack?.isMute ?? true ? Icons.mic_off : Icons.mic,
                                        color: instructorPeer.audioTrack?.isMute ?? true ? Colors.red : Colors.green,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Expanded(
                          child: nonInstructorPeers.isEmpty && !isInstructorVideoOn && instructorPeer == null
                              ? const Center(
                            child: Text(
                              'No other participants in the meeting',
                              style: TextStyle(color: Colors.white70, fontSize: 18),
                            ),
                          )
                              : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 300,
                              childAspectRatio: 16 / 9,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: nonInstructorPeers.length,
                            itemBuilder: (context, index) {
                              final peer = nonInstructorPeers[index];
                              final videoTrack = _peerIdToTrackMap[peer.peerId];
                              final hasVideo = videoTrack != null && !videoTrack.isMute;
                              bool isMuted = peer.isLocal ? !_isAudioOn : (peer.audioTrack?.isMute ?? true);

                              return FadeTransition(
                                opacity: _fadeController,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      hasVideo
                                          ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: HMSVideoView(
                                          track: videoTrack,
                                          setMirror: peer.peerId == _localPeer?.peerId,
                                          scaleType: ScaleType.SCALE_ASPECT_BALANCED,
                                        ),
                                      )
                                          : Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              _getPeerColor(peer.name).withOpacity(0.6),
                                              _getPeerColor(peer.name).withOpacity(0.3),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _getInitials(peer.name),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 40,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                peer.name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (_raisedHands.contains(peer.peerId)) ...[
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.pan_tool,
                                                  color: Colors.yellow,
                                                  size: 16,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isMuted ? Icons.mic_off : Icons.mic,
                                            color: isMuted ? Colors.red : Colors.green,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Control Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildToggleButton(
                          icon: _isAudioOn ? Icons.mic : Icons.mic_off,
                          color: _isAudioOn ? Colors.green : Colors.red,
                          onTap: _toggleAudio,
                          isLoading: _isTogglingAudio,
                          tooltip: _isAudioOn ? 'Mute Audio' : 'Unmute Audio',
                        ),
                        const SizedBox(width: 12),
                        _buildToggleButton(
                          icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                          color: _isVideoOn ? Colors.green : Colors.red,
                          onTap: _toggleVideo,
                          isLoading: _isTogglingVideo,
                          tooltip: _isVideoOn ? 'Turn Off Video' : 'Turn On Video',
                        ),
                        const SizedBox(width: 12),
                        _buildToggleButton(
                          icon: Icons.chat,
                          color: _unreadMessageCount > 0 ? Colors.blue : Colors.white,
                          onTap: _openChat,
                          isLoading: false,
                          badgeCount: _unreadMessageCount,
                          tooltip: 'Open Chat',
                        ),
                        const SizedBox(width: 12),
                        if (!_isInstructor)
                          _buildToggleButton(
                            icon: _raisedHands.contains(_localPeer?.peerId) ? Icons.pan_tool : Icons.pan_tool_outlined,
                            color: _raisedHands.contains(_localPeer?.peerId) ? Colors.yellow : Colors.white,
                            onTap: _toggleRaiseHand,
                            isLoading: false,
                            tooltip: _raisedHands.contains(_localPeer?.peerId) ? 'Lower Hand' : 'Raise Hand',
                          ),
                        if (_isInstructor) ...[
                          const SizedBox(width: 12),
                          _buildToggleButton(
                            icon: _isAllMuted ? Icons.volume_off : Icons.volume_up,
                            color: _isAllMuted ? Colors.red : Colors.green,
                            onTap: _toggleMuteAll,
                            isLoading: false,
                            tooltip: _isAllMuted ? 'Unmute All' : 'Mute All',
                          ),
                          const SizedBox(width: 12),
                          _buildToggleButton(
                            icon: _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                            color: _isRecording ? Colors.red : Colors.white,
                            onTap: _toggleRecording,
                            isLoading: _isTogglingRecording,
                            tooltip: _isRecording ? 'Stop Recording' : 'Start Recording',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // Floating Leave Button
              Positioned(
                bottom: 80,
                right: 16,
                child: FloatingActionButton(
                  onPressed: _leaveMeeting,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end, color: Colors.white),
                  tooltip: 'Leave Meeting',
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isLoading,
    int? badgeCount,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    IconData? icon,
    required VoidCallback onTap,
    required bool isLoading,
    required LinearGradient gradient,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBottomSheet() {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setBottomSheetState) {
        void updateChatUI() => setBottomSheetState(() {});
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Chat',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: _chatScrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = message.senderUsername != null && message.senderUsername == widget.username;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: _getPeerColor(message.senderName ?? 'Unknown'),
                                        child: Text(
                                          _getInitials(message.senderName ?? 'Unknown'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isMe ? Colors.blue.withOpacity(0.8) : Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isMe ? 'You' : (message.senderName ?? 'Unknown'),
                                            style: TextStyle(
                                              color: isMe ? Colors.white : Colors.white70,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            message.message,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat('HH:mm').format(message.time),
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isMe)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: _getPeerColor(widget.username),
                                        child: Text(
                                          _getInitials(widget.username),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      if (_typingPeers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Text(
                                  _typingPeers.length == 1 ? 'Someone is typing' : '${_typingPeers.length} are typing',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 30,
                                  height: 10,
                                  child: TypingIndicator(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                onChanged: (value) {
                                  if (value.trim().isNotEmpty) {
                                    _sendTypingEvent();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _sendMessage(() => setBottomSheetState(() {})),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.blue, Colors.blueAccent],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_showScrollToBottom)
                    Positioned(
                      bottom: 80,
                      right: 16,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.blue,
                        onPressed: () {
                          _chatScrollController.animateTo(
                            _chatScrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        },
                        child: const Icon(Icons.arrow_downward, color: Colors.white),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Typing Indicator Widget
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({Key? key}) : super(key: key);

  @override
  _TypingIndicatorState createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    _dotAnimations = List.generate(3, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            0.2 * index,
            0.2 * (index + 1),
            curve: Curves.easeInOut,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -5 * _dotAnimations[index].value),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}