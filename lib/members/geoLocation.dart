import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'BackgroundLocationHelper.dart';
import 'dart:async';

class AttendancePage extends StatefulWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with WidgetsBindingObserver {
  late LocationPermission permission;
  Position? currentPos;
  final double targetLatitude = 20.991388;
  final double targetLongitude = 75.552986;
  final double noTrackingRadius = 10.0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? memberDocId;
  bool _isCheckInLoading = false;
  bool _isCheckOutLoading = false;
  bool _isRemoteCheckInLoading = false;
  bool _isRemoteCheckOutLoading = false;
  bool isTracking = false;
  bool _serviceRunning = false;
  Position? _lastPosition;
  Timer? _statusTimer;
  Timer? _locationTrackingTimer;
  int _locationUpdateCounter = 0;
  static const int _maxLocationsPerDocument = 50;
  String? _currentTripId;

  List<LatLng> _recentPath = [];
  LatLng? _currentMapCenter;
  final int _maxPathPoints = 50;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
    _checkTrackingStatus();
    _initializeBackgroundService();
    _ensureServicePersistence();

    _statusTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _checkTrackingStatus();
      _getLastLocation();
    });

    _currentMapCenter = LatLng(targetLatitude, targetLongitude);
  }

  Future<void> _restoreServiceIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldRun = prefs.getBool('service_should_run') ?? false;
    final serviceRunning = await FlutterBackgroundService().isRunning();

    if (shouldRun && !serviceRunning) {
      print("Restoring background service...");
      await BackgroundLocationService.startBackgroundLocationService();
      setState(() {
        isTracking = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        print("App resumed - checking service status");
        _checkTrackingStatus();
        _getLastLocation();
        _restoreServiceIfNeeded();
        _syncOfflineLocationData();
        break;
      case AppLifecycleState.paused:
        print("App paused - ensuring service persistence");
        _ensureServicePersistence();
        break;
      case AppLifecycleState.detached:
        print("App detached");
        break;
      case AppLifecycleState.inactive:
        print("App inactive");
        break;
      case AppLifecycleState.hidden:
        print("App hidden");
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _locationTrackingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeBackgroundService() async {
    await BackgroundLocationService.initializeService();
  }

  Future<void> _checkTrackingStatus() async {
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();

    if (mounted) {
      setState(() {
        _serviceRunning = isRunning;
        isTracking = isRunning;
      });
    }

    print("Background service running status: $isRunning");
  }

  Future<void> _ensureServicePersistence() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('service_should_run', isTracking);

    if (isTracking) {
      await prefs.setString('user_email', _auth.currentUser?.email ?? '');
      await prefs.setDouble('target_latitude', targetLatitude);
      await prefs.setDouble('target_longitude', targetLongitude);
      await prefs.setDouble('no_tracking_radius', noTrackingRadius);

      Timer.periodic(Duration(seconds: 5), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final shouldRun = prefs.getBool('service_should_run') ?? false;
        final serviceRunning = await FlutterBackgroundService().isRunning();

        if (shouldRun && !serviceRunning) {
          print("Service should be running but isn't. Restarting...");
          await BackgroundLocationService.startBackgroundLocationService();
        }
      });
    }
  }

  Future<void> _getLastLocation() async {
    if (!isTracking) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLatitude,
        targetLongitude,
      );

      print("Distance from target: ${distance}m");

      bool isWithinNoTrackingZone = distance <= noTrackingRadius;

      if (mounted) {
        setState(() {
          _lastPosition = position;
          _currentMapCenter = LatLng(position.latitude, position.longitude);
          _recentPath.add(_currentMapCenter!);
          if (_recentPath.length > _maxPathPoints) {
            _recentPath.removeAt(0); // Fixed: Changed removeApplifecycleStateAt to removeAt
          }
        });
      }

      if (isWithinNoTrackingZone && isTracking) {
        print("Within no-tracking zone ($distance meters from target). Pausing tracking.");
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pause_tracking', true);
      } else if (!isWithinNoTrackingZone && isTracking) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pause_tracking', false);
        if (_auth.currentUser?.email != null) {
          await _storeLocationUpdate(_auth.currentUser!.email!, position, 'update');
        }
      }

      print("Current position: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print("Error getting current position: $e");
    }
  }

  void _checkPermission() async {
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      LocationPermission askedPermission = await Geolocator.requestPermission();
      if (askedPermission == LocationPermission.denied ||
          askedPermission == LocationPermission.deniedForever) {
        print("Permission denied permanently");
        _showResultDialog("Permission Denied",
            "Location permission is required for attendance tracking. Please enable it in your device settings.");
        return;
      }
    }

    if (Platform.isAndroid) {
      if (await Permission.locationAlways.request().isDenied) {
        _showResultDialog("Permission Required",
            "Background location permission is required for continuous tracking. Please allow 'All the time' access in the next prompt.");
        await Permission.locationAlways.request();
      }
    }
  }

  void _startLocationTracking() async {
    if (!isTracking) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', _auth.currentUser?.email ?? '');
      await prefs.setBool('service_should_run', true);
      await prefs.setBool('pause_tracking', false);
      await prefs.setDouble('target_latitude', targetLatitude);
      await prefs.setDouble('target_longitude', targetLongitude);
      await prefs.setDouble('no_tracking_radius', noTrackingRadius);

      await BackgroundLocationService.startBackgroundLocationService();

      setState(() {
        isTracking = true;
      });

      if (_auth.currentUser?.email != null) {
        _currentTripId = await _getNextTripId(_auth.currentUser!.email!);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location tracking started'),
          duration: Duration(seconds: 2),
        ),
      );

      _locationTrackingTimer =
          Timer.periodic(Duration(minutes: 1), (timer) async {
            if (!mounted) {
              timer.cancel();
              return;
            }

            final serviceRunning = await FlutterBackgroundService().isRunning();
            final shouldRun = prefs.getBool('service_should_run') ?? false;

            if (shouldRun && !serviceRunning) {
              print("Service stopped unexpectedly, restarting...");
              await BackgroundLocationService.startBackgroundLocationService();
            }

            _checkTrackingStatus();
            _getLastLocation();
          });
    }
  }

  Future<String> _getNextTripId(String userEmail) async {
    final now = DateTime.now();
    final formattedDate = "${now.year}-${now.month}-${now.day}";

    QuerySnapshot tripSnapshot = await _firestore
        .collection('memberLocations')
        .doc(formattedDate)
        .collection(userEmail)
        .get();

    if (tripSnapshot.docs.isEmpty) {
      return 'trip1';
    }

    int maxTripNumber = 0;
    for (var doc in tripSnapshot.docs) {
      String docId = doc.id;
      if (docId.startsWith('trip')) {
        int tripNumber = int.parse(docId.replaceFirst('trip', ''));
        if (tripNumber > maxTripNumber) {
          maxTripNumber = tripNumber;
        }
      }
    }

    return 'trip${maxTripNumber + 1}';
  }

  Future<void> _storeLocationUpdate(
      String userEmail, Position position, String locationType) async {
    if (userEmail.isEmpty) {
      print("Error: User email is empty, cannot store location.");
      return;
    }

    final now = DateTime.now();
    final formattedDate = "${now.year}-${now.month}-${now.day}";

    print("Attempting to store $locationType for email: $userEmail on date: $formattedDate");

    String tripId = _currentTripId ?? 'trip1'; // Moved outside the try block

    try {
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': Timestamp.now(),
        'accuracy': position.accuracy,
        'type': locationType,
      };

      await _firestore
          .collection('memberLocations')
          .doc(formattedDate)
          .collection(userEmail)
          .doc(tripId)
          .set({
        'locationStream': FieldValue.arrayUnion([locationData])
      }, SetOptions(merge: true));
      print("Location stored in memberLocations/$formattedDate/$userEmail/$tripId");

      _locationUpdateCounter++;
      if (_locationUpdateCounter >= _maxLocationsPerDocument) {
        _currentTripId = await _getNextTripId(userEmail);
        _locationUpdateCounter = 0;
      }

      final userSnapshot = await _firestore
          .collection('members')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        final userDoc = userSnapshot.docs.first;
        print("Found user in members collection: ${userDoc.id}");
        await userDoc.reference
            .collection('location')
            .doc("$formattedDate-$tripId")
            .set({
          'locationStream': FieldValue.arrayUnion([locationData])
        }, SetOptions(merge: true));
        print("Location stored in members/${userDoc.id}/location/$formattedDate-$tripId");
      }
    } catch (firestoreError) {
      print("Firestore error while storing location: $firestoreError");
      final prefs = await SharedPreferences.getInstance();
      List<String> offlineData = prefs.getStringList('offline_location_data') ?? [];
      offlineData.add("$userEmail|$formattedDate|$tripId|${position.latitude}|${position.longitude}|$locationType");
      await prefs.setStringList('offline_location_data', offlineData);
      print("Stored location update locally due to Firestore failure");
    }
  }
  Future<void> getRemotePos(String action) async {
    try {
      setState(() {
        if (action == 'checkIn') {
          _isRemoteCheckInLoading = true;
        } else {
          _isRemoteCheckOutLoading = true;
        }
      });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentPos = position;
      });

      if (action == 'checkIn') {
        await _sendRemoteCheckInRequest();
      } else {
        await _sendRemoteCheckOutRequest();
      }
    } catch (e) {
      print("Error fetching location: $e");
      _showResultDialog(
          "Error", "Unable to fetch your location: ${e.toString()}");
    } finally {
      setState(() {
        if (action == 'checkIn') {
          _isRemoteCheckInLoading = false;
        } else {
          _isRemoteCheckOutLoading = false;
        }
      });
    }
  }

  Future<bool> _isRemoteCheckInApproved() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return false;
    }

    final query = await _firestore
        .collection('remoteCheckInRequests')
        .where('userEmail', isEqualTo: user.email)
        .where('status', isEqualTo: 'approved')
        .get();

    return query.docs.isNotEmpty;
  }

  Future<void> getCurrentPos(String action) async {
    try {
      setState(() {
        if (action == 'checkIn') {
          _isCheckInLoading = true;
        } else {
          _isCheckOutLoading = true;
        }
      });

      if (action == 'checkOut') {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Authentication Error'),
              content: const Text('You need to be logged in to view your tasks.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
          return;
        }

        final today = DateFormat('dd-MM-yyyy').format(DateTime.now());

        await showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Remaining tasks for today'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('members')
                      .where('email', isEqualTo: currentUser.email)
                      .limit(1)
                      .snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Text("Error fetching tasks: ${snapshot.error}");
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Text("No user data found.");
                    }

                    final memberDoc = snapshot.data!.docs[0];

                    return StreamBuilder(
                      stream: FirebaseFirestore.instance
                          .collection('members')
                          .doc(memberDoc.id)
                          .collection('dailyTasks')
                          .doc(today)
                          .snapshots(),
                      builder: (context,
                          AsyncSnapshot<DocumentSnapshot> taskSnapshot) {
                        if (taskSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (taskSnapshot.hasError) {
                          return Text(
                              "Error fetching today's tasks: ${taskSnapshot.error}");
                        }

                        if (!taskSnapshot.hasData ||
                            !taskSnapshot.data!.exists) {
                          return const Text("No tasks found for today.");
                        }

                        final data =
                        taskSnapshot.data!.data() as Map<String, dynamic>;
                        final tasks = List<Map<String, dynamic>>.from(
                            data['tasks'] ?? []);

                        if (tasks.isEmpty) {
                          return const Text("You have no tasks for today.");
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            final title = task['title'] ?? 'Untitled Task';
                            final description =
                                task['description'] ?? 'No description';

                            return ListTile(
                              leading: const Icon(Icons.task_alt),
                              title: Text(title),
                              subtitle: Text(description),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Task'),
                                      content: Text(
                                          'Are you sure you want to delete "$title"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    try {
                                      final docRef = FirebaseFirestore.instance
                                          .collection('members')
                                          .doc(memberDoc.id)
                                          .collection('dailyTasks')
                                          .doc(today);

                                      final updatedTasks =
                                      List<Map<String, dynamic>>.from(tasks);
                                      updatedTasks.removeAt(index);

                                      await docRef.update({
                                        'tasks': updatedTasks,
                                      });

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Task "$title" deleted successfully'),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error deleting task: $e'),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentPos = position;
        _lastPosition = position;
        _currentMapCenter = LatLng(position.latitude, position.longitude);
        _recentPath.add(_currentMapCenter!);
        if (_recentPath.length > _maxPathPoints) {
          _recentPath.removeAt(0);
        }
      });

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLatitude,
        targetLongitude,
      );

      if (action == 'checkIn' && distance > 300) {
        bool isApproved = await _isRemoteCheckInApproved();
        if (!isApproved) {
          _showResultDialog(
              "Failed", "Remote check-in not approved by Team Lead.");
          return;
        }
      }

      await _storeAttendance(action);

      if (_auth.currentUser?.email != null) {
        await _storeLocationUpdate(_auth.currentUser!.email!, position,
            action == 'checkIn' ? 'check_in' : 'check_out');
      }

      if (action == 'checkIn') {
        _startLocationTracking();
      } else if (action == 'checkOut') {
        _stopLocationTracking();
      }
    } catch (e) {
      print("Error: $e");
      _showResultDialog(
          "Error", "Unable to process attendance: ${e.toString()}");
    } finally {
      setState(() {
        if (action == 'checkIn') {
          _isCheckInLoading = false;
        } else {
          _isCheckOutLoading = false;
        }
      });
    }
  }

  void _stopLocationTracking() async {
    if (isTracking) {
      setState(() {
        isTracking = false;
        _recentPath.clear();
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('service_should_run', false);

      _locationTrackingTimer?.cancel();
      _locationTrackingTimer = null;

      if (_auth.currentUser?.email != null && _lastPosition != null) {
        await _storeLocationUpdate(
            _auth.currentUser!.email!, _lastPosition!, 'check_out');
      }

      await BackgroundLocationService.stopBackgroundLocationService();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location tracking stopped')),
      );

      _checkTrackingStatus();
      _currentTripId = null;
    }
  }

  Future<void> _sendRemoteCheckInRequest() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      _showResultDialog("Error", "User not logged in or email not found.");
      return;
    }

    if (currentPos == null) {
      _showResultDialog("Error", "Location not available.");
      return;
    }

    String currentTime = DateFormat('HH:mm').format(DateTime.now());
    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      await _firestore.collection('remoteCheckInRequests').add({
        'userEmail': user.email,
        'latitude': currentPos!.latitude,
        'longitude': currentPos!.longitude,
        'date': currentDate,
        'time': currentTime,
        'status': 'pending',
      });

      _showResultDialog(
          "Success", "Remote check-in request sent to your Team Lead.");
    } catch (e) {
      print("Error sending remote request: $e");
      _showResultDialog(
          "Error", "Unable to send remote check-in request: ${e.toString()}");
    }
  }

  Future<void> _sendRemoteCheckOutRequest() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      _showResultDialog("Error", "User not logged in or email not found.");
      return;
    }

    if (currentPos == null) {
      _showResultDialog("Error", "Location not available.");
      return;
    }

    String currentTime = DateFormat('HH:mm').format(DateTime.now());
    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      DocumentReference remoteCheckOutRef =
      await _firestore.collection('remoteCheckOuts').add({
        'userEmail': user.email,
        'latitude': currentPos!.latitude,
        'longitude': currentPos!.longitude,
        'date': currentDate,
        'time': currentTime,
      });

      if (remoteCheckOutRef.id.isNotEmpty) {
        await _storeAttendance('checkOut');
        _stopLocationTracking();
        _showResultDialog("Success", "Remote check-out recorded successfully.");
      } else {
        _showResultDialog("Error", "Failed to record remote check-out.");
      }
    } catch (e) {
      print("Error processing remote check-out: $e");
      _showResultDialog(
          "Error", "Unable to process remote check-out: ${e.toString()}");
    }
  }

  Future<void> _storeAttendance(String action) async {
    User? user = _auth.currentUser;

    if (user == null || user.email == null) {
      print("User not logged in or email not found");
      return;
    }

    String emailID = user.email!;
    String day = DateFormat('EEEE').format(DateTime.now());
    DateTime now = DateTime.now();
    String formattedDate = "${now.year}-${now.month}-${now.day}";

    DocumentReference docRef = FirebaseFirestore.instance
        .collection('memberAttendance')
        .doc(formattedDate);

    try {
      await docRef.set({
        'attendees': {
          emailID: {
            action: DateFormat('HH:mm').format(DateTime.now()),
            'day': day,
          }
        },
      }, SetOptions(merge: true));

      _showResultDialog("Success", "$action successfully recorded");
    } catch (e) {
      print('Error storing attendance: $e');
      _showResultDialog("Failed", "Error storing attendance: ${e.toString()}");
    }
  }

  void _showResultDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _syncOfflineLocationData() async {
    final prefs = await SharedPreferences.getInstance();
    final offlineData = prefs.getStringList('offline_location_data');

    if (offlineData == null || offlineData.isEmpty) return;

    print("Found ${offlineData.length} offline location entries to sync");

    for (String entry in offlineData) {
      try {
        final parts = entry.split('|');
        if (parts.length != 6) continue;

        final userEmail = parts[0];
        final date = parts[1];
        final tripId = parts[2];
        final latitude = double.parse(parts[3]);
        final longitude = double.parse(parts[4]);
        final locationType = parts[5];

        final position = Position(
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );

        final locationData = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': Timestamp.now(),
          'accuracy': position.accuracy,
          'type': locationType,
        };

        await _firestore
            .collection('memberLocations')
            .doc(date)
            .collection(userEmail)
            .doc(tripId)
            .set({
          'locationStream': FieldValue.arrayUnion([locationData])
        }, SetOptions(merge: true));

        print("Synced offline location for $userEmail on $date in $tripId");
      } catch (e) {
        print("Error syncing offline data: $e");
      }
    }

    await prefs.setStringList('offline_location_data', []);
    print("Cleared offline location data after sync");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Attendance',
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.teal.shade700,
              Colors.teal.shade300,
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.4, 0.8],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isTracking ? Colors.green : Colors.red,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          isTracking ? "Tracking Active" : "Not Tracking",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    height: 300,
                    width: MediaQuery.of(context).size.width * 0.9,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _lastPosition == null
                          ? Center(
                        child: Text(
                          'Waiting for location...',
                          style: TextStyle(
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                          : FlutterMap(
                        options: MapOptions(
                          initialCenter: _currentMapCenter ??
                              LatLng(targetLatitude, targetLongitude),
                          initialZoom: 15.0,
                          minZoom: 5.0,
                          maxZoom: 18.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: ['a', 'b', 'c'],
                            userAgentPackageName: 'com.example.app',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _recentPath,
                                strokeWidth: 4.0,
                                color: Colors.blue,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  _lastPosition!.latitude,
                                  _lastPosition!.longitude,
                                ),
                                width: 40.0,
                                height: 40.0,
                                child: Icon(
                                  Icons.location_pin,
                                  color: Colors.red,
                                  size: 40.0,
                                ),
                              ),
                              Marker(
                                point: LatLng(targetLatitude, targetLongitude),
                                width: 40.0,
                                height: 40.0,
                                child: Icon(
                                  Icons.flag,
                                  color: Colors.green,
                                  size: 40.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  if (_lastPosition != null)
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Last location: ${_lastPosition!.latitude.toStringAsFixed(6)}, ${_lastPosition!.longitude.toStringAsFixed(6)}",
                            style: TextStyle(color: Colors.white),
                          ),
                          FutureBuilder<double>(
                            future: Future.value(Geolocator.distanceBetween(
                              _lastPosition!.latitude,
                              _lastPosition!.longitude,
                              targetLatitude,
                              targetLongitude,
                            )),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                bool isWithinNoTrackingZone =
                                    snapshot.data! <= noTrackingRadius;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "Distance from target: ${snapshot.data!.toStringAsFixed(1)}m" +
                                        (isWithinNoTrackingZone
                                            ? " (No tracking zone)"
                                            : ""),
                                    style: TextStyle(
                                      color: isWithinNoTrackingZone
                                          ? Colors.yellow
                                          : Colors.white,
                                      fontWeight: isWithinNoTrackingZone
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }
                              return SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 20),
                  GlassmorphicContainer(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: 500,
                    borderRadius: 30,
                    blur: 15,
                    alignment: Alignment.center,
                    border: 2,
                    linearGradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderGradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.5),
                        Colors.white.withOpacity(0.2),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          SizedBox(height: 50),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildAttendanceButton(
                                icon: Icons.check_circle_outline,
                                label: 'Check In',
                                color: Colors.green,
                                onTap: () => getCurrentPos('checkIn'),
                                isLoading: _isCheckInLoading,
                              ),
                              _buildAttendanceButton(
                                icon: Icons.exit_to_app_rounded,
                                label: 'Check Out',
                                color: Colors.red,
                                onTap: () => getCurrentPos('checkOut'),
                                isLoading: _isCheckOutLoading,
                              ),
                            ],
                          ),
                          SizedBox(height: 40),
                          _buildAttendanceButton(
                            icon: Icons.hourglass_top,
                            label: 'Request Remote Check In',
                            color: Colors.teal,
                            onTap: () => getRemotePos('checkIn'),
                            isWide: true,
                            isLoading: _isRemoteCheckInLoading,
                          ),
                          SizedBox(height: 40),
                          _buildAttendanceButton(
                            icon: Icons.hourglass_bottom,
                            label: 'Remote Check Out',
                            color: Colors.orange,
                            onTap: () => getRemotePos('checkOut'),
                            isWide: true,
                            isLoading: _isRemoteCheckOutLoading,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isWide = false,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: isWide ? double.infinity : 130,
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        decoration: BoxDecoration(
          color: color.withOpacity(isLoading ? 0.5 : 0.7),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: isLoading
            ? Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        )
            : Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 40,
            ),
            SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}