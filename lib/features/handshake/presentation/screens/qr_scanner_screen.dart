import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _hasScanned = false;

  // Permission state: null = still checking, true = denied, false = granted
  bool? _isPermissionDenied;
  bool _isPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndRequestPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Only re-check status, never call .request() on resume
      _recheckPermission();
    }
  }

  /// Called once on init – requests permission if needed.
  Future<void> _checkAndRequestPermission() async {
    var status = await Permission.camera.status;
    debugPrint('[QrScanner] Initial status: $status');

    if (!status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.camera.request();
      debugPrint('[QrScanner] After request: $status');
    }

    if (!mounted) return;

    if (status.isGranted) {
      _startScanner();
    } else {
      setState(() {
        _isPermissionDenied = true;
        _isPermanentlyDenied = status.isPermanentlyDenied;
      });
    }
  }

  /// Called on resume – only checks status, never prompts.
  Future<void> _recheckPermission() async {
    final status = await Permission.camera.status;
    debugPrint('[QrScanner] Recheck status: $status');
    if (!mounted) return;

    if (status.isGranted) {
      if (_isPermissionDenied == true) {
        // Permission was denied before but is now granted – start scanner
        _startScanner();
      }
      // If scanner was already running, do nothing (MobileScanner handles its own lifecycle)
    } else {
      // Permission was revoked while app was in background
      _stopScanner();
      setState(() {
        _isPermissionDenied = true;
        _isPermanentlyDenied = status.isPermanentlyDenied;
      });
    }
  }

  void _startScanner() {
    _stopScanner(); // Dispose old controller if any
    final controller = MobileScannerController();
    setState(() {
      _controller = controller;
      _isPermissionDenied = false;
      _isPermanentlyDenied = false;
    });
  }

  void _stopScanner() {
    _controller?.dispose();
    _controller = null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    final uri = Uri.tryParse(code);
    if (uri == null) {
      _showError('Invalid QR code');
      return;
    }

    final pathSegments = uri.pathSegments;

    if (pathSegments.length != 1) {
      _showError('Invalid QR code format. Expected: https://ixo.app/{id}');
      return;
    }

    setState(() {
      _hasScanned = true;
    });

    context.go('/handshake/${pathSegments[0]}');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopScanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Still checking permission
    if (_isPermissionDenied == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Permission denied view
    if (_isPermissionDenied == true) {
      return _buildPermissionDeniedView();
    }

    // Scanner view
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller?.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller?.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_controller != null)
            MobileScanner(
              controller: _controller!,
              onDetect: _onDetect,
            ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 110,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'Place QR code in frame',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 80,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'Camera Permission Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'This feature requires camera access to scan QR codes for secure exchange.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_isPermanentlyDenied)
                ElevatedButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _checkAndRequestPermission,
                  icon: const Icon(Icons.security),
                  label: const Text('Grant Permission'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
