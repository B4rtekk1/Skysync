import 'package:flutter/material.dart';
import '../utils/api_service.dart';
import '../utils/token_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SharedSpreadsheetPreviewWidget extends StatelessWidget {
  final String filename;
  final String folderName;
  final String sharedBy;
  final double width;
  final double height;
  final bool showFullScreenOnTap;

  const SharedSpreadsheetPreviewWidget({
    Key? key,
    required this.filename,
    required this.folderName,
    required this.sharedBy,
    this.width = 100,
    this.height = 100,
    this.showFullScreenOnTap = true,
  }) : super(key: key);

  String get _previewUrl => '${ApiService.baseUrl}/files/${sharedBy}/${folderName}/${filename}?spreadsheet=true';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: showFullScreenOnTap ? () => _showFullScreen(context) : null,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: FutureBuilder<String?>(
            future: TokenService.getToken(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildPlaceholder();
              }
              
              final token = snapshot.data;
              if (token == null) {
                return _buildErrorWidget();
              }
              
              return FutureBuilder<Map<String, dynamic>>(
                future: _fetchSpreadsheetData(token),
                builder: (context, dataSnapshot) {
                  if (dataSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildPlaceholder();
                  }
                  
                  if (dataSnapshot.hasError || !dataSnapshot.hasData) {
                    return _buildErrorWidget();
                  }
                  
                  final data = dataSnapshot.data!;
                  final columns = data['columns'] as List;
                  final rows = data['rows'] as List;
                  final totalRows = data['total_rows'] as int;
                  final totalColumns = data['total_columns'] as int;
                  
                  return Container(
                    color: Colors.grey[50],
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.table_chart,
                              size: 16,
                              color: Colors.blue[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                filename,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalRows wierszy, $totalColumns kolumn',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (rows.isNotEmpty && columns.isNotEmpty)
                          Expanded(
                            child: SingleChildScrollView(
                              child: _buildPreviewTable(columns, rows),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewTable(List columns, List rows) {
    return Table(
      border: TableBorder.all(
        color: Colors.grey.shade300,
        width: 0.5,
      ),
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
      },
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
          ),
          children: columns.take(4).map<Widget>((column) {
            return Container(
              padding: const EdgeInsets.all(4),
              child: Text(
                column.toString(),
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
        // Data rows (max 5 rows for preview)
        ...rows.take(5).map<TableRow>((row) {
          return TableRow(
            children: row.take(4).map<Widget>((cell) {
              return Container(
                padding: const EdgeInsets.all(4),
                child: Text(
                  cell?.toString() ?? '',
                  style: const TextStyle(fontSize: 8),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          );
        }).toList(),
      ],
    );
  }

  Future<Map<String, dynamic>> _fetchSpreadsheetData(String token) async {
    final response = await http.get(
      Uri.parse(_previewUrl),
      headers: {
        'API_KEY': ApiService.apiKey,
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load spreadsheet data');
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.table_chart,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SharedFullScreenSpreadsheetView(
          filename: filename,
          folderName: folderName,
          sharedBy: sharedBy,
        ),
      ),
    );
  }
}

class SharedFullScreenSpreadsheetView extends StatelessWidget {
  final String filename;
  final String folderName;
  final String sharedBy;

  const SharedFullScreenSpreadsheetView({
    Key? key,
    required this.filename,
    required this.folderName,
    required this.sharedBy,
  }) : super(key: key);

  String get _previewUrl => '${ApiService.baseUrl}/files/${sharedBy}/${folderName}/${filename}?spreadsheet=true';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[800],
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          filename,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadSpreadsheet(context),
          ),
        ],
      ),
      body: FutureBuilder<String?>(
        future: TokenService.getToken(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          final token = snapshot.data;
          if (token == null) {
            return const Center(
              child: Text('Błąd autoryzacji'),
            );
          }
          
          return FutureBuilder<Map<String, dynamic>>(
            future: _fetchSpreadsheetData(token),
            builder: (context, dataSnapshot) {
              if (dataSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              
              if (dataSnapshot.hasError || !dataSnapshot.hasData) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nie można załadować danych arkusza',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                );
              }
              
              final data = dataSnapshot.data!;
              final columns = data['columns'] as List;
              final rows = data['rows'] as List;
              final totalRows = data['total_rows'] as int;
              final totalColumns = data['total_columns'] as int;
              
              return Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header with info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.table_chart,
                            color: Colors.blue[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  filename,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '$totalRows wierszy, $totalColumns kolumn',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Table
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: _buildFullTable(columns, rows),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFullTable(List columns, List rows) {
    return Table(
      border: TableBorder.all(
        color: Colors.grey.shade300,
        width: 0.5,
      ),
      columnWidths: Map.fromIterable(
        List.generate(columns.length, (index) => index),
        key: (index) => index,
        value: (index) => const FlexColumnWidth(1.5),
      ),
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
          ),
          children: columns.map<Widget>((column) {
            return Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                column.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
        // Data rows
        ...rows.map<TableRow>((row) {
          return TableRow(
            children: row.map<Widget>((cell) {
              return Container(
                padding: const EdgeInsets.all(8),
                child: Text(
                  cell?.toString() ?? '',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          );
        }).toList(),
      ],
    );
  }

  Future<Map<String, dynamic>> _fetchSpreadsheetData(String token) async {
    final response = await http.get(
      Uri.parse(_previewUrl),
      headers: {
        'API_KEY': ApiService.apiKey,
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load spreadsheet data');
    }
  }

  void _downloadSpreadsheet(BuildContext context) {
    // Implementacja pobierania arkusza
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funkcja pobierania będzie dostępna wkrótce'),
      ),
    );
  }
} 