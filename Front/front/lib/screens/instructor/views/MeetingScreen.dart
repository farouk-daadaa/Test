import 'package:flutter/material.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'LobbyScreen.dart';

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

  @override
  void initState() {
    super.initState();
    _isVideoOn = widget.initialVideoOn;
    _isAudioOn = widget.initialAudioOn;
    _peers = widget.peers.where((peer) => peer.name != null && peer.name!.isNotEmpty && peer.name != "Unknown").toSet().toList();
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
        // Retry mechanism to ensure tracks are initialized
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(milliseconds: 1000));
          await widget.hmsSDK.switchVideo(isOn: _isVideoOn);
          await widget.hmsSDK.switchAudio(isOn: _isAudioOn);
          HMSLocalPeer? localPeer = await widget.hmsSDK.getLocalPeer();
          if (localPeer != null) {
            bool videoState = localPeer.videoTrack != null && !localPeer.videoTrack!.isMute;
            bool audioState = localPeer.audioTrack != null && !localPeer.audioTrack!.isMute;
            if (videoState == _isVideoOn && audioState == _isAudioOn) break;
          }
        }
        await _updateLocalTracks();
        // Verify the actual states
        HMSLocalPeer? localPeer = await widget.hmsSDK.getLocalPeer();
        if (localPeer != null) {
          setState(() {
            _isVideoOn = localPeer.videoTrack != null && !localPeer.videoTrack!.isMute;
            _isAudioOn = localPeer.audioTrack != null && !localPeer.audioTrack!.isMute;
          });
          print('Meeting: Initial states set - Video: $_isVideoOn, Audio: $_isAudioOn');
        }
      }
    } catch (e) {
      print('Error fetching local peer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch local peer: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    widget.hmsSDK.removeUpdateListener(listener: this);
    widget.hmsSDK.switchVideo(isOn: false);
    widget.hmsSDK.switchAudio(isOn: false);
    _videoTracks.clear();
    _peerIdToTrackMap.clear();
    _peers.clear();
    _localPeer = null;
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
    try {
      await widget.hmsSDK.switchVideo(isOn: !_isVideoOn);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle video: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleAudio() async {
    try {
      await widget.hmsSDK.switchAudio(isOn: !_isAudioOn);
      HMSLocalPeer? localPeer = await widget.hmsSDK.getLocalPeer();
      if (localPeer != null) {
        setState(() {
          _isAudioOn = localPeer.audioTrack != null && !localPeer.audioTrack!.isMute;
        });
        print('Meeting: Audio toggled - Audio: $_isAudioOn');
      }
    } catch (e) {
      print('Error toggling audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle audio: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _leaveMeeting() {
    widget.hmsSDK.leave();
    setState(() {
      _hasLeftMeeting = true;
    });
  }

  void _rejoinMeeting() {
    setState(() {
      _hasLeftMeeting = false;
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
      backgroundColor: Colors.grey[800],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Participants (${_peers.length})', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _peers.length,
                itemBuilder: (context, index) {
                  final peer = _peers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getPeerColor(peer.name!),
                      child: Text(_getInitials(peer.name!), style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(peer.name!, style: const TextStyle(color: Colors.white)),
                    trailing: Icon(
                      peer.audioTrack?.isMute ?? true ? Icons.mic_off : Icons.mic,
                      color: peer.audioTrack?.isMute ?? true ? Colors.red : Colors.green,
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

  // HMSUpdateListener methods
  @override
  void onJoin({required HMSRoom room}) {
    setState(() {
      _peers = (room.peers ?? []).where((peer) => peer.name != null && peer.name!.isNotEmpty && peer.name != "Unknown").toSet().toList();
    });
    _updateLocalTracks();
  }

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    if (peer.name == null || peer.name!.isEmpty || peer.name == "Unknown") return;
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
    if (track.kind == HMSTrackKind.kHMSTrackKindVideo) {
      setState(() {
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
      });
    }
  }

  @override
  void onError({required HMSException error}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Meeting error: ${error.message}'), backgroundColor: Colors.red),
    );
  }

  @override
  void onMessage({required HMSMessage message}) {
    print('Received message: ${message.message}');
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
    print('Audio device changed: $currentAudioDevice');
  }

  @override
  void onChangeTrackStateRequest({required HMSTrackChangeRequest hmsTrackChangeRequest}) {
    print('Track state change requested: ${hmsTrackChangeRequest.track}');
  }

  @override
  void onHMSError({required HMSException error}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('HMS Error: ${error.message}'), backgroundColor: Colors.red),
    );
  }

  @override
  void onPeerListUpdate({required List<HMSPeer> addedPeers, required List<HMSPeer> removedPeers}) {
    print('Peer list updated: added ${addedPeers.length}, removed ${removedPeers.length}');
    setState(() {
      for (var peer in addedPeers) {
        if (peer.name == null || peer.name!.isEmpty || peer.name == "Unknown") continue;
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
    setState(() {
      _hasLeftMeeting = true;
    });
  }

  @override
  void onSessionStoreAvailable({HMSSessionStore? hmsSessionStore}) {
    print('Session store available: ${hmsSessionStore != null ? "Initialized" : "Not initialized"}');
  }

  @override
  Widget build(BuildContext context) {
    if (_hasLeftMeeting) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.waving_hand, color: Colors.yellow, size: 50),
              const SizedBox(height: 16),
              const Text('You left the room', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Have a nice day, ${widget.username}!', style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Left by mistake? ', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  TextButton(
                    onPressed: _rejoinMeeting,
                    child: const Text('Rejoin', style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _exitToMySessions,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Exit', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Live Meeting Room', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _showParticipantsList,
            child: Row(
              children: [
                const Icon(Icons.people_alt_outlined, color: Colors.white),
                const SizedBox(width: 8),
                Text('${_peers.length} Participants', style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          _peers.isEmpty
              ? const Center(child: Text('No participants in the meeting', style: TextStyle(color: Colors.white70, fontSize: 18)))
              : GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              childAspectRatio: 16 / 9,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _peers.length,
            itemBuilder: (context, index) {
              final peer = _peers[index];
              final videoTrack = _peerIdToTrackMap[peer.peerId];
              final hasVideo = videoTrack != null && !videoTrack.isMute;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Stack(
                  children: [
                    hasVideo
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: HMSVideoView(track: videoTrack, setMirror: peer.peerId == _localPeer?.peerId),
                    )
                        : Center(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: _getPeerColor(peer.name!),
                        child: Text(
                          _getInitials(peer.name!),
                          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: Text(peer.name!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: Icon(
                          peer.audioTrack?.isMute ?? true ? Icons.mic_off : Icons.mic,
                          color: peer.audioTrack?.isMute ?? true ? Colors.red : Colors.green,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    heroTag: 'video',
                    onPressed: _toggleVideo,
                    backgroundColor: _isVideoOn ? Colors.green : Colors.grey,
                    mini: true,
                    child: Icon(_isVideoOn ? Icons.videocam : Icons.videocam_off, color: Colors.white),
                  ),
                  FloatingActionButton(
                    heroTag: 'audio',
                    onPressed: _toggleAudio,
                    backgroundColor: _isAudioOn ? Colors.green : Colors.grey,
                    mini: true,
                    child: Icon(_isAudioOn ? Icons.mic : Icons.mic_off, color: Colors.white),
                  ),
                  FloatingActionButton(
                    heroTag: 'leave',
                    onPressed: _leaveMeeting,
                    backgroundColor: Colors.red,
                    mini: true,
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}