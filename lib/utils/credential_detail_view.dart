/*
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CredentialDetailView extends StatelessWidget {
  final Map<String, dynamic> credential;

  const CredentialDetailView({Key? key, required this.credential})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Pretty-print the JSON
    final prettyJson = const JsonEncoder.withIndent('  ').convert(credential);

    return Scaffold(
      backgroundColor: const Color(0xFF101828),
      appBar: AppBar(
        title: const Text(
          'Credential Detail',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF101828),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: SelectableText(
            prettyJson,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Courier',
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
*/

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CredentialDetailView extends StatefulWidget {
  final Map<String, dynamic> credential;
  final String walletid;

  const CredentialDetailView({
    Key? key,
    required this.credential,
    required this.walletid,
  }) : super(key: key);

  @override
  State<CredentialDetailView> createState() => _CredentialDetailViewState();
}

class _CredentialDetailViewState extends State<CredentialDetailView> {
  Map<String, dynamic>? _status; // ⬅️ will hold status response
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _fetchStatus();
    });
  }

  /*  Future<void> _fetchStatus() async {
    setState(() => _loading = true);

    // final walletId = widget.credential['wallet'];
    // final credentialId = widget.credential['id'];
    final credentialId = 'urn:uuid:c8c3f0ce-5b7e-4115-bf8a-0066ca5a4b16';

    final res = await ApiClient.getCredentialStatus(
      // walletId: widget.walletid,
      walletId: 'c0930282-fcbc-401c-8ef5-46f341c59b1a',
      credentialId: credentialId,
      context: context,
    );

    if (res.containsKey('status')) {
      final statusData = res['status'];
      setState(() {
        if (statusData is List && statusData.isNotEmpty) {
          _status = statusData.first as Map<String, dynamic>;
          print("Status -==========================$_status");
        } else if (statusData is Map<String, dynamic>) {
          _status = statusData;
        } else {
          _status = {"message": "Unknown status format"};
          print("Else Status -==========================$res['status']");
        }
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      final err = res['error']['message'];
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Failed to load status: $err')));
    }
  }*/

  @override
  Widget build(BuildContext context) {
    // Pretty-print the JSON
    final prettyJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(widget.credential);

    return Scaffold(
      backgroundColor: const Color(0xFF101828),
      appBar: AppBar(
        title: const Text(
          'Credential Detail',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF101828),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  prettyJson,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Courier',
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  )
                : _status != null
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade800,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Credential Status: ${jsonEncode(_status)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
