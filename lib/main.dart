import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(MyApp());
}

class Meal {
  final String date;
  final String time;
  final String meal;

  Meal({required this.date, required this.time, required this.meal});

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'time': time,
      'meal': meal,
    };
  }
}

class DatabaseHelper {
  late Database _database;

  Future<void> initDatabase() async {
    _database = await openDatabase(
      join(await getDatabasesPath(), 'meal_database.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE meals(date TEXT, time TEXT, meal TEXT)',
        );
      },
      version: 1,
    );
  }

  Future<void> insertMeal(Meal meal) async {
    await _database.insert(
      'meals',
      meal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMeal(Meal meal) async {
    await _database.delete(
      'meals',
      where: 'date = ? AND time = ? AND meal = ?',
      whereArgs: [meal.date, meal.time, meal.meal],
    );
  }

  Future<List<Meal>> getMealsByDate(String date) async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'meals',
      where: 'date = ?',
      whereArgs: [date],
    );

    return List.generate(maps.length, (i) {
      return Meal(
        date: maps[i]['date'],
        time: maps[i]['time'],
        meal: maps[i]['meal'],
      );
    });
  }
}

class MyApp extends StatelessWidget {
  final dbHelper = DatabaseHelper();

  @override
  Widget build(BuildContext context) {
    dbHelper.initDatabase();

    return MaterialApp(
      title: 'Meal Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.greenAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.orangeAccent,
        ),
      ),
      home: MyHomePage(dbHelper: dbHelper),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final DatabaseHelper dbHelper;

  const MyHomePage({super.key, required this.dbHelper});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late DateTime selectedDate = DateTime.now();
  late String selectedDateString;
  late TextEditingController mealController;

  @override
  void initState() {
    super.initState();
    selectedDateString =
    "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}";
    mealController = TextEditingController();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        selectedDateString =
        "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}";
      });
    }
  }

  void _addMeal(String time, String meal) async {
    final newMeal = Meal(date: selectedDateString, time: time, meal: meal);
    final existingMeals =
    await widget.dbHelper.getMealsByDate(selectedDateString);

    // Find the index of the existing meal with the same time as the new meal
    final existingMealIndex =
    existingMeals.indexWhere((meal) => meal.time == time);

    if (existingMealIndex != -1) {
      // If an existing meal with the same time is found, update it with comma-separated meals
      final existingMeal = existingMeals[existingMealIndex];
      final updatedMeal = Meal(
        date: existingMeal.date,
        time: existingMeal.time,
        meal: '${existingMeal.meal}, ${newMeal.meal}',
      );
      existingMeals[existingMealIndex] = updatedMeal;
      await widget.dbHelper.insertMeal(updatedMeal);
    } else {
      await widget.dbHelper.insertMeal(newMeal);
    }

    setState(() {
      mealController.clear();
    });
  }

  void _deleteMeal(Meal meal) async {
    // Delete the meal from the database
    await widget.dbHelper.deleteMeal(meal);

    // Update the UI
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Tracker'),
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 20),
              const Text(
                'Select Date:',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => _selectDate(context),
                child: Text(
                  selectedDateString,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Add Meal:',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: mealController,
                decoration: const InputDecoration(
                  hintText: 'Enter meal',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      backgroundColor: Colors.white,
                    ),
                    onPressed: () {
                      _addMeal('Breakfast', mealController.text);
                    },
                    child: const Text('Add Breakfast'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.redAccent,
                    ),
                    onPressed: () {
                      _addMeal('Lunch', mealController.text);
                    },
                    child: Text('Add Lunch'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.yellowAccent,
                      backgroundColor: Colors.black,
                    ),
                    onPressed: () {
                      _addMeal('Dinner', mealController.text);
                    },
                    child: Text('Add Dinner'),
                  ),
                ],
              ),
              SizedBox(height: 40),
              FutureBuilder<List<Meal>>(
                future: widget.dbHelper.getMealsByDate(selectedDateString),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text('No meals recorded for this date.');
                  } else {
                    return Column(
                      children: [
                        Text(
                          'Meals for $selectedDateString:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        for (var meal in snapshot.data!)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 2,
                                  offset: Offset(0, 2), // Shadow offset
                                ),
                              ],
                            ),
                            margin: EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                              title: Text(
                                '${meal.time}: ${meal.meal}',
                                style: TextStyle(fontSize: 16),
                              ),
                              trailing: GestureDetector(
                                onTap: () => _deleteMeal(meal), // Call the delete function
                                child: Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );

                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
