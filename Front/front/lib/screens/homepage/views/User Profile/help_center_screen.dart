import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({Key? key}) : super(key: key);

  @override
  _HelpCenterScreenState createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<bool> _expandedFaq = List.generate(7, (_) => false);
  bool _isLaunching = false; // Track loading state for URL launch
  final Color primaryColor = const Color(0xFFDB2777);

  final List<Map<String, String>> faqItems = [
    {
      'question': 'Can I access my courses offline?',
      'answer': 'Yes, you can download course materials and access them offline. This is great for learning on the go, especially when you don\'t have an internet connection.'
    },
    {
      'question': 'How do I enroll in a course?',
      'answer': 'Simply browse our course catalog, select your desired course, and click the "Enroll" button. Follow the payment process if it\'s a paid course, and you\'ll get immediate access.'
    },
    {
      'question': 'Is there a way to track my progress?',
      'answer': 'Yes, our platform provides detailed progress tracking. You can see completed lessons, quiz scores, and overall course progress in your dashboard.'
    },
    {
      'question': 'How do I reach out for help or support?',
      'answer': 'You can contact us through various channels including WhatsApp, email, or our social media platforms. We typically respond within 24 hours.'
    },
    {
      'question': 'Is my data safe and secure?',
      'answer': 'Yes, we take data security seriously. We use encryption and follow best practices to protect your personal information and learning data.'
    },
    {
      'question': 'Do you offer a certificate?',
      'answer': 'Yes, upon successful completion of a course, you\'ll receive a verified digital certificate that you can share on your professional networks.'
    },
    {
      'question': 'Are there any subscriptions?',
      'answer': 'We offer both individual course purchases and subscription plans. Check our pricing page for detailed information about available options.'
    },
  ];

  final List<Map<String, dynamic>> contactItems = [
    {
      'title': 'WhatsApp',
      'value': '+21658840064',
      'icon': FontAwesomeIcons.whatsapp,
      'color': const Color(0xFF25D366),
      'url': 'https://wa.me/21658840064'
    },
    {
      'title': 'Website',
      'value': '9antra.tn/contact-us',
      'icon': Icons.language,
      'color': const Color(0xFF2196F3),
      'url': 'https://9antra.tn/contact-us'
    },
    {
      'title': 'Facebook',
      'value': '9antra.tn',
      'icon': Icons.facebook,
      'color': const Color(0xFF1877F2),
      'url': 'https://www.facebook.com/9antra.tn'
    },
    {
      'title': 'Instagram',
      'value': '9antra.tn_the_bridge',
      'icon': Icons.camera_alt,
      'color': const Color(0xFFE4405F),
      'url': 'https://www.instagram.com/9antra.tn_the_bridge/'
    },
    {
      'title': 'TikTok',
      'value': '9antra.tn',
      'icon': Icons.music_note,
      'color': Colors.black,
      'url': 'https://www.tiktok.com/@9antra.tn'
    },
    {
      'title': 'YouTube',
      'value': '9antra.tn_the_bridge',
      'icon': Icons.play_circle_fill,
      'color': const Color(0xFFFF0000),
      'url': 'https://www.youtube.com/@9antra.tn_the_bridge'
    },
    {
      'title': 'Email',
      'value': 'Contact@9antra.tn',
      'icon': Icons.email,
      'color': const Color(0xFF757575),
      'url': 'mailto:Contact@9antra.tn?subject=Support Request'
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    setState(() {
      _isLaunching = true;
    });

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch $url'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching URL: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (context.mounted) {
        setState(() {
          _isLaunching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Help Center',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: primaryColor,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  text: 'FAQ',
                  icon: Icon(Icons.question_answer_outlined),
                ),
                Tab(
                  text: 'Contact Us',
                  icon: Icon(Icons.contact_support_outlined),
                ),
              ],
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // FAQ Tab
                      _buildFaqTab(),
                      // Contact Us Tab
                      _buildContactTab(),
                    ],
                  ),
                ),
                if (_isLaunching)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
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

  Widget _buildFaqTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: faqItems.length + 1, // +1 for the header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSectionHeader(
            'Frequently Asked Questions',
            'Find answers to common questions about our platform.',
            Icons.lightbulb_outline,
          );
        }

        final itemIndex = index - 1;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              colorScheme: ColorScheme.light(
                primary: primaryColor,
              ),
            ),
            child: ExpansionTile(
              title: Text(
                faqItems[itemIndex]['question']!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: CircleAvatar(
                backgroundColor: primaryColor.withOpacity(0.1),
                child: Icon(
                  Icons.help_outline,
                  color: primaryColor,
                ),
              ),
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  faqItems[itemIndex]['answer']!,
                  style: TextStyle(
                    color: Colors.grey[700],
                    height: 1.5,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contactItems.length + 1, // +1 for the header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSectionHeader(
            'Contact Us',
            'Reach out to us through any of these channels for support.',
            Icons.contact_support_outlined,
          );
        }

        final itemIndex = index - 1;
        final item = contactItems[itemIndex];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isLaunching ? null : () => _launchUrl(item['url']),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: item['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item['icon'],
                      color: item['color'],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['value'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

