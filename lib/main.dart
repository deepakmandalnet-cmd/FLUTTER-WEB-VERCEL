import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TableProvider()),
        ChangeNotifierProvider(create: (context) => AuthStateProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class AuthStateProvider with ChangeNotifier {
  User? _user;

  AuthStateProvider() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get currentUser => _user;
}


// 1. Router Configuration
GoRouter _router(AuthStateProvider authStateProvider) {
 return GoRouter(
  refreshListenable: authStateProvider,
  redirect: (BuildContext context, GoRouterState state) {
    final bool loggedIn = authStateProvider.currentUser != null;
    final bool loggingIn = state.matchedLocation == '/login';
    final bool isAdminRoute = state.matchedLocation == '/admin';

    // if user is not logged in and is trying to access admin, redirect to login
    if (!loggedIn && isAdminRoute) {
      return '/login';
    }

    // if user is logged in and is trying to access login, redirect to admin
    if (loggedIn && loggingIn) {
      return '/admin';
    }

    return null; // no redirect needed
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const MonthlyTableScreen();
      },
    ),
    GoRoute(
      path: '/admin',
      builder: (BuildContext context, GoRouterState state) {
        return const AdminScreen();
      },
    ),
    GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        })
  ],
);
}

class TableProvider with ChangeNotifier {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int _daysInMonth = 0;

  Map<String, dynamic> _tableData = {};
  bool _isLoading = true;
  StreamSubscription<DocumentSnapshot>? _dataSubscription;

  TableProvider() {
    _updateDaysInMonth();
    listenForDataChanges();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;
  int get daysInMonth => _daysInMonth;
  Map<String, dynamic> get tableData => _tableData;
  bool get isLoading => _isLoading;

  List<int> get yearList => List.generate(5, (index) => DateTime.now().year - 2 + index);
  List<String> get monthList => List.generate(12, (index) => DateFormat('MMMM').format(DateTime(0, index + 1)));

  Future<void> setDate(int year, int month) async {
    _selectedYear = year;
    _selectedMonth = month;
    _updateDaysInMonth();
    listenForDataChanges();
  }

  Future<void> goToNextMonth() async {
    if (_selectedMonth == 12) {
      _selectedMonth = 1;
      _selectedYear++;
    } else {
      _selectedMonth++;
    }
    _updateDaysInMonth();
    listenForDataChanges();
  }

  Future<void> goToPreviousMonth() async {
    if (_selectedMonth == 1) {
      _selectedMonth = 12;
      _selectedYear--;
    } else {
      _selectedMonth--;
    }
    _updateDaysInMonth();
    listenForDataChanges();
  }

  void listenForDataChanges() {
    _isLoading = true;
    notifyListeners();

    _dataSubscription?.cancel();

    final year = _selectedYear;
    final month = _selectedMonth.toString().padLeft(2, '0');
    final documentId = '$year-$month';

    _dataSubscription = FirebaseFirestore.instance
        .collection('monthly_data')
        .doc(documentId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _tableData = snapshot.data() ?? {};
      } else {
        _tableData = {};
      }
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      print("Error listening to data: $error");
      _isLoading = false;
      _tableData = {};
      notifyListeners();
    });
  }

  void _updateDaysInMonth() {
    _daysInMonth = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authStateProvider = Provider.of<AuthStateProvider>(context);
    final textTheme = Theme.of(context).textTheme;

    return MaterialApp.router(
      routerConfig: _router(authStateProvider),
      title: 'Monthly Table',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(textTheme),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MonthlyTableScreen extends StatefulWidget {
  const MonthlyTableScreen({super.key});

  @override
  State<MonthlyTableScreen> createState() => _MonthlyTableScreenState();
}

class _MonthlyTableScreenState extends State<MonthlyTableScreen> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  bool _isDisclaimerExpanded = false;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableProvider = Provider.of<TableProvider>(context);

    List<DataColumn> buildColumns() {
      List<DataColumn> columns = [
        DataColumn(
          label: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Game', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          ),
        ),
      ];
      for (int i = 1; i <= tableProvider.daysInMonth; i++) {
        columns.add(
          DataColumn(
            label: Container(
              width: 30,
              alignment: Alignment.center,
              child: Text('$i', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      }
      return columns;
    }

    List<DataRow> buildRows() {
      List<String> rowNames = ['Disawar', 'Night bazzar', 'CC colony', 'Faridabad', 'Delhi night', 'Gaziabad', 'Gali'];
      return List.generate(rowNames.length, (rowIndex) {
        final personName = rowNames[rowIndex];
        final personData = tableProvider.tableData[personName] as Map<String, dynamic>? ?? {};

        List<DataCell> cells = [
          DataCell(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(personName, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.secondary)),
            ),
          ),
        ];
        for (int i = 1; i <= tableProvider.daysInMonth; i++) {
          final day = i.toString();
          final value = personData[day] ?? '';
          cells.add(DataCell(Center(child: Text(value.toString()))));
        }
        return DataRow(cells: cells);
      });
    }

    Widget buildContent() {
      if (tableProvider.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Scrollbar(
        thumbVisibility: true,
        controller: _verticalScrollController,
        child: SingleChildScrollView(
          controller: _verticalScrollController,
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              Scrollbar(
                thumbVisibility: true,
                controller: _horizontalScrollController,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _horizontalScrollController,
                  child: DataTable(
                    border: TableBorder.all(
                      color: Colors.grey.shade300,
                      width: 1.0,
                    ),
                    headingRowColor: MaterialStateColor.resolveWith((states) => Theme.of(context).colorScheme.primary.withOpacity(0.1)),
                    dataRowColor: MaterialStateColor.resolveWith((states) => Colors.white),
                    columnSpacing: 10.0,
                    columns: buildColumns(),
                    rows: buildRows(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Disclaimer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '''This website is for informational and entertainment purposes only.
We do not promote, support, or encourage any form of gambling, betting, or illegal activities.

All the information, results, and charts provided on this website are based on publicly available data and are shown for reference only.

We are not responsible for any loss, damage, or legal consequences arising from the use of information available on this website.

Users are advised to follow the laws of their respective states/countries.
If gambling is illegal in your area, please leave this website immediately.

By using this website, you agree that you are accessing the content at your own risk and responsibility.''',
                      textAlign: TextAlign.center,
                      maxLines: _isDisclaimerExpanded ? null : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isDisclaimerExpanded = !_isDisclaimerExpanded;
                        });
                      },
                      child: Text(
                        _isDisclaimerExpanded ? 'Read Less' : 'Read More...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'PLAY NIGHT BAZZAR',
                      style: GoogleFonts.oswald(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3.0,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      'MONTHLY RESULT CHART',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_left_rounded),
                          onPressed: () => tableProvider.goToPreviousMonth(),
                          tooltip: 'Previous Month',
                        ),
                        Row(
                          children: [
                            DropdownButton<int>(
                              value: tableProvider.selectedYear,
                              onChanged: (int? newValue) {
                                if (newValue != null) {
                                  tableProvider.setDate(newValue, tableProvider.selectedMonth);
                                }
                              },
                              items: tableProvider.yearList.map<DropdownMenuItem<int>>((int value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text(value.toString()),
                                );
                              }).toList(),
                              underline: const SizedBox(),
                            ),
                            const SizedBox(width: 16),
                            DropdownButton<int>(
                              value: tableProvider.selectedMonth,
                              onChanged: (int? newValue) {
                                if (newValue != null) {
                                  tableProvider.setDate(tableProvider.selectedYear, newValue);
                                }
                              },
                              items: List.generate(12, (index) {
                                return DropdownMenuItem<int>(
                                  value: index + 1,
                                  child: Text(tableProvider.monthList[index]),
                                );
                              }),
                              underline: const SizedBox(),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_right_rounded),
                          onPressed: () => tableProvider.goToNextMonth(),
                          tooltip: 'Next Month',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.grey),
            Expanded(
              child: buildContent(),
            ),
          ],
        ),
      ),
    );
  }
}

// Login Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _isSigningIn = false;

  Future<void> _signIn() async {
    if (mounted) {
      setState(() {
        _isSigningIn = true;
      });
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // The router's redirect logic will handle navigation
    } on FirebaseAuthException catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
            content: Text('Failed to sign in: ${e.message}'),
            backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
                Theme.of(context).colorScheme.secondary.withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                margin: const EdgeInsets.all(24.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Admin Login', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 32),
                      _isSigningIn ? const CircularProgressIndicator() : _buildSignInButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return InkWell(
      onTap: _signIn,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Sign In',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// Admin Screen
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // For Form
  final _formKey = GlobalKey<FormState>();
  final List<String> _playerNames = ['Anil', 'Sunil', 'Raju', 'Suresh', 'Ramesh', 'Vikas', 'Prakash'];
  String? _selectedPlayer;
  DateTime _selectedDate = DateTime.now();
  final _numberController = TextEditingController();
  bool _isSubmitting = false;

  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _selectedPlayer = _playerNames.first;
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Colors.black, // body text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitData() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      final year = _selectedDate.year;
      final month = _selectedDate.month.toString().padLeft(2, '0');
      final day = _selectedDate.day.toString();

      final documentId = '$year-$month';
      final player = _selectedPlayer!;
      final number = _numberController.text;

      try {
        final docRef = FirebaseFirestore.instance.collection('monthly_data').doc(documentId);
        await docRef.set({player: {day: number}}, SetOptions(merge: true));

        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
              content: Text('Data submitted successfully!'),
              backgroundColor: Colors.green),
        );
        _numberController.clear();
      } catch (e) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
              content: Text('Error submitting data: $e'),
              backgroundColor: Colors.redAccent),
        );
      }

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Admin Panel - ${user?.email ?? ''}', style: const TextStyle(fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 1,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: _signOut,
              tooltip: 'Sign Out',
            )
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade50,
                Colors.purple.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Card(
                   elevation: 12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Enter New Data',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 32),
                          // Player Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedPlayer,
                            decoration: const InputDecoration(
                                labelText: 'Player',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                                border: OutlineInputBorder()),
                            items: _playerNames.map((String player) {
                              return DropdownMenuItem<String>(
                                value: player,
                                child: Text(player),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedPlayer = newValue!;
                              });
                            },
                            validator: (value) =>
                                value == null ? 'Please select a player' : null,
                          ),
                          const SizedBox(height: 20),
                          // Date Picker
                          ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.grey.shade400)),
                            leading: const Icon(Icons.calendar_today_outlined),
                            title:
                                Text('Date: ${DateFormat.yMMMd().format(_selectedDate)}'),
                            onTap: () => _selectDate(context),
                          ),
                          const SizedBox(height: 20),
                          // Number Input
                          TextFormField(
                            controller: _numberController,
                            decoration: const InputDecoration(
                                labelText: 'Number',
                                prefixIcon: Icon(Icons.format_list_numbered_rounded),
                                border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          // Submit Button
                          _isSubmitting
                              ? const Center(child: CircularProgressIndicator())
                              : _buildSubmitButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return InkWell(
      onTap: _submitData,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [
              Colors.indigo.shade400,
              Colors.purple.shade400,
            ],
          ),
           boxShadow: [
            BoxShadow(
              color: Colors.indigo.withOpacity(0.4),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.save_alt_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Submit Data',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
