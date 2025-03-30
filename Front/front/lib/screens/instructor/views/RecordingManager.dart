import 'package:hmssdk_flutter/hmssdk_flutter.dart';

class RecordingManager implements HMSUpdateListener {
  final HMSSDK hmsSDK;
  bool _isRecording = false;
  final Function(bool)? onRecordingStateChanged; // Add callback

  RecordingManager({required this.hmsSDK, this.onRecordingStateChanged}) {
    // Add the update listener when the RecordingManager is created
    hmsSDK.addUpdateListener(listener: this);
  }

  bool get isRecording => _isRecording;

  // Start recording the session
  Future<bool> startRecording() async {
    try {
      // Configure recording settings
      HMSRecordingConfig recordingConfig = HMSRecordingConfig(
        meetingUrl: "", // Leave empty for HMS server recording
        toRecord: true, // Enable recording
        rtmpUrls: [],   // Add RTMP URLs if you want to stream to a custom RTMP server
      );

      // Start recording
      await hmsSDK.startRtmpOrRecording(hmsRecordingConfig: recordingConfig);
      _isRecording = true; // Optimistically set to true
      onRecordingStateChanged?.call(_isRecording); // Notify listeners
      print('Recording started successfully');
      return true;
    } catch (e) {
      print('Error starting recording: $e');
      return false;
    }
  }

  // Stop recording the session
  Future<bool> stopRecording() async {
    try {
      await hmsSDK.stopRtmpAndRecording();
      _isRecording = false; // Optimistically set to false
      onRecordingStateChanged?.call(_isRecording); // Notify listeners
      print('Recording stopped successfully');
      return true;
    } catch (e) {
      print('Error stopping recording: $e');
      return false;
    }
  }

  // Check the current recording state
  Future<bool> checkRecordingState() async {
    // Since we are now tracking the state via onRoomUpdate, we can return the current value of _isRecording
    print('Current recording state: $_isRecording');
    return _isRecording;
  }

  // Implement HMSUpdateListener methods
  @override
  void onRoomUpdate({required HMSRoom room, required HMSRoomUpdate update}) {
    if (update == HMSRoomUpdate.serverRecordingStateUpdated) {
      // In version 1.10.5, HMSRoom does not have a direct serverRecordingState property
      // We rely on our optimistic updates, but notify listeners of the event
      print('Server recording state updated');
      onRecordingStateChanged?.call(_isRecording); // Notify listeners
    }
  }

  @override
  void onJoin({required HMSRoom room}) {}

  @override
  void onPeerUpdate({required HMSPeer peer, required HMSPeerUpdate update}) {}

  @override
  void onTrackUpdate(
      {required HMSTrack track,
        required HMSTrackUpdate trackUpdate,
        required HMSPeer peer}) {}

  @override
  void onHMSError({required HMSException error}) {
    print('HMS Error: ${error.message}');
  }

  @override
  void onMessage({required HMSMessage message}) {}

  @override
  void onRoleChangeRequest({required HMSRoleChangeRequest roleChangeRequest}) {}

  @override
  void onChangeTrackStateRequest(
      {required HMSTrackChangeRequest hmsTrackChangeRequest}) {}

  @override
  void onRemovedFromRoom(
      {required HMSPeerRemovedFromPeer hmsPeerRemovedFromPeer}) {}

  @override
  void onReconnecting() {}

  @override
  void onReconnected() {}

  @override
  void onAudioDeviceChanged(
      {HMSAudioDevice? currentAudioDevice,
        List<HMSAudioDevice>? availableAudioDevice}) {}

  @override
  void onPeerListUpdate(
      {required List<HMSPeer> addedPeers, required List<HMSPeer> removedPeers}) {}

  @override
  void onSessionStoreAvailable({HMSSessionStore? hmsSessionStore}) {}

  @override
  void onUpdateSpeakers({required List<HMSSpeaker> updateSpeakers}) {}

  // Clean up the listener when the RecordingManager is disposed
  void dispose() {
    hmsSDK.removeUpdateListener(listener: this);
  }
}