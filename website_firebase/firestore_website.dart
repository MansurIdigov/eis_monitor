import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';




Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
    // Disable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
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
  final Stream<QuerySnapshot> _sortenStream =
      FirebaseFirestore.instance.collection('flavors').snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _sortenStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return Text('Something went wrong');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final List<Widget> children = [];
        final List<Widget> availableFlavors = [];
        final List<Widget> unavailableFlavors = [];

        snapshot.data!.docs.forEach((DocumentSnapshot document) {
          Map<String, dynamic> data = document.data() as Map<String, dynamic>;
          Color tileColor = Color(int.parse(data['color']));
          Color textColor = tileColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
          ExpansionTile tile = ExpansionTile(
            title: Text(document.id, style: TextStyle(color: textColor)),
            subtitle: Text('${data['price'].toStringAsFixed(2)} €', style: TextStyle(color: textColor)),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Zutaten: ${data['ingredients']}',
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
                      imageUrl: data['picUrl'],
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

          if (data['available']) {
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
      },
    );
  }
}
class MapPage extends StatefulWidget{
  @override
  State<MapPage> createState() => _MapPageState();
}


class _MapPageState extends State<MapPage> {
  late GoogleMapController mapController;
  final Stream<QuerySnapshot> _locationStream =
      FirebaseFirestore.instance.collection('coordinates').snapshots();
  final Stream<QuerySnapshot> _routeStream =
      FirebaseFirestore.instance.collection('route').snapshots();
  late BitmapDescriptor userIcon;
  late GeoPoint userLocation;
  Set<Marker> markers={};
  Set<Circle> circles = {};
  GeoPoint? posOld;

  @override
  void initState() {
    super.initState();
  }

  Future setCustomIcons() async {
    userIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(12, 12)),
      'assets/images/user.png',
    );
  }
  
    static Future<Position> _getCurrentLocation() async {
    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw Exception('Location permission not granted');
      }
    }
    
    // Get current location
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    return position;
  }

  void getCurrentLocation() async{
    Position pos = await _getCurrentLocation();
    userLocation = GeoPoint(pos.latitude, pos.longitude);
    setState(() {
      circles.add(Circle(
              circleId: CircleId("fdad"),
              center: LatLng(userLocation.latitude, userLocation.longitude),
              radius: 5,
              fillColor: Color.fromARGB(255, 0, 145, 255),
              strokeColor: Color.fromARGB(255, 0, 145, 255)
      ));
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _locationStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot1) {
        if (snapshot1.hasError) {
          return const Text('Something went wrong');
        }

        if (snapshot1.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot1.hasData || snapshot1.data!.docs.isEmpty) {
          return Center(child: Text("Derzeit sind keine Koordinaten verfügbar!"),);
        }
        final data1 = snapshot1.data!.docs.last.data()! as Map<String, dynamic>;
        GeoPoint pos = data1['position'];
        markers.add(Marker(markerId: const MarkerId('Standort'), position: LatLng(pos.latitude, pos.longitude)));
        if(posOld != pos){
          posOld = pos;
          getCurrentLocation();
        }


        return StreamBuilder<QuerySnapshot>(
          stream: _routeStream,
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot2) {
            if (snapshot2.hasError) {
              return const Text('Something went wrong');
            }
            else{
            // Extract route coordinates from Firestore snapshot
            List<LatLng> routeCoords = [];
            snapshot2.data!.docs.forEach((DocumentSnapshot document) {
              Map<String, dynamic> data2 = document.data() as Map<String, dynamic>;
              GeoPoint point = data2['position'];
              routeCoords.add(LatLng(point.latitude, point.longitude));
            });

            // Define polyline options
            Set<Polyline> polylines = Set<Polyline>.from([
              Polyline(
                polylineId: PolylineId('route'),
                points: routeCoords,
                color: Colors.blue,
                width: 3,
              ),
            ]);

            GoogleMap googleMap = GoogleMap(
              onMapCreated: _onMapCreated,
              polylines: polylines,
              initialCameraPosition: CameraPosition(
                target: LatLng(pos.latitude, pos.longitude),
                zoom: 16.0,
              ),
              markers: markers,
              circles: circles,);

            return SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: googleMap,
            );
          }
          }
        );
      },
    );
  }
}