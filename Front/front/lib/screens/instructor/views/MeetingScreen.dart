import 'package:flutter/material.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';

class MeetingScreen extends StatefulWidget {
  final HMSSDK hmsSDK;
  final List<HMSPeer> peers;
  final List<HMSVideoTrack> videoTracks;
  final bool initialVideoOn;
  final bool initialAudioOn;

  const MeetingScreen({
    Key? key,
    required this.hmsSDK,
    required this.peers,
    required this.videoTracks,
    this.initialVideoOn = false,
    this.initialAudioOn = false,
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
  final Map<HMSVideoTrack, HMSPeer> _trackToPeerMap = {};

  @override
  void initState() {
    super.initState();
    // Initialize states from widget parameters
    _isVideoOn = widget.initialVideoOn;
    _isAudioOn = widget.initialAudioOn;

    // Initialize peers and video tracks
    _peers = widget.peers.where((peer) => peer.name != null && peer.name!.isNotEmpty && peer.name != "Unknown").toSet().toList();
    _videoTracks = List.from(widget.videoTracks);

    // Initialize track-to-peer mapping
    for (var track in _videoTracks) {
      var peer = _peers.firstWhere(
            (p) => widget.videoTracks.indexOf(track) < _peers.length && widget.videoTracks.indexOf(track) == _peers.indexOf(p),
        orElse: () => _peers.first,
      );
      _trackToPeerMap[track] = peer;
    }

    // Fetch local peer and set up initial state
    _fetchLocalPeerAndSetup();
    // Add this class as an update listener
    widget.hmsSDK.addUpdateListener(listener: this);
  }

  Future<void> _fetchLocalPeerAndSetup() async {
    _localPeer = await widget.hmsSDK.getLocalPeer();
    if (_localPeer != null) {
      HMSLocalPeer? localPeer = _localPeer as HMSLocalPeer?;
      if (localPeer != null) {
        // Set initial states
        await widget.hmsSDK.switchVideo(isOn: _isVideoOn);
        await widget.hmsSDK.switchAudio(isOn: _isAudioOn);

        // Verify the actual state from the SDK
        final videoTrack = localPeer.videoTrack;
        final audioTrack = localPeer.audioTrack;
        setState(() {
          _isVideoOn = videoTrack != null && !videoTrack.isMute;
          _isAudioOn = audioTrack != null && !audioTrack.isMute;
        });
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    // Remove the update listener
    widget.hmsSDK.removeUpdateListener(listener: this);
    // Leave the meeting
    widget.hmsSDK.leave();
    // Clear all data to prevent stale tracks on rejoin
    _videoTracks.clear();
    _trackToPeerMap.clear();
    _peers.clear();
    _localPeer = null;
    super.dispose();
  }

  void _toggleVideo() async {
    try {
      await widget.hmsSDK.switchVideo(isOn: !_isVideoOn);
      setState(() {
        _isVideoOn = !_isVideoOn;
      });
      // Force a UI update to ensure the placeholder is shown
      if (_localPeer != null) {
        final localPeer = _localPeer as HMSLocalPeer?;
        if (localPeer != null) {
          final videoTrack = localPeer.videoTrack;
          setState(() {
            _isVideoOn = videoTrack != null && !videoTrack.isMute;
          });
        }
      }
    } catch (e) {
      print('Error toggling video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to toggle video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleAudio() async {
    try {
      await widget.hmsSDK.switchAudio(isOn: !_isAudioOn);
      setState(() {
        _isAudioOn = !_isAudioOn;
      });
      // Force a UI update to ensure the audio state is reflected
      if (_localPeer != null) {
        final localPeer = _localPeer as HMSLocalPeer?;
        if (localPeer != null) {
          final audioTrack = localPeer.audioTrack;
          setState(() {
            _isAudioOn = audioTrack != null && !audioTrack.isMute;
          });
        }
      }
    } catch (e) {
      print('Error toggling audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to toggle audio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _leaveMeeting() {
    widget.hmsSDK.leave();
    Navigator.pop(context);
  }

  void _showParticipantsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[800],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Participants (${_peers.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _peers.length,
                itemBuilder: (context, index) {
                  final peer = _peers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getPeerColor(peer.name!),
                      child: Text(
                        _getInitials(peer.name!),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      peer.name!,
                      style: const TextStyle(color: Colors.white),
                    ),
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
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
    print('Joined room: ${room.id}');
    setState(() {
      _peers = (room.peers ?? []).where((peer) => peer.name != null && peer.name!.isNotEmpty && peer.name != "Unknown").toSet().toList();
    });
  }

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    print('Peer update: ${peer.name}, update: $update');
    if (peer.name == null || peer.name!.isEmpty || peer.name == "Unknown") return;
    setState(() {
      if (update == HMSPeerUpdate.peerJoined) {
        if (!_peers.any((p) => p.peerId == peer.peerId)) {
          _peers.add(peer);
          _showNotification('${peer.name} joined the meeting');
        }
      } else if (update == HMSPeerUpdate.peerLeft) {
        _peers.removeWhere((p) => p.peerId == peer.peerId);
        _videoTracks.removeWhere((track) => _trackToPeerMap[track]?.peerId == peer.peerId);
        _trackToPeerMap.removeWhere((track, p) => p.peerId == peer.peerId);
        _showNotification('${peer.name} left the meeting');
      }
    });
  }

  @override
  void onTrackUpdate({required HMSTrack track, required HMSTrackUpdate trackUpdate, required HMSPeer peer}) {
    print('Track update: ${track.kind}, update: $trackUpdate, peer: ${peer.name}');
    if (peer.name == null || peer.name!.isEmpty || peer.name == "Unknown") return;
    if (track.kind == HMSTrackKind.kHMSTrackKindVideo) {
      setState(() {
        if (trackUpdate == HMSTrackUpdate.trackAdded) {
          final videoTrack = track as HMSVideoTrack;
          if (!_videoTracks.contains(videoTrack)) {
            _videoTracks.add(videoTrack);
            _trackToPeerMap[videoTrack] = peer;
          }
        } else if (trackUpdate == HMSTrackUpdate.trackRemoved) {
          _videoTracks.remove(track);
          _trackToPeerMap.remove(track);
        } else if (trackUpdate == HMSTrackUpdate.trackMuted || trackUpdate == HMSTrackUpdate.trackUnMuted) {
          if (peer.peerId == _localPeer?.peerId) {
            if (track.kind == HMSTrackKind.kHMSTrackKindVideo) {
              _isVideoOn = !(track as HMSVideoTrack).isMute;
            }
          }
        }
      });
    } else if (track.kind == HMSTrackKind.kHMSTrackKindAudio) {
      if (trackUpdate == HMSTrackUpdate.trackMuted || trackUpdate == HMSTrackUpdate.trackUnMuted) {
        if (peer.peerId == _localPeer?.peerId) {
          setState(() {
            _isAudioOn = !(track as HMSAudioTrack).isMute;
          });
        }
      }
    }
  }

  @override
  void onError({required HMSException error}) {
    print('HMS Error: ${error.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Meeting error: ${error.message}'),
        backgroundColor: Colors.red,
      ),
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
    print('HMS Error occurred: ${error.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('HMS Error: ${error.message}'),
        backgroundColor: Colors.red,
      ),
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
        _videoTracks.removeWhere((track) => _trackToPeerMap[track]?.peerId == peer.peerId);
        _trackToPeerMap.removeWhere((track, p) => p.peerId == peer.peerId);
        _showNotification('${peer.name} left the meeting');
      }
    });
  }

  @override
  void onRemovedFromRoom({required HMSPeerRemovedFromPeer hmsPeerRemovedFromPeer}) {
    print('Removed from room: ${hmsPeerRemovedFromPeer.reason}');
    Navigator.pop(context);
  }

  @override
  void onSessionStoreAvailable({HMSSessionStore? hmsSessionStore}) {
    print('Session store available: ${hmsSessionStore != null ? "Initialized" : "Not initialized"}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Live Meeting Room',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _showParticipantsList,
            child: Row(
              children: [
                const Icon(
                  Icons.people_alt_outlined,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_peers.length} Participants',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          _peers.isEmpty
              ? const Center(
            child: Text(
              'No participants in the meeting',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          )
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
              final videoTrack = _videoTracks.firstWhere(
                    (track) => _trackToPeerMap[track]?.peerId == peer.peerId,
                orElse: () => null as HMSVideoTrack,
              );
              final hasVideo = videoTrack != null && !videoTrack.isMute;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    hasVideo
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: HMSVideoView(
                        track: videoTrack,
                        setMirror: peer.peerId == _localPeer?.peerId,
                      ),
                    )
                        : Center(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: _getPeerColor(peer.name!),
                        child: Text(
                          _getInitials(peer.name!),
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
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          peer.name!,
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
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    heroTag: 'video',
                    onPressed: _toggleVideo,
                    backgroundColor: _isVideoOn ? Colors.green : Colors.grey,
                    mini: true,
                    child: Icon(
                      _isVideoOn ? Icons.videocam : Icons.videocam_off,
                      color: Colors.white,
                    ),
                  ),
                  FloatingActionButton(
                    heroTag: 'audio',
                    onPressed: _toggleAudio,
                    backgroundColor: _isAudioOn ? Colors.green : Colors.grey,
                    mini: true,
                    child: Icon(
                      _isAudioOn ? Icons.mic : Icons.mic_off,
                      color: Colors.white,
                    ),
                  ),
                  FloatingActionButton(
                    heroTag: 'leave',
                    onPressed: _leaveMeeting,
                    backgroundColor: Colors.red,
                    mini: true,
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
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