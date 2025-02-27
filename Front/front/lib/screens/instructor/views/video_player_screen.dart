import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String lessonTitle;

  const VideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    required this.lessonTitle,
  }) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _error;
  bool _isControlsVisible = true;
  Timer? _hideControlsTimer;
  bool _isFullscreen = true; // Track fullscreen state

  @override
  void initState() {
    super.initState();
    _setInitialOrientation();
    _initializeVideo();
  }

  void _setInitialOrientation() {
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  Future<void> _initializeVideo() async {
    try {
      final baseUrl = 'http://192.168.1.13:8080';
      final fullUrl = widget.videoUrl.startsWith('http')
          ? widget.videoUrl
          : '$baseUrl${widget.videoUrl}';

      _controller = VideoPlayerController.network(fullUrl);

      // Add listener for position updates
      _controller.addListener(() {
        if (mounted) {
          setState(() {}); // Ensure UI updates correctly
        }
      });

      await _controller.initialize();

      // Ensure the video starts from where it left off
      await _controller.setLooping(false); // Ensure no unintended looping
      await _controller.play();

      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _error = 'Error loading video: $e');
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    final controller = _controller;
    if (controller.value.isInitialized) {
      setState(() {});
    }
  }

  void _toggleControls() {
    setState(() => _isControlsVisible = !_isControlsVisible);
    _hideControlsTimer?.cancel();
    if (_isControlsVisible && _controller.value.isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _isControlsVisible = false);
        }
      });
    }
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
      _hideControlsTimer?.cancel();
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _controller.value.isPlaying) {
          setState(() => _isControlsVisible = false);
        }
      });
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Player
            if (_error != null)
              _ErrorDisplay(error: _error!)
            else if (_isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFDB2777)),
              ),

            // Controls Overlay
            if (_isControlsVisible && _isInitialized) ...[
              _TopBar(
                lessonTitle: widget.lessonTitle,
                onBack: () {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                    DeviceOrientation.portraitDown,
                  ]);
                  Navigator.pop(context);
                },
              ),
              _CenterPlayButton(
                controller: _controller,
                onPressed: _togglePlayPause,
              ),
              _BottomControls(
                controller: _controller,
                onPlayPause: _togglePlayPause,
                onFullscreen: _toggleFullscreen,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}

class _ErrorDisplay extends StatelessWidget {
  final String error;

  const _ErrorDisplay({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          error,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String lessonTitle;
  final VoidCallback onBack;

  const _TopBar({
    required this.lessonTitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + 16,
          16,
          16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                lessonTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 48), // Balance for back button
          ],
        ),
      ),
    );
  }
}

class _CenterPlayButton extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onPressed;

  const _CenterPlayButton({
    required this.controller,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          return AnimatedOpacity(
            opacity: value.isPlaying ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: onPressed,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onPlayPause;
  final VoidCallback onFullscreen;

  const _BottomControls({
    required this.controller,
    required this.onPlayPause,
    required this.onFullscreen,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress Bar
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                if (!value.isInitialized) return const SizedBox();

                final duration = value.duration;
                final position = value.position;

                return Slider(
                  value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                  min: 0.0,
                  max: duration.inMilliseconds.toDouble(),
                  activeColor: const Color(0xFFDB2777),
                  inactiveColor: Colors.white30,
                  onChanged: (newPosition) {
                    controller.seekTo(Duration(milliseconds: newPosition.toInt()));
                  },
                );
              },
            ),
            const SizedBox(height: 8),

            // Controls Row
            Row(
              children: [
                // Play/Pause Button
                IconButton(
                  icon: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      return Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      );
                    },
                  ),
                  onPressed: onPlayPause,
                ),
                const SizedBox(width: 8),

                // Current Position
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    return Text(
                      _formatDuration(value.position),
                      style: const TextStyle(color: Colors.white),
                    );
                  },
                ),
                const Text(
                  ' / ',
                  style: TextStyle(color: Colors.white54),
                ),
                // Total Duration
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    return Text(
                      _formatDuration(value.duration),
                      style: const TextStyle(color: Colors.white54),
                    );
                  },
                ),
                const Spacer(),

                // Fullscreen Button
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                  onPressed: onFullscreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}