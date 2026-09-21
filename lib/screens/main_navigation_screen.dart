import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'services_screen.dart';
import 'trips_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final User? user;
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.user,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        user: widget.user,
        onNavigateToProfile: () => _onTabSelected(3),
        onNavigateToTrips: () => _onTabSelected(1),
      ),
      TripsScreen(
        onBookNewRide: () => _onTabSelected(0),
      ),
      ServicesScreen(
        onSelectRideService: (serviceId) {
          _onTabSelected(0);
        },
      ),
      ProfileScreen(
        user: widget.user,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: ZyroBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
