import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  final double totalIncome;
  final double workedHours;
  final double loanTaken;

  const DashboardPage({
    super.key,
    this.totalIncome = 0,
    this.workedHours = 0,
    this.loanTaken = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow[200],
      appBar: AppBar(title: Text('Dashboard'),backgroundColor: Colors.yellow[300],),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.green[100],
              child: ListTile(
                leading: Icon(Icons.euro, color: Colors.green),
                title: Text('Total Income'),
                subtitle: Text('€${totalIncome.toStringAsFixed(2)}'),
              ),
            ),
            SizedBox(height: 16),
            Card(
              color: Colors.blue[100],
              child: ListTile(
                leading: Icon(Icons.access_time, color: Colors.blue),
                title: Text('Worked Hours'),
                subtitle: Text('${workedHours.toStringAsFixed(2)} hours'),
              ),
            ),
            SizedBox(height: 16),
            Card(
              color: Colors.red[100],
              child: ListTile(
                leading: Icon(Icons.money_off, color: Colors.red),
                title: Text('Loan Taken'),
                subtitle: Text('€${loanTaken.toStringAsFixed(2)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
