import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  runApp(const RouteBakeryTrackerApp());
}

class RouteBakeryTrackerApp extends StatelessWidget {
  const RouteBakeryTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSD Route & Profit Master',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: const CardTheme(color: Color(0xFF1E1E1E)),
      ),
      home: const RouteDashboardPage(),
    );
  }
}

class RouteDashboardPage extends StatefulWidget {
  const RouteDashboardPage({Key? key}) : super(key: key);

  @override
  State<RouteDashboardPage> createState() => _RouteDashboardPageState();
}

enum ShiftState { offShift, onDuty, offDuty }

class _RouteDashboardPageState extends State<RouteDashboardPage> {
  ShiftState _currentShiftState = ShiftState.offShift;
  final Stopwatch _shiftStopwatch = Stopwatch();
  Timer? _shiftTimer;
  double _trackedGpsMiles = 0.0;
  double _totalGasCosts = 0.0;
  double _calculatedFuelCpm = 0.0;

  double _adjustableStaleLimit = 6.0; 
  double _currentRouteSalesVolume = 10000.0; 
  double _currentRouteStaleLoss = 450.0; 

  final String _currentFiscalPeriod = "Period 10 (2026)";
  final bool _isCurrentPeriodVerified = false; 
  final List<Map<String, String>> _historicalSbtLogs = [
    {"period": "P09", "store": "Giant Foods #6529", "date": "2026-09-24", "status": "Verified"},
    {"period": "P09", "store": "Weis Market #0225", "date": "2026-09-25", "status": "Verified"},
    {"period": "P08", "store": "Giant Foods #6529", "date": "2026-08-20", "status": "Verified"},
  ];

  String _selectedEmergencyStore = 'Giant Foods #6529';
  
  final List<Map<String, dynamic>> _tastykakeInventoryItems = [
    {"name": "TK SS Baked Pies", "qty": 0, "type": "SS"},
    {"name": "TK SS Glazed Pies", "qty": 0, "type": "SS"},
    {"name": "TK SS Cake - Cupcake", "qty": 0, "type": "SS"},
    {"name": "TK SS Cake - Snowball", "qty": 0, "type": "SS"},
    {"name": "TK SS Honey Bun", "qty": 0, "type": "SS"},
    {"name": "TK SS Bars", "qty": 0, "type": "SS"},
    {"name": "TK FP 5 Ct Minis", "qty": 0, "type": "FP"},
    {"name": "TK Bagged Donuts", "qty": 0, "type": "FP"},
    {"name": "TK MS 6Ct Sweet Rolls", "qty": 0, "type": "FP"},
  ];

  Timer? _clearHoldTimer;
  double _clearHoldProgress = 0.0;
  @override
  void dispose() {
    _shiftTimer?.cancel();
    _clearHoldTimer?.cancel();
    super.dispose();
  }

  void _toggleShiftState(ShiftState newState) {
    setState(() {
      _currentShiftState = newState;
      if (newState == ShiftState.onDuty) {
        _shiftStopwatch.start();
        _shiftTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() { _trackedGpsMiles += 0.02; }); 
        });
      } else if (newState == ShiftState.offDuty) {
        _shiftStopwatch.stop();
        _shiftTimer?.cancel();
      } else {
        _shiftStopwatch.stop();
        _shiftStopwatch.reset();
        _shiftTimer?.cancel();
      }
    });
  }

  void _calculateFuelCpmMetrics(String val) {
    double gasInput = double.tryParse(val) ?? 0.0;
    if (gasInput > 0 && _trackedGpsMiles > 0) {
      setState(() {
        _totalGasCosts = gasInput;
        _calculatedFuelCpm = _totalGasCosts / _trackedGpsMiles;
      });
    }
  }

  void _startClearCacheHoldTimeout() {
    _clearHoldProgress = 0.0;
    _clearHoldTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _clearHoldProgress += 0.0333; 
        if (_clearHoldProgress >= 1.0) {
          _clearHoldTimer?.cancel();
          _clearHoldProgress = 0.0;
          for (var item in _tastykakeInventoryItems) { item["qty"] = 0; }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Handheld Backup Cache Securely Cleared & Sync Approved')),
          );
        }
      });
    });
  }

  void _cancelClearCacheHoldTimeout() {
    _clearHoldTimer?.cancel();
    setState(() { _clearHoldProgress = 0.0; });
  }
  @override
  Widget build(BuildContext context) {
    double currentStalePercent = (_currentRouteStaleLoss / _currentRouteSalesVolume) * 100;
    bool isOverStaleCap = currentStalePercent > _adjustableStaleLimit;

    return Scaffold(
      appBar: AppBar(title: const Text('DSD Route Execution Hub')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(
                    color: _currentShiftState == ShiftState.onDuty ? Colors.green :
                           _currentShiftState == ShiftState.offDuty ? Colors.orange : Colors.grey,
                    width: 6,
                  )),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _currentShiftState == ShiftState.onDuty ? 'STATUS: ACTIVE ON-ROUTE' :
                          _currentShiftState == ShiftState.offDuty ? 'STATUS: OFF-DUTY BREAK' : 'STATUS: SHIFT CLOSED',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text('GPS Miles: ${_trackedGpsMiles.toStringAsFixed(1)} mi', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: ElevatedButton(onPressed: () => _toggleShiftState(ShiftState.onDuty), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Start Shift'))),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton(onPressed: () => _toggleShiftState(ShiftState.offDuty), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text('Go Off-Duty'))),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton(onPressed: () => _toggleShiftState(ShiftState.offShift), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey), child: const Text('End Shift'))),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('🔒 Handheld Emergency Backup (Tastykake Only)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedEmergencyStore,
                        items: ['Giant Foods #6529', 'Weis Market #0225', 'Karns Quality Foods'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) => setState(() => _selectedEmergencyStore = val!),
                        decoration: const InputDecoration(labelText: 'Target Account Sourcing Location'),
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _tastykakeInventoryItems.length,
                        itemBuilder: (context, idx) {
                          final item = _tastykakeInventoryItems[idx];
                          return ListTile(
                            title: Text(item["name"]),
                            subtitle: Text('Category: ${item["type"]}', style: TextStyle(color: item["type"] == "SS" ? Colors.orange : Colors.purple)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.remove_circle), onPressed: () => setState(() { if (item["qty"] > 0) item["qty"]--; })),
                                Text('${item["qty"]}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                IconButton(icon: const Icon(Icons.add_circle), onPressed: () => setState(() { item["qty"]++; })),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTapDown: (_) => _startClearCacheHoldTimeout(),
                        onTapUp: (_) => _cancelClearCacheHoldTimeout(),
                        onTapCancel: () => _cancelClearCacheHoldTimeout(),
                        child: Column(
                          children: [
                            LinearProgressIndicator(value: _clearHoldProgress, color: Colors.redAccent, backgroundColor: Colors.grey),
                            const SizedBox(height: 4),
                            Container(width: double.infinity, padding: const EdgeInsets.all(12), color: Colors.red, child: const Text('HOLD FOR 3 SECONDS TO CLEAR ACCOUNT RECORD', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('📋 SBT Audit Summary (13 Fiscal Terms)', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(padding: const EdgeInsets.all(16), color: _isCurrentPeriodVerified ? Colors.green : Colors.red, width: double.infinity, child: Text(_isCurrentPeriodVerified ? '✅ Verified: Active Term $_currentFiscalPeriod is compliant.' : '🚨 ACTION REQUIRED: No statement audit logged for $_currentFiscalPeriod. 2 Days remaining!', style: const TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(height: 8),
                      DropdownButton<String>(hint: const Text('Select Prior Fiscal Operating Terms'), isExpanded: true, items: _historicalSbtLogs.map((log) => DropdownMenuItem(value: log["period"], child: Text('${log["period"]} - ${log["store"]} (${log["date"]}) ──► ${log["status"]}'))).toList(), onChanged: (val) {}),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('📢 EVENT REPLENISHMENT DEADLINES', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    SizedBox(height: 8),
                    Text('• Upcoming Sale Event: Tastykake \$2.88 Family Pack Hot Buy (Starts 12/03/2026)'),
                    Padding(padding: EdgeInsets.only(left: 12.0, top: 4.0), child: Text('──► Sister Plant Cutoff: Thursday, Nov 19 (14 Days Early Required)', style: TextStyle(color: Colors.amber))),
                    Padding(padding: EdgeInsets.only(left: 12.0, top: 2.0), child: Text('──► Navy Yard Cutoff: Thursday, Nov 26 (7 Days Early Required)', style: TextStyle(color: Colors.orangeAccent))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Route Stale Credit Ceiling', style: TextStyle(fontWeight: FontWeight.bold)), Text('${_adjustableStaleLimit.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent))]),
                    Slider(value: _adjustableStaleLimit, min: 0.0, max: 10.0, divisions: 20, label: '${_adjustableStaleLimit.toStringAsFixed(1)}%', onChanged: (val) => setState(() => _adjustableStaleLimit = val)),
                    Container(padding: const EdgeInsets.all(12), color: isOverStaleCap ? Colors.red : Colors.green, child: Text(isOverStaleCap ? '🚨 WARNING: Route Stales (${currentStalePercent.toStringAsFixed(1)}%) exceed allowance. Owed Out-of-Pocket!' : '✅ Route Stales (${currentStalePercent.toStringAsFixed(1)}%) are within the protected credit ceiling.', style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.grey),
            const Text('⚙️ BACK-OFFICE OPERATIONS MANAGEMENT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              children: [
          ],
        ),
      ),
    );
  }
}
