import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RedeemCreditsPage extends StatefulWidget {
  final String? email; // Member ID to access the Firestore document
  late final double finalCredits; // Current finalCredits value

  // Constructor to receive memberId and finalCredits
  RedeemCreditsPage({required this.email, required this.finalCredits});

  @override
  _RedeemCreditsPageState createState() => _RedeemCreditsPageState();
}

class _RedeemCreditsPageState extends State<RedeemCreditsPage> {
  double amountToRedeem = 0.0;
  String selectedOption = 'salary'; // Default option (Salary)
  bool isProcessing = false;
  double displayCredits = 0;

  // Function to handle credit redemption
  Future<void> _redeemCredits() async {
    if (amountToRedeem > displayCredits) {
      // Check if the user has enough finalCredits
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Insufficient Credits'),
            content: Text('You do not have enough finalCredits to redeem this amount.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'),
              ),
            ],
          );
        },
      );
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      // Reference to the specific document in 'weeklyHours'
      DocumentReference docRef = FirebaseFirestore.instance
          .collection('weeklyHours')
          .doc(widget.email);

      // Fetch the document to get the 'dates' field
      DocumentSnapshot snapshot = await docRef.get();
      if (!snapshot.exists) {
        throw Exception('Document does not exist');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      if (!data.containsKey('dates') || data['dates'] is! Map) {
        throw Exception('Invalid Firestore structure');
      }

      Map<String, dynamic> dates = Map<String, dynamic>.from(data['dates']);

      // Find the most recent date
      if (dates.isEmpty) {
        throw Exception('No dates available for processing');
      }

      String mostRecentDate = dates.keys.reduce((a, b) =>
      DateTime.parse(a).isAfter(DateTime.parse(b)) ? a : b);

      // Update the 'finalCredit' and add the selected option field
      if (dates[mostRecentDate].containsKey('finalCredit')) {
        double currentFinalCredits = dates[mostRecentDate]['finalCredit'] ?? 0.0;

        if (currentFinalCredits < amountToRedeem) {
          throw Exception('Insufficient finalCredits for redemption.');
        }

        dates[mostRecentDate]['finalCredit'] = currentFinalCredits - amountToRedeem;

        if (selectedOption == 'salary') {
          dates[mostRecentDate]['salarycredit'] = (dates[mostRecentDate]['salarycredit'] ?? 0.0) + amountToRedeem;
        } else if (selectedOption == 'leaves') {
          dates[mostRecentDate]['leavescredit'] = (dates[mostRecentDate]['leavescredit'] ?? 0.0) + amountToRedeem;
        }
      } else {
        throw Exception('No finalCredits available for redemption.');
      }

      // Update the document with the modified 'dates' field
      await docRef.update({'dates': dates});

      // Show success dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Redemption Successful'),
            content: Text('You have successfully redeemed $amountToRedeem finalCredits for ${selectedOption}.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'),
              ),
            ],
          );
        },
      );

      setState(() {
        displayCredits -= amountToRedeem;
      });
    } catch (e) {
      print('Error redeeming credits: $e');
      // Show error message
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('An error occurred while redeeming your credits. Please try again later.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'),
              ),
            ],
          );
        },
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    displayCredits = widget.finalCredits;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Redeem finalCredits'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Current finalCredits: ${displayCredits.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('Choose Redemption Option:'),
            ListTile(
              title: Text('Salary'),
              leading: Radio<String>(
                value: 'salary',
                groupValue: selectedOption,
                onChanged: (String? value) {
                  setState(() {
                    selectedOption = value!;
                  });
                },
              ),
            ),
            ListTile(
              title: Text('Leaves'),
              leading: Radio<String>(
                value: 'leaves',
                groupValue: selectedOption,
                onChanged: (String? value) {
                  setState(() {
                    selectedOption = value!;
                  });
                },
              ),
            ),
            SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                labelText: 'Enter amount to redeem',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  amountToRedeem = double.tryParse(value) ?? 0.0;
                });
              },
            ),
            SizedBox(height: 20),
            isProcessing
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _redeemCredits,
              child: Text('Redeem finalCredits'),
            ),
          ],
        ),
      ),
    );
  }
}
