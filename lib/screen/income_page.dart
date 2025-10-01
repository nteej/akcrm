import 'package:flutter/material.dart';
import '../services/income_service.dart';

class IncomeRecord {
  final String category;
  final double amount;
  final DateTime date;
  final String details;

  IncomeRecord({
    required this.category,
    required this.amount,
    required this.date,
    required this.details,
  });

  factory IncomeRecord.fromJson(Map<String, dynamic> json) {
    return IncomeRecord(
      category: json['category'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      details: json['details'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
      'details': details,
    };
  }
}

class IncomePage extends StatefulWidget {
  const IncomePage({super.key});

  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  List<IncomeRecord> allRecords = [];
  String selectedCategory = 'ALL';
  List<String> categories = ['ALL'];
  bool isLoading = true;
  String? errorMessage;

    // Month filter
    int? selectedMonth; // 1-12
    List<int> availableMonths = [];

    @override
    void initState() {
      super.initState();
      _loadIncomeData();
    }

    Future<void> _loadIncomeData() async {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      try {
        final records = await IncomeService.fetchIncomeRecords();
        final categoryList = await IncomeService.fetchIncomeCategories();

        setState(() {
          allRecords = records;
          categories = categoryList;
          // Collect available months from allRecords
          availableMonths = allRecords.map((r) => r.date.month).toSet().toList()..sort();
          selectedMonth = null;
          isLoading = false;
        });
      } catch (e) {
        setState(() {
          errorMessage = 'Failed to load income data: $e';
          isLoading = false;
        });
      }
    }

    // Define which categories are credit and which are debit
    final List<String> creditCategories = ['SALARY', 'FUEL REIMBURSE', 'MONEY REIMBURSE'];
    final List<String> debitCategories = ['SALARY ADVANCE', 'LOAN'];

    double get totalCredit {
      return filteredRecords
          .where((r) => creditCategories.contains(r.category))
          .fold(0.0, (sum, r) => sum + r.amount);
    }

    double get totalDebit {
      return filteredRecords
          .where((r) => debitCategories.contains(r.category))
          .fold(0.0, (sum, r) => sum + r.amount);
    }

    double get balance => totalCredit - totalDebit;

  List<IncomeRecord> get filteredRecords {
    List<IncomeRecord> records = allRecords;
    if (selectedCategory != 'ALL') {
      records = records.where((r) => r.category == selectedCategory).toList();
    }
    if (selectedMonth != null) {
      records = records.where((r) => r.date.month == selectedMonth).toList();
    }
    return records;
  }

  void _showDetails(IncomeRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(record.category),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: €${record.amount.toStringAsFixed(2)}'),
            Text('Date: ${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}'),
            SizedBox(height: 8),
            Text('Details: ${record.details}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow[200],
      appBar: AppBar(
        title: Text('Income Overview'),
        backgroundColor: Colors.yellow[300],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: isLoading ? null : _loadIncomeData,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading income data...'),
                ],
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadIncomeData,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : allRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No income records found',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Your income data will appear here once available',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadIncomeData,
                            child: Text('Refresh'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButton<String>(
                                  value: selectedCategory,
                                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      selectedCategory = val!;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: DropdownButton<int>(
                                  value: selectedMonth,
                                  hint: Text('Month'),
                                  items: [
                                    DropdownMenuItem<int>(value: null, child: Text('All Months')),
                                    ...availableMonths.map((m) => DropdownMenuItem<int>(
                                      value: m,
                                      child: Text(m.toString().padLeft(2, '0')),
                                    ))
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      selectedMonth = val;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: filteredRecords.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.filter_list_off, size: 48, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text(
                                        'No records match the selected filters',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredRecords.length,
                                  itemBuilder: (context, index) {
                                    final record = filteredRecords[index];
                                    return Card(
                                      color: Colors.yellow[400],
                                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: ListTile(
                                        title: Text(record.category),
                                        subtitle: Text('€${record.amount.toStringAsFixed(2)} on ${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}'),
                                        onTap: () => _showDetails(record),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        // Summary row at the bottom
                        Container(
                          color: Colors.grey[100],
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text('Credit: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    '€${totalCredit.toStringAsFixed(2)}',
                                    style: TextStyle(color: Colors.red[200], fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('Debit: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    '€${totalDebit.toStringAsFixed(2)}',
                                    style: TextStyle(color: Colors.green[200], fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('Balance: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    '€${balance.toStringAsFixed(2)}',
                                    style: TextStyle(color: Colors.blue[200], fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}
