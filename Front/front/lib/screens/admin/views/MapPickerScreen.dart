import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart'; // For haptic feedback
import 'package:front/constants/colors.dart'; // Import AppColors

class MapPickerScreen extends StatefulWidget {
  final String? initialAddress;

  const MapPickerScreen({Key? key, this.initialAddress}) : super(key: key);

  @override
  _MapPickerScreenState createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(36.8065, 10.1815); // Default: Tunis, Tunisia
  String? _selectedAddress;
  bool _isLoading = true; // Start with loading state
  bool _isLoadingAddress = false;
  bool _isSearching = false;
  static const String _googleApiKey = 'AIzaSyCjUgGySYoos2UeHYmd6-MpIDLno2Sy2Ps';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Prioritize initialAddress if provided
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _geocodeInitialAddress(widget.initialAddress!);
    } else {
      _getUserLocation();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    debugPrint('Attempting to get user location...');

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location services are disabled. Please enable them.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _getUserLocation();
            },
          ),
        ),
      );
      return;
    }

    // Force recheck permissions every time
    PermissionStatus permission = await Permission.locationWhenInUse.request();
    debugPrint('Location permission status: $permission');

    if (permission.isDenied) {
      debugPrint('Location permissions are denied.');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location permissions are denied.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _getUserLocation();
            },
          ),
        ),
      );
      return;
    }

    if (permission.isPermanentlyDenied) {
      debugPrint('Location permissions are permanently denied.');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location permissions are permanently denied. Please enable them in settings.'),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: () async {
              await openAppSettings();
            },
          ),
        ),
      );
      return;
    }

    // Get the current position
    try {
      debugPrint('Fetching current position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(Duration(seconds: 15), onTimeout: () {
        throw Exception('Timed out while getting location');
      });
      debugPrint('Current position: ${position.latitude}, ${position.longitude}');
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation, 15),
      );
      _updateSelectedAddress();
    } catch (e) {
      debugPrint('Error getting user location: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not get your current location. Using default location (Tunis).'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _getUserLocation();
            },
          ),
        ),
      );
    }
  }

  Future<void> _geocodeInitialAddress(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$_googleApiKey';

    try {
      setState(() {
        _isLoading = true;
      });
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final location = data['results'][0]['geometry']['location'];
          setState(() {
            _selectedLocation = LatLng(location['lat'], location['lng']);
            _isLoading = false;
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_selectedLocation, 15),
          );
          _updateSelectedAddress();
        } else {
          throw Exception('Geocoding failed: ${data['status']}');
        }
      } else {
        throw Exception('Failed to geocode location: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error geocoding initial address: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load initial location. Please select manually.')),
      );
    }
  }

  Future<void> _geocodeSearchAddress(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$_googleApiKey';

    try {
      setState(() {
        _isSearching = true;
      });
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final location = data['results'][0]['geometry']['location'];
          setState(() {
            _selectedLocation = LatLng(location['lat'], location['lng']);
            _isSearching = false;
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_selectedLocation, 15),
          );
          _updateSelectedAddress();
        } else {
          throw Exception('Geocoding failed: ${data['status']}');
        }
      } else {
        throw Exception('Failed to geocode location: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error geocoding search address: $e');
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not find the searched location.')),
      );
    }
  }

  Future<void> _updateSelectedAddress() async {
    setState(() {
      _isLoadingAddress = true;
    });
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${_selectedLocation.latitude},${_selectedLocation.longitude}&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _selectedAddress = data['results'][0]['formatted_address'];
            _isLoadingAddress = false;
          });
        } else {
          setState(() {
            _selectedAddress = 'Unknown location';
            _isLoadingAddress = false;
          });
        }
      } else {
        setState(() {
          _selectedAddress = 'Unknown location';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
      setState(() {
        _selectedAddress = 'Unknown location';
        _isLoadingAddress = false;
      });
    }
  }

  void _onMapTapped(LatLng position) {
    HapticFeedback.lightImpact(); // Add haptic feedback
    setState(() {
      _selectedLocation = position;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(_selectedLocation),
    );
    _updateSelectedAddress();
  }

  void _confirmLocation() {
    if (_selectedAddress == null || _selectedAddress == 'Unknown location') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a valid location.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Location'),
        content: Text('Use this location:\n$_selectedAddress?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textGray)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, _selectedAddress);
            },
            child: Text('Confirm', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search location...',
            hintStyle: TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white24,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white, width: 2),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear, color: Colors.white),
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
            )
                : null,
          ),
          style: TextStyle(color: Colors.white),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _geocodeSearchAddress(value);
            }
          },
        ),
        actions: [
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              if (_searchController.text.isNotEmpty) {
                _geocodeSearchAddress(_searchController.text);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 15,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            onTap: _onMapTapped,
            markers: {
              Marker(
                markerId: MarkerId('selected_location'),
                position: _selectedLocation,
                draggable: true,
                onDragEnd: (newPosition) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedLocation = newPosition;
                  });
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLng(_selectedLocation),
                  );
                  _updateSelectedAddress();
                },
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Finding your location...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isLoading)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedAddress != null && _selectedAddress != 'Unknown location'
                        ? AppColors.primary.withOpacity(0.5)
                        : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, color: AppColors.secondary, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Location',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textGray,
                            ),
                          ),
                          SizedBox(height: 4),
                          _isLoadingAddress
                              ? Text(
                            'Loading address...',
                            style: TextStyle(color: AppColors.textGray),
                          )
                              : Text(
                            _selectedAddress ?? 'Tap the map or search to select a location',
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedAddress == null || _selectedAddress == 'Unknown location'
                                  ? AppColors.textGray
                                  : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedAddress == null || _selectedAddress == 'Unknown location')
                      IconButton(
                        icon: Icon(Icons.my_location, color: AppColors.primary),
                        tooltip: 'Use My Location',
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                          });
                          _getUserLocation();
                        },
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: !_isLoading
          ? Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            onPressed: () => Navigator.pop(context),
            backgroundColor: AppColors.textGray,
            child: Icon(Icons.close, color: Colors.white),
            tooltip: 'Cancel',
          ),
          SizedBox(width: 16),
          FloatingActionButton(
            onPressed: _confirmLocation,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.check, color: Colors.white),
            tooltip: 'Confirm Location',
          ),
        ],
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}