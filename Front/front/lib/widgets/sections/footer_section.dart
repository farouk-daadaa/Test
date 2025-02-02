import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FooterSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      color: Colors.white,
      child: Column(
        children: [
          // Logo
          Image.asset(
            'assets/images/logo.png',
            height: 60,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 32),
          // Navigation Links
          Column(
            children: ['Home', 'About us', 'Our Services', 'Contact']
                .map((link) => Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                ),
                child: Text(
                  link,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ))
                .toList(),
          ),
          SizedBox(height: 32),
          // Social Media Icons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialIcon(FontAwesomeIcons.facebook),
                _buildSocialIcon(FontAwesomeIcons.instagram),
                _buildSocialIcon(FontAwesomeIcons.twitter),
                _buildSocialIcon(FontAwesomeIcons.youtube),
                _buildSocialIcon(FontAwesomeIcons.phone),
                _buildSocialIcon(FontAwesomeIcons.envelope),
              ],
            ),
          ),
          SizedBox(height: 32),
          // Copyright Text
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Copyright © 2025 All Rights Reserved by LetsCloneIt.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 6), // Reduced margin
      width: 36, // Slightly smaller size
      height: 36, // Slightly smaller size
      decoration: BoxDecoration(
        color: Color(0xFFFCA311),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: FaIcon(
          icon,
          size: 16, // Smaller icon size
          color: Colors.white,
        ),
        onPressed: () {},
        padding: EdgeInsets.zero,
      ),
    );
  }
}