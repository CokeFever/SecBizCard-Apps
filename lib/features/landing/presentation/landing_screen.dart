import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class LandingScreen extends StatelessWidget {
  final bool invitationMode;

  const LandingScreen({super.key, this.invitationMode = false});

  void _launchStoreUrl(BuildContext context) async {
    const androidUrl =
        'https://play.google.com/store/apps/details?id=com.secbizcard.app';
    const iosUrl = 'https://apps.apple.com/app/id6470000000'; // Placeholder

    final url = Uri.parse(
      Theme.of(context).platform == TargetPlatform.android
          ? androidUrl
          : iosUrl,
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open store link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (invitationMode) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 48,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'SecBizCard Invitation',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A), // Slate 900
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'You\'ve been invited to connect via SecBizCard. To view this secure profile and exchange details, please use our mobile app.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFF475569), // Slate 600
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      _launchStoreUrl(context);
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Download App'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context, isDesktop),
            _buildHero(context, isDesktop),
            _buildFeatures(context, isDesktop),
            _buildDownloadSection(context, isDesktop),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 32,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SvgPicture.asset(
                  'assets/images/logo.svg',
                  width: 32, // Slightly larger
                  height: 32,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'SecBizCard',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (!invitationMode)
                TextButton(
                  onPressed: () {
                    context.go('/login');
                  },
                  child: Text(
                    'Continue to App',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF38BDF8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: isDesktop ? 120 : 60,
      ),
      child: Flex(
        direction: isDesktop ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: isDesktop ? 6 : 0,
            child: Column(
              crossAxisAlignment: isDesktop
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Text(
                  'The New Standard for\nProfessional Identity.',
                  textAlign: isDesktop ? TextAlign.start : TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 72 : 42,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Secure, instant, and verified contact exchange.\nPowered by the Cloud.',
                  textAlign: isDesktop ? TextAlign.start : TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: isDesktop ? 20 : 16,
                    color: const Color(0xFF94A3B8), // Slate 400
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 48),
                _buildStoreButtons(context, isDesktop),
              ],
            ),
          ),
          if (isDesktop) const Spacer(flex: 1),
          // Visual: Phone Mockup or Graphic
          if (isDesktop) Expanded(flex: 5, child: _buildHeroGraphic(context)),
        ],
      ),
    );
  }

  Widget _buildHeroGraphic(BuildContext context) {
    // Abstract Card Graphic
    return Container(
      height: 600,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B).withValues(alpha: 0.8),
            const Color(0xFF0F172A).withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
            blurRadius: 100,
            spreadRadius: -20,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 40,
            left: 40,
            right: 40,
            bottom: 40,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                        ),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      "Your Name",
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "Chief Technology Officer",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreButtons(BuildContext context, bool isDesktop) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
      children: [
        _storeButton(
          icon: FontAwesomeIcons.apple,
          label: 'Download on the',
          store: 'App Store',
          onTap: () => _launchStoreUrl(context),
        ),
        _storeButton(
          icon: FontAwesomeIcons.googlePlay,
          label: 'Get it on',
          store: 'Google Play',
          onTap: () => _launchStoreUrl(context),
        ),
      ],
    );
  }

  Widget _storeButton({
    required IconData icon,
    required String label,
    required String store,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 28, color: Colors.black),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  store,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatures(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E293B), // Slate 800
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 96,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive Grid manually
          double cardWidth = isDesktop ? 350 : constraints.maxWidth;

          return Wrap(
            spacing: 32,
            runSpacing: 32,
            alignment: WrapAlignment.center,
            children: [
              _featureCard(
                icon: FontAwesomeIcons.qrcode,
                title: 'QR Exchange',
                description:
                    'Simply show your dynamic QR code to share your business card instantly.',
                width: cardWidth,
              ),
              _featureCard(
                icon: Icons.lock_outline,
                title: 'Privacy First',
                description:
                    'Your data lives in your own Google Drive. No centralized data harvesting.',
                width: cardWidth,
              ),
              _featureCard(
                icon: Icons.offline_bolt_outlined,
                title: 'Works Offline',
                description:
                    'Access and share your card even without an internet connection.',
                width: cardWidth,
              ),
              _featureCard(
                icon: Icons.verified,
                title: 'Verified Identity',
                description:
                    'Build trust with email and phone verification signals on your profile.',
                width: cardWidth,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _featureCard({
    required IconData icon,
    required String title,
    required String description,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FaIcon(icon, color: const Color(0xFF38BDF8), size: 28),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: const Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadSection(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 96, horizontal: 24),
      child: Column(
        children: [
          Text(
            "Experience Secure & Fast\nBusiness Card Exchange",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: isDesktop ? 48 : 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 48),
          _buildStoreButtons(context, isDesktop),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Column(
        children: [
          Text(
            '© ${DateTime.now().year} SecBizCard. All rights reserved.',
            style: GoogleFonts.inter(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FooterLink(
                text: 'Privacy Policy',
                onTap: () =>
                    launchUrl(Uri.parse('https://ixo.app/privacy.html')),
              ),
              Text(
                ' • ',
                style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 12),
              ),
              _FooterLink(
                text: 'EULA',
                onTap: () => launchUrl(Uri.parse('https://ixo.app/eula.html')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _FooterLink({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: const Color(0xFF38BDF8), // Light Blue
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
