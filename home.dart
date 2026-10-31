import 'package:flutter/material.dart';

import '../state.dart';
import 'commute.dart';
import 'find_ride.dart';
import 'my_trips.dart';
import 'post_ride.dart';
import 'profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    // First login: ask for name and gender before anything else.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !app.profileComplete) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const FindRideScreen(),
      const PostRideScreen(),
      const CommuteScreen(),
      const MyTripsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Find'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Offer'),
          NavigationDestination(icon: Icon(Icons.repeat), label: 'Commute'),
          NavigationDestination(icon: Icon(Icons.luggage_outlined), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Me'),
        ],
      ),
    );
  }
}
