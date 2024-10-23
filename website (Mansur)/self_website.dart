import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';




class Coordinates {
  //final int zeit
  final double latitude;
  final double longitude;

  const Coordinates({
    //required this.zeit,
    required this.latitude,
    required this.longitude,
  });

  factory Coordinates.fromJson(Map<String, dynamic> json) {
    return Coordinates(
      //zeit: json['Zeit'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class Flavor {
  late String name;
  late double price;
  late String ingredients;
  late String image;
  late int available;
  late Color color;

  Flavor({
    required this.name,
    required this.price,
    required this.ingredients,
    required this.image,
    required this.available,
    required this.color
  });

  factory Flavor.fromJson(Map<String, dynamic> json) {
    return Flavor(
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      ingredients: json['ingredients'] as String,
      image: json['picFilePath'] as String,
      available: json['available'] as int,
      color: Color(int.parse(json['color']))
    );
  }
}

String address = "https://82.194.143.119";

Future<Coordinates> fetchCoordinates() async {
  final response = await http.get(Uri.parse('$address/coordinates'));
  print(response.body);
  if (response.statusCode == 200) {
    // Decode the response body as a list
    List<dynamic> responseBody = jsonDecode(response.body);
    
    // Check if the response body is not empty
    if (responseBody.isNotEmpty) {
      // Use the first item in the list as the coordinate data
      Map<String, dynamic> firstCoordinatesData = responseBody.first;
      
      // Return the first coordinates
      return Coordinates.fromJson(firstCoordinatesData as Map<String, dynamic>);
    } else {
      throw Exception('Coordinates list is empty');
    }
  } else {
    throw Exception('Failed to load coordinates');
  }
}

List<Flavor> parseFlavors(String responseBody) {
  final parsed = (jsonDecode(responseBody) as List).cast<Map<String, dynamic>>();
  return parsed.map<Flavor>((json) => Flavor.fromJson(json)).toList();
}

Future<List<Flavor>> fetchFlavors(http.Client client) async {
  final response = await client.get(Uri.parse('$address/flavors'));
  print(response);

  return compute(parseFlavors, response.body);
}

void main() {
  runApp(const MainApp());
}


class MainApp extends StatelessWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Eis_Monitoring",
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: kIsWeb? ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 247, 229, 124)) : 
                             ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 255, 254, 230)),
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var selectedIndex = 0;
  Widget? page;

  @override
  Widget build(BuildContext context) {
    
    switch (selectedIndex) {
      case 0:
        page = FlavorPage();
        break;
      case 1:
        page = MapPage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: kIsWeb? webMenu(context, constraints) : androidMenu(context, constraints),
        );
      },
    );
  }
  Widget webMenu(BuildContext context, BoxConstraints constraints){
      return Row(
      children: [
        SafeArea(
          child: NavigationRail(
            extended: constraints.maxWidth >= 600,
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.icecream),
                label: Text('Verfügbare Sorten'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.map),
                label: Text('Zur Karte'),
              ),
            ],
            selectedIndex: selectedIndex,
            onDestinationSelected: (value) {
              setState(() {
                selectedIndex = value;
              });
            },
          ),
        ),
        Expanded(
          child: Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: page,
          ),
        ),
      ],
    );
  }

  Widget androidMenu(BuildContext context, BoxConstraints constraints){
    return Scaffold(
      body: page,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.icecream),
            label: 'Verfügbare Sorten',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Zur Karte',
          ),
        ],
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
    );
  }

}

class FlavorPage extends StatefulWidget{
  @override
  State<FlavorPage> createState() => _FlavorPageState();
}

class _FlavorPageState extends State<FlavorPage> {
  @override
  Widget build(BuildContext context){
    return FutureBuilder<List<Flavor>>(
        future: fetchFlavors(http.Client()),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('An error has occurred!'),
            );
          } else if (snapshot.hasData) {
            return FlavorsList(flavors: snapshot.data!);
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      );
  }
}

class FlavorsList extends StatelessWidget {
  const FlavorsList({Key? key, required this.flavors}) : super(key: key);

  final List<Flavor> flavors;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];
    final List<Widget> availableFlavors = [];
    final List<Widget> unavailableFlavors = [];

    flavors.forEach((Flavor flavor) {
      Color tileColor = flavor.color;
      Color textColor =
          tileColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

      ExpansionTile tile = ExpansionTile(
        title: Text(flavor.name, style: TextStyle(color: textColor)),
        subtitle:
            Text('${flavor.price.toStringAsFixed(2)} €', style: TextStyle(color: textColor)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Zutaten: ${flavor.ingredients}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textColor),
                  ),
                ),
              ],
            ),
          ),
        ],
        leading: Container(
          width: 100,
          height: 100,
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.center,
              child: SizedBox(
                width: 100, // Same as container width
                height: 100, // Same as container height
                child: CachedNetworkImage(
                  imageUrl: "$address/${flavor.image}",
                  placeholder: (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
          ),
        ),
        backgroundColor: tileColor,
        collapsedBackgroundColor: tileColor,
      );

      if (flavor.available == 1) {
        availableFlavors.add(tile);
      } else {
        unavailableFlavors.add(tile);
      }
    });

    children.add(
      ListTile(
        title: Center(child: Text("Verfügbare Sorten")),
      ),
    );

    children.addAll(availableFlavors);

    children.add(
      ListTile(
        title: Center(child: Text("Leere Sorten")),
      ),
    );

    children.addAll(unavailableFlavors);

    return ListView(
      children: children,
    );
  }
}


class MapPage extends StatefulWidget{
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late Future<Coordinates> futureCoordinates;
  late GoogleMapController mapController;
  late double lat;
  late double lng;
  final Set<Marker> markers = {};
  final Set<Marker> fetchedMarkers = {};
  final Set<Polyline> polylines = {};
  final List<String> markerIds = []; // List tracking markers already added before the map was opened
  final List<LatLng> polylineCoordinates = [];

  late Timer _timer;
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }


  @override
  void initState() {
    super.initState();
    _loadData();
    futureCoordinates = fetchCoordinates();
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (mounted){
        setState(() {
          futureCoordinates = fetchCoordinates();
        });
      }

    });
  }

  Future<void> _loadData() async {
    try {
      final response = await http.get(Uri.parse('$address/route'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        data.forEach((markerData) {
          final LatLng position = LatLng(
            markerData['latitude'],
            markerData['longitude'],
          );
          final String markerId = markerData['id'];
          fetchedMarkers.add(
            Marker(
              markerId: MarkerId(markerId),
              position: position,
            ),
          );
          markerIds.add(markerId);
        });
        updatePolylineCoordinates();
      } else {
        throw Exception('Failed to load data');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
        ),
      );
    }
  }

  void updatePolylineCoordinates() {
    polylineCoordinates.clear();
    for (String markerId in markerIds) {
      final Marker marker = fetchedMarkers.firstWhere(
        (marker) => marker.markerId.value == markerId,
      );
      polylineCoordinates.add(marker.position);
    }
    updatePolyline();
  }

  void updatePolyline() {
    setState(() {
      if (polylineCoordinates.isNotEmpty) {
        polylines.clear();
        polylines.add(
          Polyline(
            polylineId: PolylineId('poly'),
            points: List<LatLng>.from(polylineCoordinates),
            color: Colors.blue,
            width: 3,
          ),
        );
      }
    });
  }


  @override
  Widget build(BuildContext context){
    return FutureBuilder<Coordinates>(
      future: futureCoordinates,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
            lat = snapshot.data!.latitude;
            lng = snapshot.data!.longitude;
            markers.add(Marker(
                    markerId: const MarkerId('Standort'),
                    position: LatLng(lat, lng),
              ));

            return GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: LatLng(lat, lng),
                zoom: 12.0,
              ),
              markers: markers,
              polylines: polylines,
            );
          }
        else if (snapshot.hasError) {
            return Text('Die Karte ist derzeit nicht verfügbar');
          }
        else{
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}