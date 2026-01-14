import "package:flutter/material.dart";

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Theme Options"),
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: const Center(
        child: Text(
          "Theme Screen - Work in Progress",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
