import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:front/services/event_service.dart';
import 'package:provider/provider.dart';
import 'package:front/services/auth_service.dart';
import 'package:front/constants/colors.dart';

class QRScannerView extends StatefulWidget {
  final int eventId;

  const QRScannerView({Key? key, required this.eventId}) : super(key: key);

  @override
  _QRScannerViewState createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<QRScannerView> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  final EventService _eventService = EventService(baseUrl: 'http://192.168.1.13:8080');
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.getToken().then((token) {
      if (token != null) {
        _eventService.setToken(token);
      }
    });
  }

  Future<void> _requestCameraPermission() async {
    if (await Permission.camera.request().isGranted) {
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera permission is required to scan QR codes')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (_isScanning && scanData.code != null) {
        setState(() => _isScanning = false);
        try {
          final success = await _eventService.checkIn(widget.eventId, scanData.code!);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Check-in successful' : 'Check-in failed'),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
          await Future.delayed(Duration(seconds: 2));
          setState(() => _isScanning = true);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
          await Future.delayed(Duration(seconds: 2));
          setState(() => _isScanning = true);
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