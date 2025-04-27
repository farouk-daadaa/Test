import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class AppColors {
  static const Color primary = Color(0xFFDB2777);
  static const Color secondary = Color(0xFFFB923C);
  static const Color textGray = Color(0xFF6B7280);
  static const Color backgroundGray = Color(0xFFF3F4F6);
}

class RouteView extends StatefulWidget {
  final LatLng eventLocation;
  final LatLng userLocation;
  final String googleApiKey;

  const RouteView({
    Key? key,
    required this.eventLocation,
    required this.userLocation,
    required this.googleApiKey,
  }) : super(key: key);

  @override
  _RouteViewState createState() => _RouteViewState();
}

class _RouteViewState extends State<RouteView> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  String? _travelTime;
  String? _travelDistance;
  bool _isLoading = true;
  late PolylinePoints _polylinePoints;
  List<Map<String, dynamic>> _navigationSteps = [];
  bool _isNavigating = false;
  LatLng? _currentUserLocation;
  Stream<Position>? _positionStream;
  String? _currentInstruction;
  double _distanceToNextStep = double.infinity;
  int _currentStepIndex = 0;
  String? _remainingTime;
  String? _remainingDistance;
  bool _isMapManuallyPanned = false;
  double? _currentSpeed;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  double _currentZoom = 15;

  @override
  void initState() {
    super.initState();
    _polylinePoints = PolylinePoints();
    _currentUserLocation = widget.userLocation;
    _remainingTime = "Calculating...";
    _remainingDistance = "Calculating...";
    _fetchRoute();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchRoute({LatLng? origin}) async {
    setState(() {
      _isLoading = true;
      _polylines.clear();
      _navigationSteps.clear();
      _currentStepIndex = 0;
      _currentInstruction = null;
      _distanceToNextStep = double.infinity;
    });

    try {
      final startLocation = origin ?? widget.userLocation;
      final originStr = '${startLocation.latitude},${startLocation.longitude}';
      final destination = '${widget.eventLocation.latitude},${widget.eventLocation.longitude}';
      final url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=$originStr'
          '&destination=$destination'
          '&mode=driving'
          '&key=${widget.googleApiKey}';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          final polylinePoints = route['overview_polyline']['points'];
          final duration = leg['duration']['text'];
          final distance = leg['distance']['text'];
          final steps = leg['steps'] as List<dynamic>;

          List<Map<String, dynamic>> parsedSteps = steps.map((step) {
            String maneuver = step['maneuver'] ?? 'straight';
            return {
              'instruction': _stripHtml(step['html_instructions']),
              'distance': step['distance']['value'],
              'end_location': LatLng(
                step['end_location']['lat'],
                step['end_location']['lng'],
              ),
              'maneuver': maneuver,
            };
          }).toList();

          final List<PointLatLng> decodedPointsResult = _polylinePoints.decodePolyline(polylinePoints);
          final List<LatLng> decodedPoints = decodedPointsResult
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          setState(() {
            _polylines.add(
              Polyline(
                polylineId: PolylineId('route'),
                points: decodedPoints,
                color: AppColors.primary,
                width: 6,
              ),
            );
            _travelTime = duration;
            _travelDistance = distance;
            _remainingTime = duration;
            _remainingDistance = distance;
            _navigationSteps = parsedSteps;
            _isLoading = false;
            if (_navigationSteps.isNotEmpty) {
              _currentInstruction = _navigationSteps[0]['instruction'];
              _distanceToNextStep = _navigationSteps[0]['distance'].toDouble();
              _animationController.forward();
            }
          });

          if (!_isNavigating) {
            final bounds = _computeBounds(decodedPoints);
            _mapController?.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 50),
            );
          }
        } else {
          throw Exception('Directions API failed: ${data['status']}');
        }
      } else {
        throw Exception('Failed to fetch directions: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load route: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _stripHtml(String htmlText) {
    RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    return htmlText.replaceAll(exp, '');
  }

  LatLngBounds _computeBounds(List<LatLng> points) {
    double southWestLat = points[0].latitude;
    double southWestLng = points[0].longitude;
    double northEastLat = points[0].latitude;
    double northEastLng = points[0].longitude;

    for (var point in points) {
      if (point.latitude < southWestLat) southWestLat = point.latitude;
      if (point.longitude < southWestLng) southWestLng = point.longitude;
      if (point.latitude > northEastLat) northEastLat = point.latitude;
      if (point.longitude > northEastLng) northEastLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );
  }

  void _startNavigation() async {
    setState(() {
      _isNavigating = true;
      _isMapManuallyPanned = false;
    });

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings);
    _positionStream!.listen((Position position) async {
      setState(() {
        _currentUserLocation = LatLng(position.latitude, position.longitude);
        _currentSpeed = position.speed * 3.6;
      });

      bool isOnRoute = false;
      for (var step in _navigationSteps) {
        final stepLocation = step['end_location'] as LatLng;
        final distance = Geolocator.distanceBetween(
          _currentUserLocation!.latitude,
          _currentUserLocation!.longitude,
          stepLocation.latitude,
          stepLocation.longitude,
        );
        if (distance < 50) {
          isOnRoute = true;
          break;
        }
      }

      if (!isOnRoute) {
        await _fetchRoute(origin: _currentUserLocation);
        _currentStepIndex = 0;
      }

      _updateNavigationInstruction();
      _updateRemainingTimeAndDistance();

      if (!_isMapManuallyPanned) {
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _currentUserLocation!,
              zoom: 18,
              tilt: 60,
              bearing: position.heading,
            ),
          ),
        );
      }
    });
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _isMapManuallyPanned = false;
      _positionStream = null;
      _currentInstruction = null;
      _distanceToNextStep = double.infinity;
      _currentStepIndex = 0;
      _currentSpeed = null;
    });
    _fetchRoute();
  }

  void _updateNavigationInstruction() {
    if (_navigationSteps.isEmpty) return;

    bool stepUpdated = false;
    for (int i = _currentStepIndex; i < _navigationSteps.length; i++) {
      final step = _navigationSteps[i];
      final stepLocation = step['end_location'] as LatLng;
      final distance = Geolocator.distanceBetween(
        _currentUserLocation!.latitude,
        _currentUserLocation!.longitude,
        stepLocation.latitude,
        stepLocation.longitude,
      );

      if (distance <= 30) {
        if (i + 1 < _navigationSteps.length) {
          setState(() {
            _currentStepIndex = i + 1;
            _currentInstruction = _navigationSteps[_currentStepIndex]['instruction'];
            _distanceToNextStep = _navigationSteps[_currentStepIndex]['distance'].toDouble();
          });
          _animationController.forward(from: 0);
        } else {
          setState(() {
            _currentInstruction = "You have reached your destination!";
            _distanceToNextStep = 0;
            _isNavigating = false;
            _remainingTime = "0 mins";
            _remainingDistance = "0 km";
          });
          _positionStream = null;
        }
        stepUpdated = true;
        break;
      }
    }

    if (!stepUpdated) {
      final step = _navigationSteps[_currentStepIndex];
      final stepLocation = step['end_location'] as LatLng;
      final distance = Geolocator.distanceBetween(
        _currentUserLocation!.latitude,
        _currentUserLocation!.longitude,
        stepLocation.latitude,
        stepLocation.longitude,
      );
      setState(() {
        _currentInstruction = step['instruction'];
        _distanceToNextStep = distance;
      });
    }
  }

  void _updateRemainingTimeAndDistance() async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${_currentUserLocation!.latitude},${_currentUserLocation!.longitude}'
          '&destination=${widget.eventLocation.latitude},${widget.eventLocation.longitude}'
          '&mode=driving'
          '&key=${widget.googleApiKey}';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final leg = data['routes'][0]['legs'][0];
          final duration = leg['duration']['text'];
          final distance = leg['distance']['text'];
          setState(() {
            _remainingTime = duration;
            _remainingDistance = distance;
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating remaining time and distance: $e');
    }
  }

  void _recenterMap() {
    setState(() {
      _isMapManuallyPanned = false;
    });
    if (_currentUserLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentUserLocation!,
            zoom: 18,
            tilt: 60,
            bearing: Geolocator.bearingBetween(
              _currentUserLocation!.latitude,
              _currentUserLocation!.longitude,
              _currentUserLocation!.latitude,
              _currentUserLocation!.longitude,
            ),
          ),
        ),
      );
    }
  }

  Widget _getTurnIcon(String maneuver) {
    switch (maneuver) {
      case 'turn-left':
        return Icon(Icons.arrow_back, size: 40, color: Colors.white);
      case 'turn-right':
        return Icon(Icons.arrow_forward, size: 40, color: Colors.white);
      case 'straight':
        return Icon(Icons.arrow_upward, size: 40, color: Colors.white);
      case 'roundabout-left':
      case 'roundabout-right':
        return Icon(Icons.roundabout_right, size: 40, color: Colors.white);
      default:
        return Icon(Icons.arrow_upward, size: 40, color: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Route to Event'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.compass_calibration, color: Colors.white),
            onPressed: () {
              _mapController?.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _currentUserLocation ?? widget.eventLocation,
                    zoom: _currentZoom,
                    tilt: 0,
                    bearing: 0,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.eventLocation,
              zoom: 15,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              controller.setMapStyle('''
                [
                  {
                    "featureType": "poi",
                    "stylers": [
                      { "visibility": "off" }
                    ]
                  },
                  {
                    "featureType": "transit",
                    "stylers": [
                      { "visibility": "off" }
                    ]
                  }
                ]
              ''');
            },
            onCameraMove: (CameraPosition position) {
              _currentZoom = position.zoom;
              if (_isNavigating) {
                setState(() {
                  _isMapManuallyPanned = true;
                });
              }
            },
            markers: {
              Marker(
                markerId: MarkerId('event_location'),
                position: widget.eventLocation,
                infoWindow: InfoWindow(title: 'Event Location'),
              ),
              if (_currentUserLocation != null)
                Marker(
                  markerId: MarkerId('user_location'),
                  position: _currentUserLocation!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                  infoWindow: InfoWindow(title: 'Your Location'),
                ),
            },
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      'Loading route...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          if (_isNavigating && _currentInstruction != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _getTurnIcon(_navigationSteps[_currentStepIndex]['maneuver']),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentInstruction!,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (_distanceToNextStep != double.infinity && _distanceToNextStep > 0)
                              SizedBox(height: 8),
                            if (_distanceToNextStep != double.infinity && _distanceToNextStep > 0)
                              Text(
                                'In ${(_distanceToNextStep).toInt()} m',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isNavigating)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGray,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: AppColors.textGray, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'ETA: $_remainingTime',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.straighten, color: AppColors.textGray, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$_remainingDistance',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _stopNavigation,
                        icon: Icon(Icons.stop, size: 18),
                        label: Text("Stop"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (!_isNavigating && _travelTime != null && _travelDistance != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGray,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: AppColors.textGray, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'ETA: $_travelTime',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.straighten, color: AppColors.textGray, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$_travelDistance',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _startNavigation,
                    icon: Icon(Icons.navigation, size: 18),
                    label: Text("Go Now"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                  ),
                ],
              ),
            ),
          if (_isNavigating && _isMapManuallyPanned)
            Positioned(
              bottom: 100,
              right: 16,
              child: FloatingActionButton(
                onPressed: _recenterMap,
                backgroundColor: AppColors.backgroundGray,
                child: Icon(Icons.my_location, color: AppColors.primary),
              ),
            ),
          if (_isNavigating && _currentSpeed != null)
            Positioned(
              top: 100,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '${_currentSpeed!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'km/h',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}