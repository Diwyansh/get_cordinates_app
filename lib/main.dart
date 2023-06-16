import 'dart:async';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Get Coordinates App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Get Coordinates CSV'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  List<List> coordinatesData = [["DateTime", "Longitude", "Latitude"]];

  @override
  void initState() {
    FlutterBackgroundService().on("localData").listen((event) {
      coordinatesData.add(event!["localData"]);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
           const Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Text(
                'Please tap on the following available buttons to\nStart or Stop location service',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),
              ),
            ),
            ButtonBar(alignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: (){
                  enableBackgroundService();
                }, child: const Text("Start")
                ),
                ElevatedButton(
                    onPressed: () async {

                      final dir = await getApplicationDocumentsDirectory();

                      String path = dir.path;

                      File file = File("$path/coordinates.csv");

                      final csv = ListToCsvConverter().convert(coordinatesData);

                      file.writeAsString(csv);

                      FlutterBackgroundService().invoke("stop");

                }, child:const Text("End")
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }

  return await Geolocator.getCurrentPosition();
}

final service = FlutterBackgroundService();

Future<void> enableBackgroundService() async {

  await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onBackground: onBackground,
        onForeground: onStart,
      ),
      androidConfiguration: AndroidConfiguration(
        autoStart: true,
          autoStartOnBoot: true,
          onStart: onStart,
        isForegroundMode: true,
      )
  );
}

@pragma('vm:entry-point')
onStart(ServiceInstance serviceInstance) {

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      final data = await _determinePosition();
      List<String> localData = [];
      localData.add("${DateTime.now()}");
      localData.add("${data.longitude}");
      localData.add("${data.latitude}");

      serviceInstance.invoke("localData", {"localData" : localData});
    });

    serviceInstance.on("stop").listen((event) {
      serviceInstance.stopSelf();
    });
}

@pragma('vm:entry-point')
bool onBackground(ServiceInstance serviceInstance) {

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    final data = await _determinePosition();
    List<String> localData = [];
    localData.add("${DateTime.now()}");
    localData.add("${data.longitude}");
    localData.add("${data.latitude}");

    serviceInstance.invoke("localData", {"localData" : localData});
  });
  return true;
}