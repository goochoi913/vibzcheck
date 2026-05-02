import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../insights/insights_screen.dart';
import '../playlist/playlist_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  static _MainNavigationState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<_MainNavigationState>();
  }

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    PlaylistScreen(),
    ChatScreen(),
    InsightsScreen(),
    ProfileScreen(),
  ];

  void switchToTab(int index) {
    if (index < 0 || index >= _screens.length) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            label: 'Playlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
