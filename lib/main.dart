import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:str_erp/Manager/ManagerLogin.dart';
import 'package:str_erp/members/BackgroundLocationHelper.dart';
import 'TeamLead/TLHome.dart';
import '../auth/Login.dart';
import 'firebase_options.dart';


//this is the entry point of the APP 

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize background service immediately
  await BackgroundLocationService.initializeService();
  
  // Check if service should be running on app start
  final prefs = await SharedPreferences.getInstance();
  final shouldRun = prefs.getBool('service_should_run') ?? false;
  
  if (shouldRun) {
    print("App started - service should be running, starting it...");
    await BackgroundLocationService.startBackgroundLocationService();
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      theme: ThemeData.dark(),
      home: LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}




