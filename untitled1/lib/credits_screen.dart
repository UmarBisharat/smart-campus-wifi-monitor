import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Credits',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // TEAM ICON
                Container(
                  height: 90,
                  width: 90,
                  decoration: BoxDecoration(
                    color: colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    size: 50,
                    color: colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 25),

                // TITLE
                Text(
                  'Our Team',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Made with passion by',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),

                const SizedBox(height: 20),

                // ANIMATED NAMES
                SizedBox(
                  height: 50,
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    child: AnimatedTextKit(
                      repeatForever: true,
                      pause: const Duration(milliseconds: 1000),
                      animatedTexts: [
                        RotateAnimatedText('UMAR'),
                        RotateAnimatedText('HAYA'),
                        RotateAnimatedText('SHUMAIL'),
                        RotateAnimatedText('SABRA'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // TEAM CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Team Zero',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Hackathon Team',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),

                      const SizedBox(height: 18),

                      const Divider(),

                      const SizedBox(height: 10),

                      _teamMember('Umar', colorScheme),
                      _teamMember('Haya', colorScheme),
                      _teamMember('Shumail', colorScheme),
                      _teamMember('Sabra', colorScheme),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  'Thank you for using our app ❤️',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _teamMember(String name, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.person_outline, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            name,
            style: TextStyle(
              fontSize: 15,
              // onSecondary, not onSurface: this card's background is
              // colorScheme.secondary, so the text needs the color
              // meant to contrast with that, not the page's onSurface.
              color: colorScheme.onSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}