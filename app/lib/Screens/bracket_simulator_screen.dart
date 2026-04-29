import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Providers/api_service.dart';

class BracketSimulatorScreen extends ConsumerStatefulWidget {
  const BracketSimulatorScreen({super.key});

  @override
  ConsumerState<BracketSimulatorScreen> createState() => _BracketSimulatorScreenState();
}

class _BracketSimulatorScreenState extends ConsumerState<BracketSimulatorScreen> {
  bool _isLoading = false;
  List<MapEntry<String, dynamic>> _results = [];
  
  // Mock 64 teams (Abilene Christian, Air Force, Akron, Alabama, etc.)
  final List<int> _mock64Teams = [
    2000, 2005, 2006, 2010, 333, 2011, 2016, 44, 2026, 9, 12, 8, 2032, 2029, 
    349, 2, 2046, 252, 2050, 239, 91, 2057, 2065, 2066, 68, 103, 104, 189, 71, 
    225, 2803, 2083, 2084, 2086, 13, 2934, 2239, 2463, 2856, 25, 2097, 2099, 
    2110, 2115, 2117, 232, 2127, 2429, 236, 2130, 2132, 228, 325, 324, 2142, 
    38, 36, 171, 2154, 172, 156, 159, 2166, 2168
  ];

  Future<void> _simulate() async {
    setState(() {
      _isLoading = true;
      _results = [];
    });

    final api = ref.read(apiServiceProvider);
    final response = await api.simulateBracket(_mock64Teams, iterations: 1000);

    if (response != null && response['results'] != null) {
      final Map<String, dynamic> rawResults = response['results'];
      
      // Sort by likelihood to win championship ("W")
      final sortedEntries = rawResults.entries.toList()
        ..sort((a, b) => (b.value['W'] as num).compareTo(a.value['W'] as num));

      setState(() {
        _results = sortedEntries;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Simulation failed. Please try again.')),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('March Madness Simulator', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)], // Deep blue to bright blue
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _simulate,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sports_basketball, size: 28, color: Colors.white),
                            SizedBox(width: 12),
                            Text(
                              'SIMULATE 10,000 ITERATIONS',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            
            if (_results.isEmpty && !_isLoading)
              const Expanded(
                child: Center(
                  child: Text(
                    'Tap to simulate the 64-team bracket using our Monte Carlo CBB AI.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ),

            if (_results.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '🏆 Most Likely Champions',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final entry = _results[index];
                    final teamId = entry.key;
                    final probs = entry.value;
                    
                    final winPct = ((probs['W'] as num) * 100).toStringAsFixed(1);
                    final f4Pct = ((probs['F4'] as num) * 100).toStringAsFixed(1);
                    
                    // Add subtle glow to top 3
                    final isTop3 = index < 3;
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: isTop3 ? Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 1.5) : null,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isTop3 ? Colors.amber : Colors.grey[800],
                          child: Text(
                            '#${index + 1}',
                            style: TextStyle(
                              color: isTop3 ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          'Team $teamId', // In a real app, map ID to Team Name
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                        ),
                        subtitle: Text(
                          'Final Four: $f4Pct%',
                          style: TextStyle(color: Colors.blue[300]),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Win %', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            Text(
                              '$winPct%',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.greenAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
