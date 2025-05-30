import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class BatteryOptimizationHelper {
  // Request battery optimization exemption
  static Future<bool> requestBatteryOptimizationExemption(BuildContext context) async {
    if (!Platform.isAndroid) return true;
    
    try {
      bool isIgnoring = await Permission.ignoreBatteryOptimizations.status.isGranted;
      
      if (!isIgnoring) {
        // Show dialog explaining why we need this permission
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Background Location Required"),
              content: Text(
                "This app needs to track location in the background for attendance purposes. "
                "Please allow the app to ignore battery optimization when prompted.\n\n"
                "If you don't see a prompt or want to enable it later, you can do so in:\n"
                "Settings > Apps > Your App > Battery > Unrestricted"
              ),
              actions: [
                TextButton(
                  child: Text("Continue"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
        
        // Request permission
        if (await Permission.ignoreBatteryOptimizations.request().isGranted) {
          return true;
        } else {
          // Show additional instructions if user didn't grant permission
          await _showBatteryOptimizationInstructions(context);
          return false;
        }
      }
      
      return isIgnoring;
    } catch (e) {
      print("Error requesting battery optimization exemption: $e");
      return false;
    }
  }
  
  // Show instructions for battery optimization settings
  static Future<void> _showBatteryOptimizationInstructions(BuildContext context) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String appName = packageInfo.appName;
    
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Battery Optimization"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "For reliable location tracking in the background, please disable battery optimization for $appName:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text("1. Open device Settings"),
                Text("2. Go to Apps (or Applications)"),
                Text("3. Find and tap on $appName"),
                Text("4. Tap on Battery"),
                Text("5. Select 'Unrestricted' or 'Don't optimize'"),
                SizedBox(height: 12),
                Text(
                  "On some devices, you may need to go to:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text("Settings > Battery > Battery optimization > All apps > $appName > Don't optimize"),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}