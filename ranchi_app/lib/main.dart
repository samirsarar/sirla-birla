import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Replace with your actual Mapbox Public Token
  MapboxOptions.setAccessToken("YOUR_MAPBOX_PUBLIC_TOKEN");
  runApp(const RanchiPlannerApp());
}

class RanchiPlannerApp extends StatelessWidget {
  const RanchiPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ranchi Smart Planner',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? mapboxMap;
  CircleAnnotationManager? circleAnnotationManager;
  
  // Stores our Point A, Point C, and Point B
  List<Position> routePoints = []; 
  String statusText = "Tap the map to set Origin (Point A)";

  // Calls our Node.js Backend (We will update this to send actual coordinates next)
  Future<void> fetchRoutes() async {
    if (routePoints.length < 2) {
      setState(() => statusText = "Need at least Origin and Destination!");
      return;
    }
    
    // Using dummy distance for now, we'll connect the real math later
    final response = await http.post(
      Uri.parse('http://10.0.2.2:3000/api/calculate-routes'), 
      headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({
        'distanceKm': 5, 
        'weights': {'time': 0.5, 'cost': 0.4, 'pollution': 0.1}
      }),
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      setState(() {
        statusText = "Best: ${data['recommended']['name']} | "
            "₹${data['recommended']['cost'].toStringAsFixed(0)} | "
            "${data['recommended']['time'].toStringAsFixed(0)} mins";
      });
    } else {
      setState(() { statusText = "Server Error"; });
    }
  }

  _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    // Initialize the manager that lets us draw circles (pins)
    circleAnnotationManager = await mapboxMap.annotations.createCircleAnnotationManager();
  }

  // Handle User Tapping the Map
  void _onMapTap(MapContentGestureContext context) {
    if (routePoints.length >= 3) {
      // If we already have 3 points, clear the map to start over
      routePoints.clear();
      circleAnnotationManager?.deleteAll();
      setState(() => statusText = "Tap the map to set Origin (Point A)");
      return;
    }

    final position = context.point.coordinates;
    routePoints.add(position);

    // Draw a colored dot on the map where they tapped
    int color = routePoints.length == 1 ? Colors.green.value : // Origin (Green)
                routePoints.length == 2 ? Colors.red.value :   // Destination (Red)
                Colors.orange.value;                           // Waypoint (Orange)

    circleAnnotationManager?.create(CircleAnnotationOptions(
      geometry: Point(coordinates: position),
      circleColor: color,
      circleRadius: 8.0,
    ));

    // Update UI instructions
    setState(() {
      if (routePoints.length == 1) statusText = "Origin set. Tap for Destination (Point B)";
      if (routePoints.length == 2) statusText = "Destination set. Tap for Waypoint (Point C) or hit Find Route";
      if (routePoints.length == 3) statusText = "Waypoint set. Ready to calculate!";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ranchi Trip Planner')),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapWidget"),
            onMapCreated: _onMapCreated,
            onTapListener: _onMapTap, // Listen for taps
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(85.3096, 23.3441)), // Ranchi
              zoom: 12.0,
            ),
          ),
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(statusText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: fetchRoutes,
                    child: const Text("Find Best Route"),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}