import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/auth_services.dart';
import '../utils/credential_detail_view.dart';
import 'login_view.dart';

class CredentialView extends StatefulWidget {
  const CredentialView({Key? key}) : super(key: key);

  @override
  State<CredentialView> createState() => _CredentialViewState();
}

class _CredentialViewState extends State<CredentialView> {
  String? _walletName;
  String? _walletID;
  String? _walletDID;
  List<Map<String, dynamic>> _credentials = [];
  bool _loading = false;
  late final matchCredentialsPdIDs;

  var _verificationStateId;

  Map<String, dynamic>? _presentationDefinition;
  String? resolvePresentationRequestUrl;

  String IdsofCredentials = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _fetchWallets();
      await _fetchCredentials();
      // await _fetchWalletDIDs();

      final res = await ApiClient.getWalletDIDs(
        walletId: _walletID!,
        context: context,
      );

      if (res.containsKey('dids')) {
        final didList = res['dids'] as List;

        if (didList.isNotEmpty) {
          final firstDid = didList.first['did'] as String; // ✅ get "did"
          print("Wallet Primary DID = $firstDid");

          setState(() {
            _walletDID = firstDid;
          });

          // ScaffoldMessenger.of(
          //   context,
          // ).showSnackBar(SnackBar(content: Text("✅ DID: $firstDid")));
        } else {
          // ScaffoldMessenger.of(
          //   context,
          // ).showSnackBar(const SnackBar(content: Text("❌ No DIDs found")));
        }
      } else {
        final err = res['error']['message'];
        print("❌ Error fetching DIDs: $err");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ $err")));
      }
    });
  }

  Map<String, dynamic>? _status; // ⬅️ will hold status response

  Future<void> _fetchWallets() async {
    setState(() => _loading = true);
    final res = await ApiClient.getWallets(context);
    if (res.containsKey('wallets')) {
      final wallets = (res['wallets'] as List).cast<Map<String, dynamic>>();
      if (wallets.isNotEmpty) {
        _walletName = wallets.first['name'] as String?;
        _walletID = wallets.first['id'] as String?;
      }
    } else {
      final msg =
          (res['error'] as Map?)?['message'] ?? 'Failed to fetch wallets';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    setState(() => _loading = false);
  }

  Future<void> _confirmAndDelete(int index) async {
    final id = _credentials[index]['id'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete credential?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final res = await ApiClient.deleteCredential(id, context);
      if (res.containsKey('message')) {
        setState(() => _credentials.removeAt(index));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(res['message'])));
      } else {
        final err = res['error']['message'] ?? 'Failed to delete';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  // ✅ Fetch credentials and always refresh _credentials state
  Future<void> _fetchCredentials() async {
    setState(() => _loading = true);

    final res = await ApiClient.getCredentials(context);
    print('[_fetchCredentials] Raw API response: $res'); // 👈 ADD THIS

    if (res.containsKey('credentials')) {
      final creds = (res['credentials'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _credentials = creds; // ✅ replace list instead of appending
        if (kDebugMode) {
          print(
            '[_fetchCredentials] Number of credentials fetched: ${creds.length}',
          );
        }
      });
    } else {
      final msg =
          (res['error'] as Map?)?['message'] ?? 'Failed to fetch credentials';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      print('[_fetchCredentials] Error response: $msg'); // 👈 ADD THIS
    }

    setState(() => _loading = false);
  }

  Future<void> _handleLogout() async {
    final res = await ApiClient.logOut(context);
    final msg =
        res['message'] ??
        (res['error']?['message'] ?? 'Logout failed').toString();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginView()),
      (_) => false,
    );
  }

  Future<void> _handleAddCertificate() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScannerView(isVerification: false),
      ),
    );

    if (code != null) {
      /*  ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Certificate added: $code')*/

      // )
      // );
      await _fetchCredentials();
    }
  }

  bool isLoading = false;

  Future<void> _handleVerifyCertificate() async {
    setState(() => isLoading = true); // ⬅️ NEW FLAG
    try {
      // 1️⃣ Scan or paste QR
      final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const QrScannerView(isVerification: true),
        ),
      );
      if (code == null || code.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      // 2️⃣ Decode the URL
      final decoded = Uri.decodeFull(code);
      print("Decoded URL: $decoded");

      // 3️⃣ Parse it
      final uri = Uri.parse(decoded);

      // ✅ Extract state
      final stateId = uri.queryParameters['state'];
      if (stateId == null || stateId.isEmpty) {
        throw Exception("❌ No state parameter found");
      }
      _verificationStateId = stateId;
      print("Extracted state: $stateId");

      // ✅ Extract presentation_definition_uri
      final pdUriString = uri.queryParameters['presentation_definition_uri'];
      if (pdUriString == null || pdUriString.isEmpty) {
        throw Exception("❌ No presentation_definition_uri found");
      }
      print("Presentation Definition URI: $pdUriString");

      // 4️⃣ Fetch JSON from presentation_definition_uri
      final dio = Dio();
      final resp = await dio.get(pdUriString);
      if (resp.data is! Map<String, dynamic>) {
        throw Exception("Invalid response JSON at $pdUriString");
      }
      _presentationDefinition = resp.data as Map<String, dynamic>;
      print("Presentation Definition JSON: $_presentationDefinition");

      // STEP 01: matchCredentialsForPresentationDefinition
      final res = await ApiClient.matchCredentialsForPresentationDefinition(
        _presentationDefinition!,
        context,
      );
      if (!res.containsKey('credentials')) {
        throw Exception((res['error'] as Map)['message']);
      }
      final matches = (res['credentials'] as List).cast<Map<String, dynamic>>();
      matchCredentialsPdIDs = matches.map((m) => m['id'] as String).toList();
      print('All IDs: ${matchCredentialsPdIDs[0]}');

      // STEP 02: resolvePresentationRequest
      final response = await ApiClient.resolvePresentationRequest(
        code,
        context,
      );
      if (!response.containsKey('presentationRequest')) {
        throw Exception((response['error'] as Map)['message']);
      }
      resolvePresentationRequestUrl = response['presentationRequest'];
      print(' resolvePresentationRequest= $resolvePresentationRequestUrl');

      // STEP 03: usePresentationRequest
      final result = await ApiClient.usePresentationRequest(
        presentationRequest: resolvePresentationRequestUrl ?? '',
        selectedCredentials: [matchCredentialsPdIDs[0]],
        context: context,
      );
      if (!result.containsKey('response')) {
        throw Exception((result['error']['message'] ?? '').toString());
      }
      print('All usePresentationRequest : ${result['response']}');

      // STEP 04: getVerificationSession
      final resState = await ApiClient.getVerificationSession(
        stateId: _verificationStateId,
        context: context,
      );
      if (!resState.containsKey('sessionDetails')) {
        throw Exception(resState['error']['message']);
      }
      print('All Session Data : ${resState['sessionDetails']}');

      // ✅ SUCCESS: All steps passed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Verification successful')),
      );
    } catch (e) {
      // Show any error in snackbar
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Verification failed: $e')));
      print('Verification error: $e');
    } finally {
      setState(() => isLoading = false); // ⬅️ hide loader always
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF101828),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1E315A)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _walletName ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _walletID != null ? 'ID: $_walletID' : '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    height: 79, // ✅ Give enough vertical space
                    child: Text(
                      _walletDID != null ? 'DID: $_walletDID' : '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: Colors.white),
              title: const Text(
                'Add Micro Credentials',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _handleAddCertificate();
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_rounded, color: Colors.white),
              title: const Text(
                'Verify Micro Credentials',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                _handleVerifyCertificate();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _handleLogout();
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Your Credentials',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF101828),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Container(
        color: const Color(0xFF101828),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_walletName != null) ...[
                const Text('Wallet:', style: TextStyle(color: Colors.white70)),
                Text(
                  _walletName!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchCredentials,
                  color: Colors.white,
                  backgroundColor: const Color(0xFF101828),
                  child: GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: _credentials.length,
                    itemBuilder: (context, i) {
                      final parsed =
                          _credentials[i]['parsedDocument']
                              as Map<String, dynamic>;
                      final subject =
                          parsed['credentialSubject'] as Map<String, dynamic>;

                      final fullName = subject['fullName'] as String?;
                      final dob = subject['dateOfBirth'] as String?;
                      final email = subject['email'] as String?;

                      final credentialData =
                          subject['credential'] as Map<String, dynamic>?;
                      final credentialTitle =
                          credentialData?['title'] as String?;
                      final credentialLevel =
                          credentialData?['level'] as String?;

                      final issuanceRaw = parsed['issuanceDate'] as String?;
                      final expirationRaw = parsed['expirationDate'] as String?;
                      final issuedBy = parsed['IssuedBy'] as String?;

                      String? issuanceDate;
                      String? expirationDate;

                      if (issuanceRaw != null) {
                        final dt = DateTime.parse(issuanceRaw);
                        issuanceDate = DateFormat(
                          'yyyy-MM-dd HH:mm',
                        ).format(dt);
                      }

                      if (expirationRaw != null) {
                        final dt = DateTime.parse(expirationRaw);
                        expirationDate = DateFormat(
                          'yyyy-MM-dd HH:mm',
                        ).format(dt);
                      }

                      final affiliation =
                          subject['eduPersonPrimaryAffiliation'] as String?;
                      final types = List<String>.from(parsed['type'] as List);

                      return GestureDetector(
                        onLongPress: () => _confirmAndDelete(i),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CredentialDetailView(
                                  walletid: _walletID!,
                                  credential: _credentials[i],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E315A),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Flexible(
                              fit: FlexFit.loose,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (fullName != null) ...[
                                    Text(
                                      fullName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  if (credentialTitle != null) ...[
                                    Text(
                                      credentialTitle,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // const SizedBox(height: 8),
                                  ],

                                  if (credentialLevel != null) ...[
                                    Text(
                                      credentialLevel,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],

                                  if (issuanceDate != null &&
                                      expirationDate != null)
                                    Column(
                                      children: [
                                        if (dob != null)
                                          Row(
                                            children: [
                                              Text(
                                                'DOB            : ',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),

                                              Text(
                                                dob,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),

                                  const Spacer(),

                                  if (email != null)
                                    Text(
                                      '📧 $email',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),

                                  if (issuedBy != null)
                                    Row(
                                      children: [
                                        Text(
                                          'Issued By  : ',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        Flexible(
                                          child: Text(
                                            issuedBy,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  SizedBox(
                                    child: Row(
                                      children: [
                                        if (issuanceDate != null)
                                          Text(
                                            'Issued on  : ',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                        Text(
                                          ' ${issuanceDate}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),

                                        ///
                                      ],
                                    ),
                                  ),
                                  // const SizedBox(height: 5),
                                  if (expirationDate != null)
                                    Row(
                                      children: [
                                        Text(
                                          'Expires on : ',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        Text(
                                          expirationDate,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 5),

                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 2,
                                    children: types.map((t) {
                                      final type = t == t;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                          horizontal: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: type
                                              ? Colors.greenAccent
                                              : Colors.white24,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          t,
                                          style: TextStyle(
                                            color: type
                                                ? Colors.black87
                                                : Colors.white70,
                                            fontSize: 8,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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

// lib/views/qr_scanner_view.dart
class QrScannerView extends StatefulWidget {
  final bool isVerification; // NEW FLAG
  final Future<void> Function(String code)? onScan; // new callback
  const QrScannerView({super.key, this.isVerification = false, this.onScan});

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
  );
  StreamSubscription<BarcodeCapture>? _subscription;

  bool _torchOn = false;

  // for manual input
  final _manualCtrl = TextEditingController();

  late TabController _tabController;

  // 🔹 Animation controller
  late AnimationController _animController;
  late Animation<double> _anim;

  String? _scannedCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _subscription = _controller.barcodes.listen(_handleBarcode);
    // ✅ start only after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.value.isStarting) {
        _controller.start();
      }
    });

    _tabController = TabController(length: 2, vsync: this);

    // 🔹 Animate the card
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_scannedCode != null) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    _controller.stop();
    setState(() => _scannedCode = code);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed && _scannedCode == null) {
      _subscription ??= _controller.barcodes.listen(_handleBarcode);
      _controller.start();
    } else if (state != AppLifecycleState.resumed) {
      _subscription?.cancel();
      _subscription = null;
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _controller.dispose();
    _manualCtrl.dispose();
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _onAccept(String code) async {
    if (widget.isVerification) {
      setState(() => _scannedCode = null);
      Navigator.of(context).pop(code);
    } else {
      final res = await ApiClient.acceptCredential(code, context);
      if (res.containsKey('message')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] as String),
            backgroundColor: Color(0xFF0A63C9),
          ),
        );
        setState(() => _scannedCode = null);
        Navigator.of(context).pop(code);
      } else {
        // Improved error handling that works with both String and Map error types
        String errorMessage;
        if (res['error'] is Map) {
          errorMessage =
              (res['error'] as Map)['message']?.toString() ??
              'Failed to accept credential';
        } else {
          errorMessage =
              res['error']?.toString() ?? 'Failed to accept credential';
        }

        if (kDebugMode) {
          print('AcceptCredential error: $errorMessage');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onReject() {
    setState(() => _scannedCode = null);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scan QR or Paste ',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF101828),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        bottom: TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Color(0xFF0A63C9),
          controller: _tabController,
          tabs: const [
            Tab(text: 'Scan'),
            Tab(text: 'Paste'),
          ],
        ),
        actions: [
          if (_tabController.index == 0) ...[
            IconButton(
              icon: Icon(
                _torchOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: () {
                _controller.toggleTorch();
                setState(() => _torchOn = !_torchOn);
              },
            ),
            IconButton(
              icon: const Icon(Icons.cameraswitch, color: Colors.white),
              onPressed: () => _controller.switchCamera(),
            ),
          ],
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // === SCAN TAB ===
          Stack(
            children: [
              MobileScanner(controller: _controller, fit: BoxFit.cover),
              if (_scannedCode != null) ...[
                // 🔹 Show animated card in the middle
                Center(
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) {
                      return _AnimatedCredentialCard(
                        title: "Scanned Credential", // placeholder
                        issuer: "Demo Issuer", // placeholder
                        t: _anim.value,
                      );
                    },
                  ),
                ),

                // Buttons at bottom
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,

                    child: Container(
                      color: Colors.black45,
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _onReject,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _onAccept(_scannedCode!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0A63C9),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Accept'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // === PASTE TAB ===
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _manualCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Paste QR payload here',
                    labelStyle: TextStyle(color: Colors.white),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final code = _manualCtrl.text.trim();
                      if (code.isNotEmpty) {
                        _onAccept(code);
                      }
                    },
                    label: const Text('Submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A63C9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🔹 Animated card widget
class _AnimatedCredentialCard extends StatelessWidget {
  final String title;
  final String issuer;
  final double t;

  static const Color kPrimary = Color(0xFF0A63C9);
  static const Color kCardDark = Color(0xFF0B4AA8);

  const _AnimatedCredentialCard({
    required this.title,
    required this.issuer,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final begin = Alignment(-0.6 + 0.2 * t, -1 + 0.5 * t);
    final end = Alignment(0.8 - 0.2 * t, 0.9 - 0.5 * t);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      width: 300,
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [kPrimary, kCardDark],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: const Text(
                'Credential',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Issuer',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              issuer,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
