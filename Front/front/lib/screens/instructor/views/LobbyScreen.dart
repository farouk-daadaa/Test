import 'package:flutter/material.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'MeetingScreen.dart';

class LobbyScreen extends StatefulWidget {
  final HMSSDK hmsSDK;
  final String meetingToken;
  final String username;

  const LobbyScreen({
    Key? key,
    required this.hmsSDK,
    required this.meetingToken,
    required this.username,
  }) : super(key: key);

  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> implements HMSPreviewListener {
  bool _isVideoOn = true;
  bool _isAudioOn = true;
  HMSVideoTrack? _localVideoTrack;
  bool _isLoading = false;
  bool _isJoining = false;
  bool _restartingVideo = false;

  // Add flags to prevent rapid toggling
  bool _isTogglingVideo = false;
  bool _isTogglingAudio = false;

  @override
  void initState() {
    super.initState();
    // Set up listeners before starting preview
    widget.hmsSDK.addPreviewListener(listener: this);
    _startPreview();
  }

  Future<void> _startPreview() async {
    setState(() {
      _isLoading = true;
    });
    try {
      HMSConfig config = HMSConfig(
        authToken: widget.meetingToken,
        userName: widget.username,
      );
      await widget.hmsSDK.preview(config: config);
    } catch (e) {
      print('Error starting preview: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start preview: $e'), backgroundColor: Colors.red),
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

  @override
  void dispose() {
    widget.hmsSDK.removePreviewListener(listener: this);
    super.dispose();
  }

  Future<void> _joinMeeting() async {
    if (_isJoining) return;

    setState(() {
      _isJoining = true;
    });

    try {
      HMSConfig config = HMSConfig(
        authToken: widget.meetingToken,
        userName: widget.username,
      );
      await widget.hmsSDK.join(config: config);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingScreen(
              hmsSDK: widget.hmsSDK,
              peers: [],
              videoTracks: [],
              initialVideoOn: _isVideoOn,
              initialAudioOn: _isAudioOn,
              meetingToken: widget.meetingToken,
              username: widget.username,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error joining meeting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join meeting: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  void _goBack() {
    Navigator.pop(context);
  }

  Color _getPeerColor(String name) {
    final int hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    return Colors.primaries[hash % Colors.primaries.length];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      if (parts[0].isEmpty) return 'U';
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  // Complete restart of preview when video is turned on
  // This is a more robust way to handle the black screen issue
  Future<void> _restartPreview() async {
    if (_restartingVideo) return;

    setState(() {
      _restartingVideo = true;
      _localVideoTrack = null; // Clear the current track reference
    });

    try {
      // First leave the preview
      await widget.hmsSDK.cancelPreview();

      // Wait a bit for resources to be released
      await Future.delayed(const Duration(milliseconds: 500));

      // Start preview again
      HMSConfig config = HMSConfig(
        authToken: widget.meetingToken,
        userName: widget.username,
      );
      await widget.hmsSDK.preview(config: config);

      // Video should be on by default after restart
      setState(() {
        _isVideoOn = true;
      });

      print("Preview restarted successfully");
    } catch (e) {
      print("Error restarting preview: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restart video: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _restartingVideo = false;
        });
      }
    }
  }

  Future<void> _toggleVideo() async {
    // Prevent rapid toggling
    if (_isTogglingVideo || _isLoading || _isJoining || _restartingVideo) return;

    _isTogglingVideo = true;

    try {
      if (!_isVideoOn) {
        // If we're turning video on and previously had issues,
        // use the more robust approach of restarting the preview
        await _restartPreview();
      } else {
        // If turning video off, use the normal method
        await widget.hmsSDK.switchVideo(isOn: false);
        if (mounted) {
          setState(() {
            _isVideoOn = false;
          });
        }
      }
    } catch (e) {
      print('Lobby: Error toggling video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle video: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      _isTogglingVideo = false;
    }
  }

  Future<void> _toggleAudio() async {
    // Prevent rapid toggling
    if (_isTogglingAudio || _isLoading || _isJoining) return;

    _isTogglingAudio = true;

    try {
      // Call the SDK first
      await widget.hmsSDK.switchAudio(isOn: !_isAudioOn);

      // Now update the UI
      if (mounted) {
        setState(() {
          _isAudioOn = !_isAudioOn;
        });
      }
      print('Lobby: Audio toggled - Audio is now: $_isAudioOn');
    } catch (e) {
      print('Lobby: Error toggling audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle audio: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      _isTogglingAudio = false;
    }
  }

  // HMSPreviewListener methods
  @override
  void onPreview({required HMSRoom room, required List<HMSTrack> localTracks}) {
    if (!mounted) return;

    print('onPreview called with ${localTracks.length} tracks');

    HMSVideoTrack? videoTrack;
    bool hasAudioTrack = false;

    for (var track in localTracks) {
      print('Track type: ${track.kind}, isMute: ${track.isMute}, trackId: ${track.trackId}');

      if (track.kind == HMSTrackKind.kHMSTrackKindVideo) {
        videoTrack = track as HMSVideoTrack;
      } else if (track.kind == HMSTrackKind.kHMSTrackKindAudio) {
        hasAudioTrack = true;
        _isAudioOn = !track.isMute;
      }
    }

    setState(() {
      _localVideoTrack = videoTrack;
      if (videoTrack != null) {
        _isVideoOn = !videoTrack.isMute;
        print('Video track set in onPreview, trackId: ${videoTrack.trackId}, muted: ${videoTrack.isMute}');
      }

      if (!hasAudioTrack) {
        // Default to true if no audio track found
        _isAudioOn = true;
      }
    });

    print('Preview initialized - Video: $_isVideoOn, Audio: $_isAudioOn');
  }

  @override
  void onError({required HMSException error}) {
    if (mounted) {
      print('Preview error: ${error.message}, code: ${error.code}, description: ${error.description}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview error: ${error.message}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void onHMSError({required HMSException error}) {
    if (mounted) {
      print('HMS error: ${error.message}, code: ${error.code}, description: ${error.description}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('HMS error: ${error.message}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void onAudioDeviceChanged({HMSAudioDevice? currentAudioDevice, List<HMSAudioDevice>? availableAudioDevice}) {}

  @override
  void onPeerListUpdate({required List<HMSPeer> addedPeers, required List<HMSPeer> removedPeers}) {}

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    if (peer.isLocal && mounted) {
      print("Local peer update: $update");

      // Check for updates on tracks
      HMSLocalPeer localPeer = peer as HMSLocalPeer;

      if (localPeer.videoTrack != null) {
        // Always update the local video track reference when there's an update
        setState(() {
          _localVideoTrack = localPeer.videoTrack;
          _isVideoOn = !localPeer.videoTrack!.isMute;
        });
        print("Video track updated in onPeerUpdate, trackId: ${localPeer.videoTrack!.trackId}, muted: ${localPeer.videoTrack!.isMute}");
      }

      if (localPeer.audioTrack != null) {
        setState(() {
          _isAudioOn = !localPeer.audioTrack!.isMute;
        });
      }
    }
  }

  @override
  void onRoomUpdate({required HMSRoom room, required HMSRoomUpdate update}) {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get Started',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Set up your audio and video before joining',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(10)),
                    child: _isLoading || _restartingVideo
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : _isVideoOn && _localVideoTrack != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _buildVideoView(),
                    )
                        : Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: _getPeerColor(widget.username),
                        child: Text(
                          _getInitials(widget.username),
                          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Material(
                        color: _isAudioOn ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                        child: InkWell(
                          onTap: _toggleAudio,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              _isAudioOn ? Icons.mic : Icons.mic_off,
                              color: _isAudioOn ? Colors.green : Colors.red,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Material(
                        color: _isVideoOn ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                        child: InkWell(
                          onTap: _toggleVideo,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              _isVideoOn ? Icons.videocam : Icons.videocam_off,
                              color: _isVideoOn ? Colors.green : Colors.red,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          widget.username,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: (_isLoading || _isJoining || _restartingVideo) ? null : _goBack,
                            child: const Text('Back', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: (_isLoading || _isJoining || _restartingVideo) ? null : _joinMeeting,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                              child: _isJoining
                                  ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.0,
                                  )
                              )
                                  : const Text('Join Now', style: TextStyle(color: Colors.white, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isLoading || _restartingVideo)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  // Helper method to build the video view with additional error handling
  Widget _buildVideoView() {
    if (_localVideoTrack == null) {
      print("Warning: Attempted to build video view with null track");
      return const Center(
        child: Text("Camera unavailable", style: TextStyle(color: Colors.white)),
      );
    }

    try {
      return HMSVideoView(
        track: _localVideoTrack!,
        setMirror: true,
        matchParent: true,
        scaleType: ScaleType.SCALE_ASPECT_FILL,
      );
    } catch (e) {
      print("Error building video view: $e");
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 30),
            const SizedBox(height: 8),
            Text("Camera error: $e",
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }
}