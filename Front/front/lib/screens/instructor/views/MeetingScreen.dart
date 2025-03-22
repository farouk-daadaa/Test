import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'LobbyScreen.dart';
import 'package:intl/intl.dart'; // For formatting timestamps
import 'package:uuid/uuid.dart'; // For generating temporary message IDs

class MeetingScreen extends StatefulWidget {
  final HMSSDK hmsSDK;
  final List<HMSPeer> peers;
  final List<HMSVideoTrack> videoTracks;
  final bool initialVideoOn;
  final bool initialAudioOn;
  final String meetingToken;
  final String username;

  const MeetingScreen({
    Key? key,
    required this.hmsSDK,
    required this.peers,
    required this.videoTracks,
    required this.initialVideoOn,
    required this.initialAudioOn,
    required this.meetingToken,
    required this.username,
  }) : super(key: key);

  @override
  _MeetingScreenState createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> implements HMSUpdateListener {
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

  // Chat-related state
  final List<HMSMessage> _messages = [];
  bool _isChatOpen = false;
  int _unreadMessageCount = 0;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // Typing indicator state
  final List<String> _typingPeers = [];
  final Map<String, Timer> _typingTimers = {};
  bool _isTyping = false;
  Timer? _typingDebounceTimer;

  @override
  void initState() {
    super.initState();
    _isVideoOn = widget.initialVideoOn;
    _isAudioOn = widget.initialAudioOn;
    _peers = widget.peers.where((peer) => peer.name.isNotEmpty && peer.name != "Unknown").toSet().toList();
    _videoTracks = List.from(widget.videoTracks);
    _fetchLocalPeerAndSetup();
    widget.hmsSDK.addUpdateListener(listener: this);
  }

  Future<void> _fetchLocalPeerAndSetup() async {
    try {
      setState(() {
        _isLoading = true;
      });
      _localPeer = await widget.hmsSDK.getLocalPeer();
      if (_localPeer != null) {
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          bool currentVideoState = await _isVideoCurrentlyOn();
          bool currentAudioState = await _isAudioCurrentlyOn();

          print('Initial setup - Attempt $i: Current Video: $currentVideoState, Desired: $_isVideoOn, Current Audio: $currentAudioState, Desired: $_isAudioOn');

          if (currentVideoState != _isVideoOn) {
            await widget.hmsSDK.toggleCameraMuteState();
            print('Toggled video to match initial state: $_isVideoOn');
          }

          if (currentAudioState != _isAudioOn) {
            await widget.hmsSDK.toggleMicMuteState();
            print('Toggled audio to match initial state: $_isAudioOn');
          }

          HMSLocalPeer? localPeer = await widget.hmsSDK.getLocalPeer();
          if (localPeer != null) {
            bool videoState = localPeer.videoTrack != null && !localPeer.videoTrack!.isMute;
            bool audioState = localPeer.audioTrack != null && !localPeer.audioTrack!.isMute;
            if (videoState == _isVideoOn && audioState == _isAudioOn) {
              print('Initial states matched after attempt $i');
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
          print('Meeting: Final initial states set - Video: $_isVideoOn, Audio: $_isAudioOn');
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
    _videoTracks.clear();
    _peerIdToTrackMap.clear();
    _peers.clear();
    _localPeer = null;
    _messageController.dispose();
    _chatScrollController.dispose();
    _typingDebounceTimer?.cancel();
    _typingTimers.forEach((_, timer) => timer.cancel());
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
        print('Meeting: Video toggled - Video: $_isVideoOn');
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

    setState(() {
      _isTogglingAudio = true;
    });

    try {
      await widget.hmsSDK.toggleMicMuteState();
      HMSLocalPeer? localPeer = await widget.hmsSDK.getLocalPeer();
      if (localPeer != null) {
        bool newAudioState = localPeer.audioTrack != null && !localPeer.audioTrack!.isMute;
        setState(() {
          _isAudioOn = newAudioState;
        });
        print('Meeting: Audio toggled - Audio: $_isAudioOn');
      } else {
        print('Meeting: Local peer is null after toggling audio');
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

  Future<void> _leaveMeeting() async {
    try {
      await widget.hmsSDK.leave();
      if (mounted) {
        setState(() {
          _hasLeftMeeting = true;
        });
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
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LobbyScreen(
          hmsSDK: widget.hmsSDK,
          meetingToken: widget.meetingToken,
          username: widget.username,
        ),
      ),
    );
  }

  void _exitToMySessions() {
    Navigator.pushNamedAndRemoveUntil(context, '/my_sessions', (Route<dynamic> route) => false);
  }

  void _showParticipantsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Participants (${_peers.length})',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _peers.length,
                itemBuilder: (context, index) {
                  final peer = _peers[index];
                  bool isMuted = peer.isLocal ? !_isAudioOn : (peer.audioTrack?.isMute ?? true);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getPeerColor(peer.name),
                      child: Text(
                        _getInitials(peer.name),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(peer.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    trailing: Icon(
                      isMuted ? Icons.mic_off : Icons.mic,
                      color: isMuted ? Colors.red : Colors.green,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNotification(String message) {
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

  // Chat-related methods
  void _openChat() {
    setState(() {
      _isChatOpen = true;
      _unreadMessageCount = 0; // Reset unread count when chat is opened
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
      // Create a temporary message ID
      String tempMessageId = const Uuid().v4();

      // Create the HMSMessageRecipient for a broadcast message
      HMSMessageRecipient hmsMessageRecipient = HMSMessageRecipient(
        hmsMessageRecipientType: HMSMessageRecipientType.BROADCAST,
        recipientPeer: null,
        recipientRoles: null,
      );

      // Create the sent message for immediate UI feedback
      HMSMessage sentMessage = HMSMessage(
        messageId: tempMessageId,
        sender: _localPeer,
        message: messageText,
        type: "chat",
        time: DateTime.now(),
        hmsMessageRecipient: hmsMessageRecipient,
      );

      // Add the message to the list and update the UI
      setState(() {
        _messages.add(sentMessage);
        _messageController.clear();
      });

      // Update the chat UI in the bottom sheet
      updateChatUI();

      // Auto-scroll to the bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      // Send the message to the server
      await widget.hmsSDK.sendBroadcastMessage(
        message: messageText,
        type: "chat",
      );

      // Stop typing indicator after sending the message
      _isTyping = false;
      _typingDebounceTimer?.cancel();

      print('Message sent: $messageText');
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
      print('Sent typing event');
    }

    // Reset the typing timer
    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = Timer(const Duration(seconds: 3), () {
      _isTyping = false;
    });
  }

  // HMSUpdateListener methods
  @override
  void onJoin({required HMSRoom room}) {
    setState(() {
      _peers = (room.peers ?? []).where((peer) => peer.name.isNotEmpty && peer.name != "Unknown").toSet().toList();
    });
    _updateLocalTracks();
  }

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    if (peer.name.isEmpty || peer.name == "Unknown") return;
    setState(() {
      if (update == HMSPeerUpdate.peerJoined) {
        if (!_peers.any((p) => p.peerId == peer.peerId)) {
          _peers.add(peer);
          _showNotification('${peer.name} joined the meeting');
        }
      } else if (update == HMSPeerUpdate.peerLeft) {
        _peers.removeWhere((p) => p.peerId == peer.peerId);
        _peerIdToTrackMap.remove(peer.peerId);
        _videoTracks.removeWhere((track) => _peerIdToTrackMap[peer.peerId] == track);
        _showNotification('${peer.name} left the meeting');
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
        if (peer.isLocal) {
          _isAudioOn = !track.isMute;
        }
        print('Audio track updated for peer ${peer.name}: isMute=${track.isMute}');
      }
    });
  }

  void onError({required HMSException error}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meeting error: ${error.message}'), backgroundColor: Colors.red),
      );
    }
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

          // Reset the typing timer for this peer
          _typingTimers[peerId]?.cancel();
          _typingTimers[peerId] = Timer(const Duration(seconds: 5), () {
            setState(() {
              _typingPeers.remove(peerId);
              _typingTimers.remove(peerId);
              updateChatUI?.call();
            });
          });
        }
      } else {
        // Handle regular chat messages
        bool isDuplicate = _messages.any((msg) =>
        msg.message == message.message &&
            msg.sender?.peerId == message.sender?.peerId &&
            msg.time.difference(message.time).inSeconds.abs() < 2);

        if (!isDuplicate) {
          _messages.add(message);
          if (!_isChatOpen) {
            _unreadMessageCount++;
          }

          // Update the chat UI in the bottom sheet
          updateChatUI?.call();

          // Auto-scroll to the bottom
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
    print('Received message: ${message.message} from ${message.sender?.name}');
  }

  @override
  void onRoleChangeRequest({required HMSRoleChangeRequest roleChangeRequest}) {
    print('Role change request received');
  }

  @override
  void onUpdateSpeakers({required List<HMSSpeaker> updateSpeakers}) {
    print('Speakers updated: ${updateSpeakers.map((s) => s.peer.name).toList()}');
  }

  @override
  void onRoomUpdate({required HMSRoom room, required HMSRoomUpdate update}) {
    print('Room update: $update');
  }

  @override
  void onReconnecting() {
    print('Reconnecting...');
  }

  @override
  void onReconnected() {
    print('Reconnected');
  }

  @override
  void onAudioDeviceChanged({HMSAudioDevice? currentAudioDevice, List<HMSAudioDevice>? availableAudioDevice}) {
    print('Audio device changed: Current device: $currentAudioDevice, Available devices: $availableAudioDevice');
  }

  @override
  void onChangeTrackStateRequest({required HMSTrackChangeRequest hmsTrackChangeRequest}) {
    print('Track state change requested: ${hmsTrackChangeRequest.track}');
  }

  @override
  void onHMSError({required HMSException error}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('HMS Error: ${error.message}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void onPeerListUpdate({required List<HMSPeer> addedPeers, required List<HMSPeer> removedPeers}) {
    print('Peer list updated: added ${addedPeers.length}, removed ${removedPeers.length}');
    setState(() {
      for (var peer in addedPeers) {
        if (peer.name.isEmpty || peer.name == "Unknown") continue;
        if (!_peers.any((p) => p.peerId == peer.peerId)) {
          _peers.add(peer);
          _showNotification('${peer.name} joined the meeting');
        }
      }
      for (var peer in removedPeers) {
        _peers.removeWhere((p) => p.peerId == peer.peerId);
        _peerIdToTrackMap.remove(peer.peerId);
        _videoTracks.removeWhere((track) => _peerIdToTrackMap[peer.peerId] == track);
        _showNotification('${peer.name} left the meeting');
      }
    });
  }

  @override
  void onRemovedFromRoom({required HMSPeerRemovedFromPeer hmsPeerRemovedFromPeer}) {
    if (mounted) {
      setState(() {
        _hasLeftMeeting = true;
      });
    }
  }

  @override
  void onSessionStoreAvailable({HMSSessionStore? hmsSessionStore}) {
    print('Session store available: ${hmsSessionStore != null ? "Initialized" : "Not initialized"}');
  }

  @override
  Widget build(BuildContext context) {
    if (_hasLeftMeeting) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A1A2E),
                Color(0xFF16213E),
              ],
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
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.redAccent],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: const Text(
                            'Live Meeting Room',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 24,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: _showParticipantsList,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people_alt_outlined, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${_peers.length} Participants',
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                        : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        childAspectRatio: 16 / 9,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _peers.length,
                      itemBuilder: (context, index) {
                        final peer = _peers[index];
                        final videoTrack = _peerIdToTrackMap[peer.peerId];
                        final hasVideo = videoTrack != null && !videoTrack.isMute;
                        bool isMuted = peer.isLocal ? !_isAudioOn : (peer.audioTrack?.isMute ?? true);

                        return Container(
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
                                  : Center(
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: _getPeerColor(peer.name),
                                  child: Text(
                                    _getInitials(peer.name),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
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
                                    peer.name,
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
                                    isMuted ? Icons.mic_off : Icons.mic,
                                    color: isMuted ? Colors.red : Colors.green,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildToggleButton(
                          icon: _isAudioOn ? Icons.mic : Icons.mic_off,
                          color: _isAudioOn ? Colors.green : Colors.red,
                          onTap: _toggleAudio,
                          isLoading: _isTogglingAudio,
                        ),
                        _buildToggleButton(
                          icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                          color: _isVideoOn ? Colors.green : Colors.red,
                          onTap: _toggleVideo,
                          isLoading: _isTogglingVideo,
                        ),
                        _buildToggleButton(
                          icon: Icons.chat,
                          color: _unreadMessageCount > 0 ? Colors.blue : Colors.white,
                          onTap: _openChat,
                          isLoading: false,
                          badgeCount: _unreadMessageCount,
                        ),
                        _buildActionButton(
                          text: 'Leave',
                          icon: Icons.call_end,
                          onTap: _leaveMeeting,
                          isLoading: false,
                          gradient: const LinearGradient(
                            colors: [Colors.red, Colors.redAccent],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
  }) {
    return Stack(
      children: [
        GestureDetector(
          onTap: isLoading ? null : onTap,
          child: AnimatedContainer(
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
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : Icon(
              icon,
              color: color,
              size: 30,
            ),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
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
        onMessage({required HMSMessage message}) {
          this.onMessage(message: message, updateChatUI: () => setBottomSheetState(() {}));
        }

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
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                  ],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header
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
                  // Messages List
                  Expanded(
                    child: ListView.builder(
                      controller: _chatScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.sender?.peerId == _localPeer?.peerId;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.blue.withOpacity(0.8) : Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isMe ? 'You' : (message.sender?.name ?? 'Unknown'),
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
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Typing Indicator
                  if (_typingPeers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _typingPeers.length == 1
                              ? '${_typingPeers.length} is typing...'
                              : '${_typingPeers.length} are typing...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  // Message Input
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
            );
          },
        );
      },
    );
  }
}