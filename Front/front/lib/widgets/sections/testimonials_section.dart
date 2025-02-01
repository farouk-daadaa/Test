import 'package:flutter/material.dart';

class TestimonialsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'What Our Students Say',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTestimonialCard(
                  context,
                  'The Bridge has been instrumental in my career transition. The courses are well-structured and the mentors are extremely helpful.',
                  'John Doe',
                  'Web Developer',
                ),
                SizedBox(width: 16),
                _buildTestimonialCard(
                  context,
                  'I learned iOS development from scratch with The Bridge. The hands-on projects really helped me understand complex concepts.',
                  'Jane Smith',
                  'Mobile App Developer',
                ),
                SizedBox(width: 16),
                _buildTestimonialCard(
                  context,
                  'The Python courses at The Bridge are top-notch. I was able to land a job as a data scientist thanks to the skills I learned here.',
                  'Mike Johnson',
                  'Data Scientist',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialCard(BuildContext context, String text, String name, String role) {
    return Container(
      width: 300,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, size: 40, color: Theme.of(context).primaryColor),
          SizedBox(height: 16),
          Text(text, style: Theme.of(context).textTheme.bodyLarge),
          SizedBox(height: 16),
          Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
          Text(role, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

