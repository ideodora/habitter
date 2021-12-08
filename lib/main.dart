import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:oauth1/oauth1.dart' as oauth1;
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uni_links/uni_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'repositories/stats_repository.dart';
import 'repositories/counter_repository.dart';

void main() async {
  await dotenv.load(fileName: ".env");

  WidgetsFlutterBinding.ensureInitialized();

  // Open the database and store the reference.
  final database = openDatabase(
    // Set the path to the database. Note: Using the `join` function from the
    // `path` package is best practice to ensure the path is correctly
    // constructed for each platform.
    path.join(await getDatabasesPath(), 'doggie_database.db'),
    // When the database is first created, create a table to store dogs.
    onCreate: (db, version) {
      // Run the CREATE TABLE statement on the database.
      return db.execute(
        'CREATE TABLE dogs(id INTEGER PRIMARY KEY, name TEXT, age INTEGER)',
      );
    },
    // Set the version. This executes the onCreate function and provides a
    // path to perform database upgrades and downgrades.
    version: 1,
  );

  // Define a function that inserts dogs into the database
  Future<void> insertDog(Dog dog) async {
    // Get a reference to the database.
    final db = await database;

    // Insert the Dog into the correct table. You might also specify the
    // `conflictAlgorithm` to use in case the same dog is inserted twice.
    //
    // In this case, replace any previous data.
    await db.insert(
      'dogs',
      dog.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // A method that retrieves all the dogs from the dogs table.
  Future<List<Dog>> dogs() async {
    // Get a reference to the database.
    final db = await database;

    // Query the table for all The Dogs.
    final List<Map<String, dynamic>> maps = await db.query('dogs');

    // Convert the List<Map<String, dynamic> into a List<Dog>.
    return List.generate(maps.length, (i) {
      return Dog(
        id: maps[i]['id'],
        name: maps[i]['name'],
        age: maps[i]['age'],
      );
    });
  }

  Future<void> updateDog(Dog dog) async {
    // Get a reference to the database.
    final db = await database;

    // Update the given Dog.
    await db.update(
      'dogs',
      dog.toMap(),
      // Ensure that the Dog has a matching id.
      where: 'id = ?',
      // Pass the Dog's id as a whereArg to prevent SQL injection.
      whereArgs: [dog.id],
    );
  }

  Future<void> deleteDog(int id) async {
    // Get a reference to the database.
    final db = await database;

    // Remove the Dog from the database.
    await db.delete(
      'dogs',
      // Use a `where` clause to delete a specific dog.
      where: 'id = ?',
      // Pass the Dog's id as a whereArg to prevent SQL injection.
      whereArgs: [id],
    );
  }

  // Create a Dog and add it to the dogs table
  var fido = Dog(
    id: 0,
    name: 'Fido',
    age: 35,
  );

  await insertDog(fido);

  // Now, use the method above to retrieve all the dogs.
  print(await dogs()); // Prints a list that include Fido.

  // Update Fido's age and save it to the database.
  fido = Dog(
    id: fido.id,
    name: fido.name,
    age: fido.age + 7,
  );
  await updateDog(fido);

  // Print the updated results.
  print(await dogs()); // Prints Fido with age 42.

  // Delete Fido from the database.
  await deleteDog(fido.id);

  // Print the list of dogs (empty).
  print(await dogs());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(
          title: 'Flutter Demo Home Page', storage: CounterStorage()),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title, required this.storage})
      : super(key: key);

  final String title;

  final CounterStorage storage;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  final controller = TextEditingController();
  final platform = oauth1.Platform(
    'https://api.twitter.com/oauth/request_token',
    'https://api.twitter.com/oauth/authorize',
    'https://api.twitter.com/oauth/access_token',
    oauth1.SignatureMethods.hmacSha1,
  );
  final clientCredentials = oauth1.ClientCredentials(
    dotenv.env['CLIENT_TOKEN']!,
    dotenv.env['CLIENT_TOKEN_SECRET']!,
  );
  late final auth = oauth1.Authorization(clientCredentials, platform);
  oauth1.Credentials? tokenCredentials;

  late String _state;
  late StreamSubscription<Uri?> _subscription;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  void initState() {
    super.initState();

    _state = _randomString(40);
    _subscription = uriLinkStream.listen((Uri? uri) {
      if (uri?.host == 'appa') {
        _onAuthorizeCallbackIsCalled(uri);
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
          child: Container(
              color: Colors.amber,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ElevatedButton(
                        onPressed: () async {
                          auth
                              .requestTemporaryCredentials('app://appa')
                              .then((res) {
                            tokenCredentials = res.credentials;
                            launch(auth.getResourceOwnerAuthorizationURI(
                                tokenCredentials!.token));
                          });
                        },
                        child: const Text('Login')),
                    Container(
                        margin: const EdgeInsets.all(10.0),
                        height: 200,
                        decoration: BoxDecoration(
                            color: Colors.blue[600],
                            border: Border.all(color: Colors.blue, width: 1)),
                        child: Container(
                            margin: const EdgeInsets.all(10.0),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                            ),
                            child: SingleChildScrollView(
                              child: TextFormField(
                                controller: controller,
                                keyboardType: TextInputType.multiline,
                                maxLines: null,
                                minLines: 4,
                                decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(8.0)),
                              ),
                            ))),
                    ElevatedButton(
                        onPressed: () async {
                          final inputText = controller.text;
                          controller.clear();

                          oauth1.Credentials? userCredentials =
                              await widget.storage.readToken();

                          if (userCredentials == null) {
                            return;
                          }

                          final client = oauth1.Client(platform.signatureMethod,
                              clientCredentials, userCredentials);

                          Map<String, String> headers = {
                            'content-type': 'application/json'
                          };
                          String body = json.encode({'text': inputText});

                          final apiResponse = await client.post(
                              Uri.https('api.twitter.com', '/2/tweets'),
                              headers: headers,
                              body: body);
                          print(apiResponse.body);
                        },
                        child: const Text('OK')),
                    const Text(
                      'You have clicked the button this many times:',
                    ),
                    Text(
                      '$_counter',
                      style: Theme.of(context).textTheme.headline4,
                    ),
                  ],
                ),
              ))),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _onAuthorizeCallbackIsCalled(Uri? uri) async {
    closeWebView();

    final params = Uri.splitQueryString(uri!.query);
    String oauthVerifier = params['oauth_verifier']!;

    final res =
        await auth.requestTokenCredentials(tokenCredentials!, oauthVerifier);
    print('Access Token: ${res.credentials.token}');
    print('Access Toekn secred: ${res.credentials.tokenSecret}');

    await widget.storage.writeToken(res.credentials);

    // final accessToken =
    //     await repository.createAccessTokenFromCallbackUri(uri, _state);
    // await repository.saveAccessToken(accessToken);

    // Navigator.of(context).pushReplacement(
    //   MaterialPageRoute(builder: (_) => ItemListScreen()),
    // );
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    final codeUnits = List.generate(length, (index) {
      final n = rand.nextInt(chars.length);
      return chars.codeUnitAt(n);
    });
    return String.fromCharCodes(codeUnits);
  }
}
