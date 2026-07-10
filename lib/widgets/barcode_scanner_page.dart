import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/rent_plan_service.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  late AnimationController _animController;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isFlashOn = false;
  bool _hasScanned = false;
  bool _isSearching = false;
  Map<String, dynamic>? _foundUnit;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onBarcodeTextChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    final trimmed = val.trim();
    if (trimmed.length < 4) {
      if (_foundUnit != null || _isSearching) {
        setState(() {
          _foundUnit = null;
          _isSearching = false;
        });
      }
      return;
    }

    setState(() {
      _isSearching = true;
      _foundUnit = null;
    });

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final res = await RentPlanService().getLaptopUnitByBarcode(trimmed);
      if (mounted) {
        setState(() {
          _isSearching = false;
          _foundUnit = res['status'] == true && res['data'] != null ? res['data'] : null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Camera Section ────────────────────────────────────────────
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Camera View
                MobileScanner(
                  controller: _controller,
                  errorBuilder: (context, error, child) {
                    String errorMsg = 'Terjadi kesalahan pada kamera.';
                    if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
                      errorMsg = 'Izin kamera ditolak. Berikan izin kamera di pengaturan aplikasi lalu restart.';
                    }
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              errorMsg,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Coba Lagi'),
                              onPressed: () => _controller.start(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6A11CB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  onDetect: (BarcodeCapture capture) {
                    if (_hasScanned || _focusNode.hasFocus) return;
                    for (final barcode in capture.barcodes) {
                      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                        setState(() => _hasScanned = true);
                        Navigator.pop(context, barcode.rawValue);
                        break;
                      }
                    }
                  },
                ),

                // 2. Dark Overlay with scan hole
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.6),
                    BlendMode.srcOut,
                  ),
                  child: Stack(
                    children: [
                      Container(color: Colors.transparent),
                      Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.72,
                          height: MediaQuery.of(context).size.width * 0.72,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Scan Corners
                _buildScanOverlay(context),

                // 4. Animated Laser Line
                Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.72,
                    height: MediaQuery.of(context).size.width * 0.72,
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        final h = MediaQuery.of(context).size.width * 0.72;
                        return Stack(
                          children: [
                            Positioned(
                              top: _animController.value * (h - 4),
                              left: 12,
                              right: 12,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6A11CB),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6A11CB).withValues(alpha: 0.8),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // 5. Top Controls (Close / Flash / Flip)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _iconBtn(Icons.close_rounded, () => Navigator.pop(context)),
                      Row(
                        children: [
                          _iconBtn(
                            _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            () async {
                              await _controller.toggleTorch();
                              setState(() => _isFlashOn = !_isFlashOn);
                            },
                            color: _isFlashOn ? Colors.yellow : Colors.white,
                          ),
                          const SizedBox(width: 12),
                          _iconBtn(Icons.flip_camera_ios_rounded, () => _controller.switchCamera()),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Panel (Instruction text + Manual Input + Result) ──
          Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Instruction label
                  const Text(
                    'Scan Barcode / QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Posisikan barcode di dalam kotak atau ketik secara manual',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 12),

                  // Input field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Ketik barcode manual...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                        prefixIcon: const Icon(Icons.dialpad_rounded, color: Color(0xFF7E57C2), size: 20),
                        suffixIcon: _textController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                                onPressed: () {
                                  _textController.clear();
                                  _onBarcodeTextChanged('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: _onBarcodeTextChanged,
                    ),
                  ),

                  // Search result
                  if (_isSearching) ...[
                    const SizedBox(height: 12),
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7E57C2)),
                    ),
                  ] else if (_foundUnit != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.laptop_rounded, color: Colors.greenAccent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _foundUnit!['nama_laptop'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'SN: ${_foundUnit!['serial_number'] ?? '-'} | ${_foundUnit!['kondisi'] ?? '-'}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, _textController.text.trim()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6A11CB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                              minimumSize: Size.zero,
                            ),
                            child: const Text('Pilih', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_textController.text.trim().length >= 4) ...[
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Unit laptop tidak ditemukan',
                          style: TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildScanOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.72;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            _buildCorner(top: 0, left: 0, isTop: true, isLeft: true),
            _buildCorner(top: 0, right: 0, isTop: true, isLeft: false),
            _buildCorner(bottom: 0, left: 0, isTop: false, isLeft: true),
            _buildCorner(bottom: 0, right: 0, isTop: false, isLeft: false),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner({
    double? top, double? bottom, double? left, double? right,
    required bool isTop, required bool isLeft,
  }) {
    const double length = 24.0;
    const double thickness = 4.0;
    const Color color = Color(0xFF7E57C2);

    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: SizedBox(
        width: length,
        height: length,
        child: Stack(
          children: [
            Positioned(
              top: isTop ? 0 : null, bottom: !isTop ? 0 : null,
              left: isLeft ? 0 : null, right: !isLeft ? 0 : null,
              child: Container(
                width: length, height: thickness,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Positioned(
              top: isTop ? 0 : null, bottom: !isTop ? 0 : null,
              left: isLeft ? 0 : null, right: !isLeft ? 0 : null,
              child: Container(
                width: thickness, height: length,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
