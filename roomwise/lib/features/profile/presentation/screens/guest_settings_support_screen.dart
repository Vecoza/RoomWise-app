import 'package:flutter/material.dart';

class GuestSettingsSupportScreen extends StatelessWidget {
  const GuestSettingsSupportScreen({super.key});

  static const _supportEmail = 'support@roomwise.app'; // change to your email

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support & FAQ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Frequently asked questions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          _FaqItem(
            question: 'How do I change or cancel my reservation?',
            answer:
                'You can manage your stays from the Bookings tab. Tap on a reservation to view details and see the available options.',
          ),
          _FaqItem(
            question: 'Where can I see my loyalty points?',
            answer:
                'Your current point balance is visible in the Profile section under “Loyalty points”.',
          ),
          _FaqItem(
            question: 'What payment methods are supported?',
            answer:
                'You can usually pay by card via Stripe. Availability of other methods depends on the hotel and your country.',
          ),
          _FaqItem(
            question: 'I found an issue with my booking. What should I do?',
            answer:
                'If something looks wrong, please contact our support team with your booking reference so we can help as soon as possible.',
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          const Text(
            'Contact support',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'If you cannot find the answer here, feel free to contact us:',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.email_outlined),
              const SizedBox(width: 8),
              Text(
                _supportEmail,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        question,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            answer,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
