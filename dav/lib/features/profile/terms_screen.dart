import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Terms of Service Screen
// ─────────────────────────────────────────────────────────────────────────────
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Terms of Service',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.description_rounded, color: Colors.white, size: 26),
                    SizedBox(width: 10),
                    Text(
                      'Terms of Service',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'DigiPress — PG Department of Computer Science',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                SizedBox(height: 4),
                Text(
                  'Last updated: April 2026',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Friendly intro ───────────────────────────────────────────
          _TermsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('👋', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text(
                      'Welcome to DigiPress!',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'These Terms of Service describe how you can use the DigiPress app. We have kept them short and simple. By using the app, you agree to these terms. Don\'t worry — we are here to help you access academic content, not to create unnecessary rules.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          _TermsSection(
            number: '1',
            emoji: '📱',
            title: 'Who can use DigiPress?',
            body:
                'DigiPress is designed for students, faculty, and staff affiliated with our institution. You must create an account with a valid email address to access publications. Anyone can browse the app, but downloading and reading PDFs requires you to be logged in.',
          ),

          _TermsSection(
            number: '2',
            emoji: '📄',
            title: 'What you can do',
            body:
                'You are welcome to:\n\n• Read and download publications for personal academic use.\n• Bookmark PDFs to track your reading progress.\n• Share publication links with fellow students and colleagues.\n• Use the notification feature to stay updated on new uploads.',
          ),

          _TermsSection(
            number: '3',
            emoji: '🚫',
            title: 'What you should not do',
            body:
                'To keep DigiPress a great experience for everyone, please avoid:\n\n• Sharing your account credentials with others.\n• Using the app for any commercial purpose or profit.\n• Reproducing or distributing downloaded content beyond personal academic use.\n• Attempting to disrupt the app or its services in any way.',
          ),

          _TermsSection(
            number: '4',
            emoji: '🔒',
            title: 'Your account and privacy',
            body:
                'Your account information (name, email) is used solely for the purpose of providing access to the app. We do not sell your data to any third party. Your device notification token is stored only to deliver relevant academic content alerts to you.',
          ),

          _TermsSection(
            number: '5',
            emoji: '📚',
            title: 'Content on DigiPress',
            body:
                'All publications on DigiPress — including magazines, notices, syllabi, and research papers — are the intellectual property of the respective authors, departments, or institution. Unauthorized reproduction of this content outside the app is not permitted.',
          ),

          _TermsSection(
            number: '6',
            emoji: '🔧',
            title: 'App availability',
            body:
                'We work hard to keep DigiPress available at all times, but like any digital service, occasional maintenance or downtime may occur. We appreciate your patience during such periods. We are constantly working to improve your experience.',
          ),

          _TermsSection(
            number: '7',
            emoji: '✏️',
            title: 'Changes to these terms',
            body:
                'If we ever update these terms, we will notify you through the app. Continued use of DigiPress after a change means you accept the updated terms. We promise to keep any changes fair and transparent.',
          ),

          _TermsSection(
            number: '8',
            emoji: '📬',
            title: 'Questions?',
            body:
                'If you have any questions about these terms, please contact our IIC Convenor, Dr. Rajeev Puri, at the PG Department of Computer Science. You can also visit the Help Center inside the app for more information.',
            isLast: true,
          ),

          // ── Footer ───────────────────────────────────────────────────
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'These terms are designed to be fair and protect both you and the institution. Thank you for using DigiPress responsibly!',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _TermsCard extends StatelessWidget {
  final Widget child;
  const _TermsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String number;
  final String emoji;
  final String title;
  final String body;
  final bool isLast;

  const _TermsSection({
    required this.number,
    required this.emoji,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TermsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
