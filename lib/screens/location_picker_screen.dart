// lib/screens/location_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({Key? key}) : super(key: key);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<_PlaceResult> _places = [];
  bool _isLoading = false;
  GeoPoint? _currentLocation;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = GeoPoint(position.latitude, position.longitude);
      });
      await _searchNearbyPlaces();
    } catch (e) {
      debugPrint('LocationPickerScreen: Error getting location: $e');
    }
  }

  Future<void> _searchNearbyPlaces() async {
    if (_currentLocation == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Use reverse geocoding to get nearby places
      final placemarks = await placemarkFromCoordinates(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      final places = <_PlaceResult>[];

      // Add current location as first option
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final placeName = [
          place.name,
          place.street,
          place.locality,
          place.administrativeArea,
        ].where((part) => part != null && part.isNotEmpty).join(', ');

        places.add(_PlaceResult(
          placeName: placeName.isNotEmpty ? placeName : 'Current Location',
          placeId:
              'current_${_currentLocation!.latitude}_${_currentLocation!.longitude}',
          geopoint: _currentLocation!,
        ));
      }

      // Add nearby places from other placemarks
      for (final placemark in placemarks.take(5)) {
        final placeName = [
          placemark.name,
          placemark.street,
          placemark.locality,
        ].where((part) => part != null && part.isNotEmpty).join(', ');

        if (placeName.isNotEmpty) {
          // For simplicity, we'll use the same geopoint as current location
          // In a full implementation, you'd get coordinates for each place
          places.add(_PlaceResult(
            placeName: placeName,
            placeId: 'place_${placemark.hashCode}',
            geopoint: _currentLocation!,
          ));
        }
      }

      setState(() {
        _places = places;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('LocationPickerScreen: Error searching places: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      await _searchNearbyPlaces();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Simple text-based search using geocoding
      // In a full implementation, you'd use Google Places API
      final locations = await locationFromAddress(query);

      if (locations.isNotEmpty) {
        final location = locations.first;
        final placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        final places = <_PlaceResult>[];
        for (final placemark in placemarks) {
          final placeName = [
            placemark.name,
            placemark.street,
            placemark.locality,
            placemark.administrativeArea,
          ].where((part) => part != null && part.isNotEmpty).join(', ');

          if (placeName.isNotEmpty) {
            places.add(_PlaceResult(
              placeName: placeName,
              placeId: 'search_${placemark.hashCode}',
              geopoint: GeoPoint(location.latitude, location.longitude),
            ));
          }
        }

        setState(() {
          _places = places;
          _isLoading = false;
        });
      } else {
        setState(() {
          _places = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('LocationPickerScreen: Error searching: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectPlace(_PlaceResult place) {
    Navigator.pop(context, {
      'geopoint': {
        'latitude': place.geopoint.latitude,
        'longitude': place.geopoint.longitude,
      },
      'placeName': place.placeName,
      'placeId': place.placeId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a place...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchNearbyPlaces();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  _searchPlaces(value);
                } else {
                  _searchNearbyPlaces();
                }
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _places.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No places found',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _places.length,
                        itemBuilder: (context, index) {
                          final place = _places[index];
                          return ListTile(
                            leading: const Icon(Icons.place),
                            title: Text(place.placeName),
                            subtitle: Text(
                              '${place.geopoint.latitude.toStringAsFixed(4)}, ${place.geopoint.longitude.toStringAsFixed(4)}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                            onTap: () => _selectPlace(place),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PlaceResult {
  final String placeName;
  final String placeId;
  final GeoPoint geopoint;

  _PlaceResult({
    required this.placeName,
    required this.placeId,
    required this.geopoint,
  });
}
