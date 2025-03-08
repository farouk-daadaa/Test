import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  _PrivacyPolicyScreenState createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: const Color(0xFFDB2777), // Match your app's theme (consider moving to AppColors)
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle('Introduction'),
          _buildSectionContent(
            'Welcome to The Bridge! We are committed to protecting your privacy and ensuring the security of your personal information. This Privacy Policy explains how we collect, use, disclose, and safeguard your data when you use our app. By accessing or using The Bridge, you agree to the terms outlined in this policy.',
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('Data We Collect'),
          _buildSectionContent(
            'We may collect the following types of data:\n'
                '- **Personal Information**: Name, email address, and username when you register or log in.\n'
                '- **Usage Data**: Information about how you interact with the app, such as courses accessed, progress tracking, and time spent.\n'
                '- **Device Information**: Device type, operating system, and IP address for analytics and security purposes.\n'
                'We only collect data that is necessary to provide and improve our services.',
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('How We Use Your Data'),
          _buildSectionContent(
            'We use your data to:\n'
                '- Provide and personalize your learning experience.\n'
                '- Analyze usage patterns to improve app functionality.\n'
                '- Ensure account security and prevent fraud.\n'
                '- Communicate with you about updates, support, or promotional offers (with your consent).\n'
                'We do not sell your personal information to third parties.',
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('Data Security'),
          _buildSectionContent(
            'We implement industry-standard security measures, including encryption and secure servers, to protect your data from unauthorized access, alteration, or disclosure. However, no online transmission is 100% secure, and we cannot guarantee absolute security.',
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('Your Rights'),
          _buildSectionContent(
            'You have the right to:\n'
                '- Access, update, or delete your personal information.\n'
                '- Opt-out of marketing communications.\n'
                '- Request data portability or file a complaint with a data protection authority.\n'
                'To exercise these rights, please contact us at Contact@9antra.tn.',
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('Changes to This Policy'),
          _buildSectionContent(
            'We may update this Privacy Policy from time to time to reflect changes in our practices or legal requirements. We will notify you of significant changes by posting the updated policy here or via email. Your continued use of The Bridge after such changes constitutes acceptance of the new policy.\n'
                'Last Updated: March 08, 2025',
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('Contact Us'),
          _buildSectionContent(
            'If you have questions about this Privacy Policy or our data practices, please reach out to us at:\n'
                '- Email: Contact@9antra.tn\n'
                '- Website: https://9antra.tn/contact-us\n'
                'We aim to respond within 24-48 hours.',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFFDB2777), // Match app bar color for consistency
      ),
    );
  }

  Widget _buildSectionContent(String content) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey[800],
          height: 1.5,
        ),
      ),
    );
  }
}