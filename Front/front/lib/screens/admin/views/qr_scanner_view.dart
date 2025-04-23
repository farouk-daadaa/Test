import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:front/services/event_service.dart';
import 'package:provider/provider.dart';
import 'package:front/services/auth_service.dart';
import 'package:front/constants/colors.dart';
import 'dart:async';
import 'package:dio/dio.dart';

class QRScannerView extends StatefulWidget {
  final int eventId;

  const QRScannerView({Key? key, required this.eventId}) : super(key: key);

  @override
  _QRScannerViewState createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<QRScannerView> with WidgetsBindingObserver {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  StreamSubscription<Barcode>? _subscription;
  final EventService _eventService = EventService(baseUrl: 'http://192.168.1.13:8080');
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestCameraPermission();
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.getToken().then((token) {
      if (token != null && mounted) {
        _eventService.setToken(token);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      controller?.pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      controller?.resumeCamera();
    }
  }

  Future<void> _requestCameraPermission() async {
    if (await Permission.camera.request().isGranted) {
      if (mounted) {
        setState(() {});
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera permission is required to scan QR codes')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    controller?.pauseCamera();
    _subscription?.cancel();
    controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    _subscription = controller.scannedDataStream.listen((scanData) async {
      if (_isScanning && scanData.code != null && mounted) {
        print('Scanned QR code: ${scanData.code}, for event ID: ${widget.eventId}');
        setState(() => _isScanning = false);
        try {
          final success = await _eventService.checkIn(widget.eventId, scanData.code!);
          if (mounted) {
            print('Check-in result: $success');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? 'Check-in successful' : 'Check-in failed'),
                backgroundColor: success ? Colors.green : Colors.red,
              ),
            );
          }
          await Future.delayed(Duration(seconds: 2));
          if (mounted) {
            setState(() => _isScanning = true);
          }
        } on DioException catch (e) {
          if (mounted) {
            String errorMessage = 'Error: ${e.message}';
            if (e.response?.data != null && e.response?.data['message'] != null) {
              errorMessage = e.response!.data['message'];
              if (errorMessage.contains('outside allowed window')) {
                errorMessage = 'Check-in failed: Outside allowed time window (10 minutes before start until end)';
              } else if (errorMessage.contains('already checked in')) {
                errorMessage = 'Check-in failed: User already checked in';
              } else if (errorMessage.contains('not registered')) {
                errorMessage = 'Check-in failed: User not registered for this event';
              }
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
              ),
            );
            print('Check-in error: $errorMessage');
          }
          await Future.delayed(Duration(seconds: 2));
          if (mounted) {
            setState(() => _isScanning = true);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
            print('Unexpected error: $e');
          }
          await Future.delayed(Duration(seconds: 2));
          if (mounted) {
            setState(() => _isScanning = true);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR Code'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: AppColors.primary,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                _isScanning ? 'Scanning QR code...' : 'Processing...',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}