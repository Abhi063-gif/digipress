import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Help Center Screen
// ─────────────────────────────────────────────────────────────────────────────
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final List<Map<String, String>> _faqs = [
    {
      'q': 'What is DigiPress?',
      'a':
          'DigiPress is a digital library application developed by the PG Department of Computer Science. It allows students and faculty to access and read academic publications such as magazines, notices, prospectuses, research papers, and syllabi — all in one place.',
    },
    {
      'q': 'How do I read a PDF publication?',
      'a':
          'Simply tap any publication card on the Home screen. The in-app PDF viewer will open automatically, allowing you to read, scroll, zoom, and even bookmark your progress for later.',
    },
    {
      'q': 'How do I get notified about new uploads?',
      'a':
          'DigiPress sends you automatic push notifications whenever an admin uploads a new publication. Make sure you allow notification permissions when prompted. You can also check the Notifications tab inside the app to see all recent uploads.',
    },
    {
      'q': 'Can I download a PDF to read offline?',
      'a':
          'Yes! While viewing any PDF, tap the Download button at the bottom of the reader. The file will be saved to your device\'s Documents folder so you can access it even without an internet connection.',
    },
    {
      'q': 'Can I share a publication with others?',
      'a':
          'Absolutely. While reading a PDF, tap the Share button at the bottom of the viewer. You can share the document link via WhatsApp, email, or any other app. If the recipient has DigiPress installed, the link will open the PDF directly inside the app.',
    },
    {
      'q': 'I forgot my password. How can I reset it?',
      'a':
          'On the Login screen, tap "Forgot Password?". Enter your registered email address and we will send you a One-Time Password (OTP). Use this OTP to verify your identity and set a new password.',
    },
    {
      'q': 'Who can upload publications to DigiPress?',
      'a':
          'Only verified administrators can upload new content. If you are a faculty member and need admin access, please contact the IIC Convenor of the PG Department of Computer Science.',
    },
  ];

  final Set<int> _expanded = {};

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
          'Help Center',
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
          // ── Header banner ─────────────────────────────────────────────
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.help_rounded,
                      size: 28, color: Colors.white),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Frequently Asked Questions',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Find quick answers to common questions about DigiPress.',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── FAQ list ──────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: List.generate(_faqs.length, (i) {
                final isLast = i == _faqs.length - 1;
                final isOpen = _expanded.contains(i);
                return Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() {
                        if (isOpen) {
                          _expanded.remove(i);
                        } else {
                          _expanded.add(i);
                        }
                      }),
                      borderRadius: BorderRadius.vertical(
                        top: i == 0 ? const Radius.circular(16) : Radius.zero,
                        bottom: isLast && !isOpen
                            ? const Radius.circular(16)
                            : Radius.zero,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                color: isOpen
                                    ? AppColors.primary
                                    : AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isOpen
                                        ? Colors.white
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _faqs[i]['q']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isOpen
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            AnimatedRotation(
                              turns: isOpen ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 22, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: Padding(
                        padding: const EdgeInsets.fromLTRB(54, 0, 16, 16),
                        child: Text(
                          _faqs[i]['a']!,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                      crossFadeState: isOpen
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                    if (!isLast)
                      const Divider(height: 1, indent: 16, color: AppColors.border),
                  ],
                );
              }),
            ),
          ),

          const SizedBox(height: 20),

          // ── Contact box ───────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.support_agent_rounded,
                            size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Still need help? Contact us',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'For any queries, technical issues, or assistance related to DigiPress, please reach out to:',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ContactRow(
                        icon: Icons.person_rounded,
                        label: 'Contact Person',
                        value: 'Dr. Rajeev Puri',
                        bold: true,
                      ),
                      const SizedBox(height: 8),
                      _ContactRow(
                        icon: Icons.workspace_premium_rounded,
                        label: 'Designation',
                        value: 'IIC Convenor',
                      ),
                      const SizedBox(height: 8),
                      _ContactRow(
                        icon: Icons.school_rounded,
                        label: 'Department',
                        value: 'PG Department of Computer Science',
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 16, color: Color(0xFFD97706)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Please mention "DigiPress App" when reaching out for faster assistance.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF92400E),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool bold;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
              children: [
                TextSpan(text: '$label: '),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.w600,
                    color: bold ? AppColors.textPrimary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
