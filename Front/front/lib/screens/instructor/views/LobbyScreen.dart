import 'package:flutter/material.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'MeetingScreen.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

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

  // Add flags to prevent rapid toggling
  bool _isTogglingVideo = false;
  bool _isTogglingAudio = false;

  // Track if we need to restart preview to fix video
  bool _needsPreviewRestart = false;

  // List to track peers in the meeting during preview
  List<HMSPeer> _peers = [];

  // Connection test state
  bool _isTestingConnection = false;
  String _connectionStatus = 'Not Tested';
  Color _connectionStatusColor = Colors.grey;

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

  Future<void> _restartPreview() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _localVideoTrack = null;
    });

    try {
      await widget.hmsSDK.leave();
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      HMSConfig config = HMSConfig(
        authToken: widget.meetingToken,
        userName: widget.username,
      );
      await widget.hmsSDK.preview(config: config);
    } catch (e) {
      print('Error restarting preview: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restart preview: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _needsPreviewRestart = false;
        });
      }
    }
  }

  @override
  void dispose() {
    widget.hmsSDK.removePreviewListener(listener: this);
    widget.hmsSDK.toggleCameraMuteState();
    widget.hmsSDK.toggleMicMuteState();
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

  Future<void> _toggleVideo() async {
    if (_isTogglingVideo || _isLoading || _isJoining) return;

    _isTogglingVideo = true;

    try {
      if (_isVideoOn) {
        await widget.hmsSDK.toggleCameraMuteState();
        setState(() {
          _isVideoOn = false;
          _localVideoTrack = null;
        });
      } else {
        await widget.hmsSDK.toggleCameraMuteState();
        setState(() {
          _isVideoOn = true;
        });

        _needsPreviewRestart = true;

        Future.delayed(const Duration(milliseconds: 500), () async {
          if (!mounted || !_isVideoOn) return;

          HMSLocalPeer? localPeer = await widget.hmsSDK.getLocalPeer();

          if (_needsPreviewRestart &&
              (localPeer?.videoTrack == null || localPeer!.videoTrack!.isMute)) {
            _restartPreview();
          } else if (localPeer?.videoTrack != null) {
            setState(() {
              _localVideoTrack = localPeer!.videoTrack;
              _needsPreviewRestart = false;
            });
          }
        });
      }

      print('Lobby: Video toggled - Video is now: $_isVideoOn');
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
    if (_isTogglingAudio || _isLoading || _isJoining) return;

    _isTogglingAudio = true;

    try {
      await widget.hmsSDK.toggleMicMuteState();

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

  Future<void> _testConnection() async {
    if (_isTestingConnection) return;

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testing...';
      _connectionStatusColor = Colors.yellow;
    });

    try {
      const String testUrl = 'https://www.google.com';
      final stopwatch = Stopwatch()..start();

      final response = await http.get(Uri.parse(testUrl)).timeout(const Duration(seconds: 5));

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      if (response.statusCode == 200) {
        if (latency < 100) {
          setState(() {
            _connectionStatus = 'Good (Latency: ${latency}ms)';
            _connectionStatusColor = Colors.green;
          });
        } else if (latency < 300) {
          setState(() {
            _connectionStatus = 'Fair (Latency: ${latency}ms)';
            _connectionStatusColor = Colors.orange;
          });
        } else {
          setState(() {
            _connectionStatus = 'Poor (Latency: ${latency}ms)';
            _connectionStatusColor = Colors.red;
          });
        }
      } else {
        setState(() {
          _connectionStatus = 'Failed';
          _connectionStatusColor = Colors.red;
        });
      }
    } catch (e) {
      print('Connection test failed: $e');
      setState(() {
        _connectionStatus = 'Failed';
        _connectionStatusColor = Colors.red;
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
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
        _isAudioOn = true;
      }
    });

    print('Preview initialized - Video: $_isVideoOn, Audio: $_isAudioOn');
  }


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
  void onAudioDeviceChanged({HMSAudioDevice? currentAudioDevice, List<HMSAudioDevice>? availableAudioDevice}) {
    print('Audio device changed: Current device: $currentAudioDevice, Available devices: $availableAudioDevice');
  }

  @override
  void onPeerListUpdate({required List<HMSPeer> addedPeers, required List<HMSPeer> removedPeers}) {
    if (!mounted) return;

    setState(() {
      _peers.addAll(addedPeers.where((peer) => !_peers.contains(peer)));
      _peers.removeWhere((peer) => removedPeers.contains(peer));
    });

    print('Peer list updated - Current peers: ${_peers.length}');
  }

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {
    if (peer.isLocal && mounted) {
      print("Local peer update: $update");

      if (peer is HMSLocalPeer) {
        HMSLocalPeer localPeer = peer;

        if (localPeer.videoTrack != null) {
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
  }

  @override
  void onRoomUpdate({required HMSRoom room, required HMSRoomUpdate update}) {}

  @override
  Widget build(BuildContext context) {
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
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Username
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Get Started',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: _getPeerColor(widget.username),
                                    child: Text(
                                      _getInitials(widget.username),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.username,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Set up your audio and video before joining',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Participant message with styled container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _peers.isEmpty ? Icons.person : Icons.group,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _peers.isEmpty
                                  ? 'You are the first to join'
                                  : '${_peers.length} ${_peers.length == 1 ? 'other' : 'others'} in the session',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_peers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 60),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _peers.map((peer) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: _getPeerColor(peer.name),
                                      child: Text(
                                        _getInitials(peer.name),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      peer.name,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Colors.white))
                          : _isVideoOn && _localVideoTrack != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildVideoView(),
                      )
                          : Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: _getPeerColor(widget.username),
                          child: Text(
                            _getInitials(widget.username),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildToggleButton(
                          icon: _isAudioOn ? Icons.mic : Icons.mic_off,
                          color: _isAudioOn ? Colors.green : Colors.red,
                          onTap: _toggleAudio,
                          isLoading: _isTogglingAudio,
                        ),
                        const SizedBox(width: 24),
                        _buildToggleButton(
                          icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                          color: _isVideoOn ? Colors.green : Colors.red,
                          onTap: _toggleVideo,
                          isLoading: _isTogglingVideo,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildActionButton(
                          text: 'Test Connection',
                          icon: Icons.network_check,
                          onTap: _testConnection,
                          isLoading: _isTestingConnection,
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.deepOrange],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Connection: $_connectionStatus',
                        style: TextStyle(
                          color: _connectionStatusColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Action buttons at the bottom
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            text: 'Back',
                            onTap: _goBack,
                            isLoading: false,
                            gradient: const LinearGradient(
                              colors: [Colors.grey, Colors.blueGrey],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionButton(
                            text: 'Join Now',
                            onTap: _joinMeeting,
                            isLoading: _isJoining,
                            gradient: const LinearGradient(
                              colors: [Colors.blue, Colors.lightBlue],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
  }) {
    return GestureDetector(
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
        scaleType: ScaleType.SCALE_ASPECT_BALANCED,
      );
    } catch (e) {
      print("Error building video view: $e");
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 30),
            const SizedBox(height: 8),
            Text(
              "Camera error: $e",
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }
}