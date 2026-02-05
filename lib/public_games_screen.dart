
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PublicGamesScreen extends StatefulWidget {
  const PublicGamesScreen({super.key});

  @override
  State<PublicGamesScreen> createState() => _PublicGamesScreenState();
}

class _PublicGamesScreenState extends State<PublicGamesScreen> {
  final _firestore = FirebaseFirestore.instance;
  late Future<QuerySnapshot> _gamesFuture;

  @override
  void initState() {
    super.initState();
    // Fetch data once when the widget is created for better performance
    _gamesFuture = _firestore.collection('monthly_data').orderBy('time', descending: true).get();
  }

  void _refreshData() {
    setState(() {
      _gamesFuture = _firestore.collection('monthly_data').orderBy('time', descending: true).get();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: _gamesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No game results found.'));
          }

          final docs = snapshot.data!.docs;

          // Using a responsive layout that works well on web and mobile
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200), // Max width for large screens
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 38.0,
                    headingRowColor: WidgetStateProperty.resolveWith<Color?>(
                      (Set<WidgetState> states) {
                        // Using a non-deprecated way to set color with opacity
                        return Theme.of(context).colorScheme.primary.withAlpha(25); // roughly 10% opacity
                      },
                    ),
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Result')),
                      DataColumn(label: Text('Time')),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final timestamp = data['time'] as Timestamp?;
                      final timeString = timestamp != null 
                          ? TimeOfDay.fromDateTime(timestamp.toDate()).format(context)
                          : 'N/A';

                      return DataRow(
                        cells: [
                          DataCell(Text(data['name']?.toString() ?? 'N/A')),
                          DataCell(Text(data['result']?.toString() ?? 'N/A')),
                          DataCell(Text(timeString)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
