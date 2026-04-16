import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'wallet/send_money_screen.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});
  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final myrabaHandle = auth.myrabaHandle ?? '';
    final deepLink = 'myraba://pay/$myrabaHandle';

    return Scaffold(
      backgroundColor: context.mc.bg,
      appBar: AppBar(
        title: Text('QR Code'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: MyrabaColors.green,
          labelColor: MyrabaColors.green,
          unselectedLabelColor: context.mc.textHint,
          tabs: const [
            Tab(text: 'My QR Code'),
            Tab(text: 'Scan to Pay'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MyQrTab(myrabaHandle: myrabaHandle, deepLink: deepLink),
          const _ScanTab(),
        ],
      ),
    );
  }
}

class _MyQrTab extends StatelessWidget {
  final String myrabaHandle;
  final String deepLink;
  const _MyQrTab({required this.myrabaHandle, required this.deepLink});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(height: 16),
          Text('Share your code to receive money',
              style: TextStyle(color: context.mc.textSecond, fontSize: 14)),
          SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: QrImageView(
              data: deepLink,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'v\u20a6$myrabaHandle',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: MyrabaColors.green,
            ),
          ),
          SizedBox(height: 8),
          Text(deepLink,
              style:
                  TextStyle(fontSize: 12, color: context.mc.textHint)),
          SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: deepLink));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Payment link copied!'),
                    backgroundColor: MyrabaColors.green),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy Payment Link'),
          ),
        ],
      ),
    );
  }
}

class _ScanTab extends StatefulWidget {
  const _ScanTab();
  @override
  State<_ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<_ScanTab> {
  final _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;
    setState(() => _scanned = true);
    _controller.stop();

    // Parse myraba://pay/{myrabaHandle}
    if (code.startsWith('myraba://pay/')) {
      final handle = code.replaceFirst('myraba://pay/', '');
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SendMoneyScreen(prefilledHandle: handle)),
      );
    } else {
      setState(() => _scanned = false);
      _controller.start();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid Myraba QR code'),
            backgroundColor: MyrabaColors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        // Overlay
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: MyrabaColors.green, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: context.mc.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Scan a Myraba QR code',
                  style:
                      TextStyle(color: context.mc.textPrimary, fontSize: 14)),
            ),
          ),
        ),
      ],
    );
  }
}
