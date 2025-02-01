import 'package:flutter/material.dart';
import '../widgets/sections/hero_section.dart';
import '../widgets/sections/courses_section.dart';
import '../widgets/sections/statistics_section.dart';
import '../widgets/sections/features_section.dart';
import '../widgets/sections/testimonials_section.dart';
import '../widgets/sections/contact_section.dart';
import '../widgets/sections/footer_section.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset >= 400 && !_showBackToTop) {
      setState(() => _showBackToTop = true);
    } else if (_scrollController.offset < 400 && _showBackToTop) {
      setState(() => _showBackToTop = false);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeroSection(),
                StatisticsSection(),
                CoursesSection(),
                FeaturesSection(),
                TestimonialsSection(),
                ContactSection(),
                FooterSection(),
              ],
            ),
          ),
          if (_showBackToTop)
            Positioned(
              right: 24,
              bottom: 24,
              child: AnimatedOpacity(
                opacity: _showBackToTop ? 1.0 : 0.0,
                duration: Duration(milliseconds: 200),
                child: FloatingActionButton(
                  onPressed: _scrollToTop,
                  backgroundColor: Color(0xFFFCA311),
                  mini: true,
                  child: Icon(
                    Icons.arrow_upward,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}