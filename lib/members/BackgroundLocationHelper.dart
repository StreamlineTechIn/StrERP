import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
class BackgroundLocationService {
  static const String _isolateName = 'locationIsolate';
  static const String _locationUpdatePort = 'location_update_port';
  static Timer? _locationTimer;
  static FlutterBackgroundService? _service;
  static bool _isServiceRunning = false;
  static int _locationUpdateCounter = 0;
  static const int _maxLocationsPerDocument = 50;
  static int _failedUpdateCount = 0;
  static const int LOCATION_UPDATE_INTERVAL_SECONDS = 3; // Every 3 seconds
  static const int SERVICE_KEEPALIVE_INTERVAL_SECONDS = 3; // Every 3 seconds

  static Future<void> initializeService() async {
    if (_service != null) {
      print("Service already initialized");
      return;
    }

    _service = FlutterBackgroundService();
    print("Initializing Background Location Service");

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'location_service',
      'Location Tracking Service',
      description: 'Tracks location in background for attendance',
      importance: Importance.high,
      enableLights: true,
      enableVibration: false,
      playSound: false,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _service!.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: startCallback,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'location_service',
        initialNotificationTitle: 'Location Tracking Active',
        initialNotificationContent: 'Recording location for attendance',
        foregroundServiceNotificationId: 888,
        autoStartOnBoot: true,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: startCallback,
        onBackground: onIosBackground,
      ),
    );

    final ReceivePort receivePort = ReceivePort();
    if (IsolateNameServer.lookupPortByName(_locationUpdatePort) != null) {
      IsolateNameServer.removePortNameMapping(_locationUpdatePort);
    }
    IsolateNameServer.registerPortWithName(
        receivePort.sendPort, _locationUpdatePort);

    receivePort.listen((dynamic data) {
      print("Received from isolate: $data");
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    print("iOS background handler called");
    return true;
  }

  @pragma('vm:entry-point')
  static Future<void> onBootCompleted() async {
    print("Device booted - checking if service should restart");

    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      final prefs = await SharedPreferences.getInstance();
      final shouldRun = prefs.getBool('service_should_run') ?? false;

      if (shouldRun) {
        print("Service should be running after boot - starting it");
        await Future.delayed(Duration(seconds: 10));
        await startBackgroundLocationService();
      }
    } catch (e) {
      print("Error in onBootCompleted: $e");
    }
  }

  @pragma('vm:entry-point')
  static void startCallback(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    print("Started Background Location Tracking");

    bool firebaseInitialized = false;
    int retryCount = 0;
    while (!firebaseInitialized && retryCount < 3) {
      try {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
        firebaseInitialized = true;
        print("Firebase initialized successfully in background service");
      } catch (e) {
        retryCount++;
        print("Error initializing Firebase in background service (attempt $retryCount): $e");
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print("Location permission denied");
        await Future.delayed(Duration(minutes: 1));
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          service.stopSelf();
          return;
        }
      }
    }

    service.on('stopService').listen((event) async {
      print("Stop service command received");
      _locationTimer?.cancel();
      _locationTimer = null;

      final prefs = await SharedPreferences.getInstance();
      final shouldRun = prefs.getBool('service_should_run') ?? false;

      if (shouldRun) {
        print(
            "Service should continue running - attempting restart in 5 seconds");
        await Future.delayed(Duration(seconds: 5));
        await startBackgroundLocationService();
      } else {
        _isServiceRunning = false;
        service.stopSelf();
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email');
    if (userEmail == null || userEmail.isEmpty) {
      print("No user email found, stopping service");
      service.stopSelf();
      return;
    }

    final targetLatitude = prefs.getDouble('target_latitude') ?? 0.0;
    final targetLongitude = prefs.getDouble('target_longitude') ?? 0.0;
    final noTrackingRadius = prefs.getDouble('no_tracking_radius') ?? 100.0;

    print("Starting location updates for user: $userEmail");
    _isServiceRunning = true;

    await _captureLocation(service, userEmail, 'check_in', targetLatitude,
        targetLongitude, noTrackingRadius);

    _locationTimer = Timer.periodic(
        const Duration(seconds: LOCATION_UPDATE_INTERVAL_SECONDS), (timer) async {
      if (!_isServiceRunning || _locationTimer == null) {
        print("Service no longer running, cancelling timer");
        timer.cancel();
        return;
      }

      try {
        print("Attempting to get current position...");
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          targetLatitude,
          targetLongitude,
        );

        final shouldPause = prefs.getBool('pause_tracking') ?? false;
        if (shouldPause || distance <= noTrackingRadius) {
          print("Tracking paused or within no-tracking zone ($distance meters from target).");
          return;
        }

        print("Location update: Lat: ${position.latitude}, Long: ${position.longitude}, Distance: ${distance}m");

        await _storeLocationUpdate(userEmail, position, 'background_update');
        _failedUpdateCount = 0;

        final SendPort? sendPort = IsolateNameServer.lookupPortByName(_locationUpdatePort);
        if (sendPort != null) {
          sendPort.send({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'timestamp': DateTime.now().toString(),
          });
        }
      } catch (e) {
        _failedUpdateCount++;
        print("[Service] Error in background location tracking ($e) - failed count $_failedUpdateCount");

        if (_failedUpdateCount > 10) {
          print("Too many location failures, attempting service restart");
          _failedUpdateCount = 0;
          try {
            await restartBackgroundService(service);
          } catch (restartError) {
            print("Error restarting service: $restartError");
          }
        }
      }
    });

    Timer.periodic(
        const Duration(seconds: SERVICE_KEEPALIVE_INTERVAL_SECONDS), (timer) async {
      if (!_isServiceRunning) {
        timer.cancel();
        return;
      }

      final shouldRun = prefs.getBool('service_should_run') ?? false;
      if (!shouldRun) {
        print("Service should no longer run based on preferences");
        service.stopSelf();
        _isServiceRunning = false;
        timer.cancel();
      }
    });
  }

  static Future<void> restartBackgroundService(ServiceInstance service) async {
    print("Attempting to restart background service");

    _locationTimer?.cancel();

    await Future.delayed(Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('service_should_run', true);

    await startBackgroundLocationService();
  }

  static Future<void> _captureLocation(
      ServiceInstance service,
      String userEmail,
      String locationType,
      double targetLatitude,
      double targetLongitude,
      double noTrackingRadius) async {
    try {
      print("Capturing $locationType location...");
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print("$locationType location: Lat: ${position.latitude}, Long: ${position.longitude}");

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLatitude,
        targetLongitude,
      );

      if (distance <= noTrackingRadius) {
        print("Check-in is within no-tracking zone ($distance meters from target).");
      }

      await _storeLocationUpdate(userEmail, position, locationType);

      print("$locationType location stored successfully");
    } catch (e) {
      print("[Service] Error capturing $locationType location: $e");
    }
  }

  static Future<void> _storeLocationUpdate(
      String userEmail, Position position, String locationType) async {
    if (userEmail.isEmpty) {
      print("Cannot store location update: userEmail is empty");
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();
    final formattedDate = "${now.year}-${now.month}-${now.day}";

    print("Storing $locationType for date: $formattedDate and user: $userEmail");
    print("Writing to path: memberLocations/$formattedDate/users/$userEmail/locations");

    try {
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          final locationData = {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'timestamp': Timestamp.now(),
            'accuracy': position.accuracy,
            'type': locationType,
            'appState': 'background',
          };

          _locationUpdateCounter++;

          int documentSegment =
          (_locationUpdateCounter / _maxLocationsPerDocument).floor();
          String documentName = "$formattedDate-$documentSegment";

          await firestore
              .collection('memberLocations')
              .doc(formattedDate)
              .collection('users')
              .doc(userEmail)
              .collection('locations')
              .doc(documentName)
              .set({
            'locationStream': FieldValue.arrayUnion([locationData])
          }, SetOptions(merge: true)).timeout(Duration(seconds: 10));

          print("Location stored successfully for user $userEmail in segment $documentSegment at path: memberLocations/$formattedDate/users/$userEmail/locations/$documentName");
          break;
        } catch (e) {
          retryCount++;
          print("Firestore error (attempt $retryCount): $e");
          if (retryCount >= maxRetries) {
            print("Max retries reached, storing for offline sync");
            await _storeForOfflineSync(userEmail, position, locationType);
          } else {
            await Future.delayed(Duration(seconds: 2 * retryCount));
          }
        }
      }
    } catch (e) {
      print("Error in _storeLocationUpdate: $e");
      await _storeForOfflineSync(userEmail, position, locationType);
    }
  }

  static Future<void> _storeForOfflineSync(
      String userEmail, Position position, String locationType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;

      List<String> offlineData = prefs.getStringList('offline_location_data') ?? [];

      final locationJson = {
        'userEmail': userEmail,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': now,
        'accuracy': position.accuracy,
        'type': locationType,
      };

      offlineData.add(locationJson.toString());

      if (offlineData.length > 100) {
        offlineData = offlineData.sublist(offlineData.length - 100);
      }

      await prefs.setStringList('offline_location_data', offlineData);
      print("Stored location update offline for future sync");
    } catch (e) {
      print("Error storing offline data: $e");
    }
  }

  static Future<void> startBackgroundLocationService() async {
    print("Starting background location service");
    if (_service == null) {
      await initializeService();
    }
    final isRunning = await _service!.isRunning();
    if (isRunning) {
      print("Service is already running, not starting again");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('service_should_run', true);

    await _service!.startService();
    print("Background service start command issued");

    await Future.delayed(Duration(seconds: 2));
    final didStart = await _service!.isRunning();
    if (!didStart) {
      print("Service failed to start, retrying once more");
      await _service!.startService();
    }
  }

  static Future<void> stopBackgroundLocationService() async {
    print("Stopping background location service");

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('service_should_run', false);

    if (_service == null) {
      print("Service was never initialized");
      return;
    }

    final isRunning = await _service!.isRunning();
    if (!isRunning) {
      print("Service is not running, nothing to stop");
      return;
    }

    final targetLatitude = prefs.getDouble('target_latitude') ?? 0.0;
    final targetLongitude = prefs.getDouble('target_longitude') ?? 0.0;
    final noTrackingRadius = prefs.getDouble('no_tracking_radius') ?? 100.0;
    final userEmail = prefs.getString('user_email') ?? '';

    if (_service is ServiceInstance && userEmail.isNotEmpty) {
      await _captureLocation(_service! as ServiceInstance, userEmail,
          'check_out', targetLatitude, targetLongitude, noTrackingRadius);
    }

    _service!.invoke('stopService');

    _isServiceRunning = false;
    if (IsolateNameServer.lookupPortByName(_locationUpdatePort) != null) {
      IsolateNameServer.removePortNameMapping(_locationUpdatePort);
    }

    print("Background location service stop requested");
  }
}