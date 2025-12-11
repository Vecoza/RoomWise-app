import 'package:flutter/material.dart';

class GuestSettingsSupportScreen extends StatelessWidget {
  const GuestSettingsSupportScreen({super.key});

  static const _supportEmail = 'support@roomwise.app';

  // Design tokens – keep in sync with GuestSettingsScreen
  static const _primaryGreen = Color(0xFF05A87A);
  static const _bgColor = Color(0xFFF3F4F6);
  static const _cardColor = Colors.white;
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const double _cardRadius = 18;
  static const double _cardPadding = 16;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('Support & FAQ'),
        backgroundColor: _bgColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      _buildFaqCard(),
                      const SizedBox(height: 16),
                      _buildContactCard(context),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ----- CARDS -----

  Widget _buildHeaderCard() {
    return _supportCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFE0F9F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent, color: _primaryGreen),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How can we help?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Browse common questions or reach out to our support team if something is unclear.',
                  style: TextStyle(fontSize: 13, color: _textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqCard() {
    return _supportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Frequently asked questions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tap a question to see more details.',
            style: TextStyle(fontSize: 12, color: _textMuted),
          ),
          SizedBox(height: 12),

          // FAQ items
          _FaqItem(
            question: 'How do I change or cancel my reservation?',
            answer:
                'You can manage your stays from the Bookings tab. Tap on a reservation to view details and see the available options.',
          ),
          _FaqDivider(),
          _FaqItem(
            question: 'Where can I see my loyalty points?',
            answer:
                'Your current point balance is visible in the Profile section under “Loyalty points”.',
          ),
          _FaqDivider(),
          _FaqItem(
            question: 'What payment methods are supported?',
            answer:
                'You can usually pay by card via Stripe. Availability of other methods depends on the hotel and your country.',
          ),
          _FaqDivider(),
          _FaqItem(
            question: 'I found an issue with my booking. What should I do?',
            answer:
                'If something looks wrong, please contact our support team with your booking reference so we can help as soon as possible.',
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return _supportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact support',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Didn’t find what you were looking for? Reach out and we’ll get back to you as soon as possible.',
            style: TextStyle(fontSize: 12, color: _textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.email_outlined, color: _primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _supportEmail,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _primaryGreen,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // SizedBox(
          //   width: double.infinity,
          //   height: 44,
          //   child: OutlinedButton(
          //     style: OutlinedButton.styleFrom(
          //       side: const BorderSide(color: _primaryGreen),
          //       foregroundColor: _primaryGreen,
          //       shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(14),
          //       ),
          //     ),
          //     onPressed: () {
          //       // Here you could plug url_launcher to open mail client.
          //       ScaffoldMessenger.of(context).showSnackBar(
          //         const SnackBar(
          //           content: Text('Open your email app to contact support.'),
          //         ),
          //       );
          //     },
          //     child: const Text(
          //       'Email support',
          //       style: TextStyle(fontWeight: FontWeight.w600),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  // ----- SHARED CARD HELPER -----

  Widget _supportCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(_cardPadding),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ----- FAQ ITEM + DIVIDER -----

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    const textPrimary = GuestSettingsSupportScreen._textPrimary;
    const textMuted = GuestSettingsSupportScreen._textMuted;

    return Theme(
      // Remove default ExpansionTile divider color
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        iconColor: textMuted,
        collapsedIconColor: textMuted,
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 13,
                color: textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqDivider extends StatelessWidget {
  const _FaqDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Divider(height: 1, color: Color(0xFFE5E7EB)),
    );
  }
}
