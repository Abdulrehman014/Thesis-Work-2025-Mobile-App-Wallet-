import 'package:flutter/material.dart';

class PresentationRequestView extends StatefulWidget {
  /// Each credential: { "id": "...", "title": "Bank Id", "issuer": "CH Authority" }
  final List<Map<String, String>> credentials;

  /// Called when user confirms; you'll receive the selected credential id.
  final Future<void> Function(String credentialId) onDisclose;

  /// Called when user declines.
  final VoidCallback onDecline;

  /// Optional heading
  final String heading;

  const PresentationRequestView({
    super.key,
    required this.credentials,
    required this.onDisclose,
    required this.onDecline,
    this.heading = "Presentation Request",
  });

  @override
  State<PresentationRequestView> createState() =>
      _PresentationRequestViewState();
}

class _PresentationRequestViewState extends State<PresentationRequestView>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _introCtrl;
  late final AnimationController _gradientCtrl;
  late final Animation<double> _slideIn;
  late final Animation<double> _fadeIn;

  int _index = 0;
  bool _submitting = false;
  String? _selectedId;

  // Theme constants (match your app)
  static const Color kBg = Color(0xFF101828);
  static const Color kPrimary = Color(0xFF0A63C9);
  static const Color kCardDark = Color(
    0xFF0B4AA8,
  ); // deep blue for gradient mix

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);

    _selectedId = widget.credentials.isNotEmpty
        ? widget.credentials.first['id']
        : null;

    // Entrance animations
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideIn = Tween<double>(
      begin: 30,
      end: 0,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_introCtrl);
    _fadeIn = CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut);
    _introCtrl.forward();

    // Subtle "alive" gradient shimmer
    _gradientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _introCtrl.dispose();
    _gradientCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() {
      _index = i;
      _selectedId = widget.credentials[i]['id'];
    });
  }

  Future<void> _handleDisclose() async {
    if (_selectedId == null) return;
    setState(() => _submitting = true);
    try {
      await widget.onDisclose(_selectedId!);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final creds = widget.credentials;
    final canScroll = creds.length > 1;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.heading,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_introCtrl, _gradientCtrl]),
        builder: (context, _) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8 + _slideIn.value,
            ),
            child: Opacity(
              opacity: _fadeIn.value,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card carousel
                  SizedBox(
                    height: 190,
                    child: PageView.builder(
                      controller: _pageController,
                      physics: canScroll
                          ? const BouncingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      onPageChanged: _onPageChanged,
                      itemCount: creds.length,
                      itemBuilder: (context, i) {
                        final c = creds[i];
                        final selected = i == _index;
                        final t = _gradientCtrl.value; // 0..1 for gradient

                        return AnimatedScale(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          scale: selected ? 1.0 : 0.96,
                          child: _AnimatedCredentialCard(
                            title: c['title'] ?? 'Credential',
                            issuer: c['issuer'] ?? 'Issuer',
                            t: t,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${_index + 1} of ${creds.isEmpty ? 1 : creds.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Credential to present',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  for (final c in creds)
                    SizedBox(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        height: kToolbarHeight,
                        width: kToolbarHeight * 12,
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                          // dark background to match UI
                          border: Border(
                            top: BorderSide(
                              color: Color(0xFF0A63C9), // accent color
                              width: 1.2,
                            ),
                            bottom: BorderSide(
                              color: Color(0xFF0A63C9), // accent color
                              width: 1.2,
                            ),
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            c['title'] ?? c['id'] ?? 'Credential',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submitting ? null : widget.onDecline,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.4),
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _handleDisclose,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Disclose'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

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
    // Animate the gradient’s focal points for a classy “alive” feel.
    final begin = Alignment(-0.6 + 0.2 * t, -1 + 0.5 * t);
    final end = Alignment(0.8 - 0.2 * t, 0.9 - 0.5 * t);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
            // top badge glow
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
