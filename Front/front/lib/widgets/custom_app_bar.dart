import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Padding(
        padding: EdgeInsets.only(left: 16),
        child: Image.asset(
          'assets/images/logo.png',
          height: 40,
        ),
      ),
      titleSpacing: 0,
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, size: 28),
            color: Color(0xFFDB2777),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ),
        SizedBox(width: 8),
      ],
    );
  }
}

