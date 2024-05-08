import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();              // Widget bindings must be initialized before Firestore
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.android,      // Use Options from android
  );
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);   // Disable caching of Firestore data
  runApp(const Eisverkauf());
}

class Eisverkauf extends StatelessWidget {
  const Eisverkauf({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eis',
      theme: ThemeData(
        primaryColor: Colors.white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Arial',
      ),
      home: IceCreamPage(),
      debugShowCheckedModeBanner: false,         // Disable banner during debugging
    );
  }
}

class IceCreamPage extends StatefulWidget {
  @override
  _IceCreamPageState createState() => _IceCreamPageState();
}

class _IceCreamPageState extends State<IceCreamPage> {
  List<Flavor> availableFlavors = [];
  List<Flavor> unavailableFlavors = [];  

  @override
    void initState(){
      super.initState();
    }
  
  // Function to load images before they are used
  Future<void> _preloadImage(String imageUrl) async {                   
    await precacheImage(CachedNetworkImageProvider(imageUrl), context);    
  }

  // Function to unload images when a flavor's image is deleted
  Future<void> _unloadImage(String imageUrl) async {                    
    await DefaultCacheManager().removeFile(imageUrl);
  }


  final ImagePicker _imagePicker = ImagePicker();

  Future<void> addFlavor(Flavor flavor) async {
    // Preparing variables for image storage
    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final String picName = '${time}.jpg';
    final firebase_storage.Reference storageRef =
        firebase_storage.FirebaseStorage.instance.ref().child('flavor_images').child(picName);
    String imageUrl = "";

    // Displaying Snackbar to indicate flavor addition process starts
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sorte wird hinzugefügt...'),
        duration: Duration(seconds: 1), 
      ),
    );

    try {
      // Storing image with current time as filename
      await storageRef.putFile(File(flavor.image));
      imageUrl = await storageRef.getDownloadURL();

      // Adding flavor data to Firestore
      await FirebaseFirestore.instance.collection('flavors').doc(flavor.name).set({
        'price': flavor.price,
        'ingredients': flavor.ingredients,
        'available': flavor.available,
        'picUrl': imageUrl,
        'picName': picName,
        'color': flavor.color.value.toString(), // Save color as hex string
      });

      // Displaying success Snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sorte erfolgreich hinzugefügt!'),
          duration: Duration(seconds: 1), 
        ),
      );
    } catch (e) {
      print('Error adding flavor: $e');

      // Displaying error Snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sorte konnte nicht hinzugefügt werden!'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    _preloadImage(imageUrl);
  }

Future<void> updateFlavor(Flavor flavor, String name, double price, String ingredients, String imageNew, Color color) async {
  try {
    // Define variables for image outside of check, being redifned if a new image has been selected
    String imageUrl = flavor.image;
    String picName = flavor.picName;   

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sorte wird geändert...'),
        duration: Duration(seconds: 1),
      ),
    );
    if (flavor.image != imageNew) {  // Check if new image has been selected
      // Set new image name and delete old image if name and image are being changed
      if (flavor.name != name) {
        firebase_storage.Reference storageRef =
          firebase_storage.FirebaseStorage.instance.ref().child('flavor_images').child(flavor.picName);
        storageRef.delete(); 
        final time = DateTime.now().millisecondsSinceEpoch.toString();
        picName = '${time}.jpg';
      }
      firebase_storage.Reference storageRef =
          firebase_storage.FirebaseStorage.instance.ref().child('flavor_images').child(picName);
      await storageRef.putFile(File(imageNew));
      imageUrl = await storageRef.getDownloadURL();
      await _unloadImage(flavor.image);     // Unload old image
    }

    // Overwrite old document if name wasn't changed, create new document if it was
    await FirebaseFirestore.instance.collection('flavors').doc(name).set({  
      'price': price,
      'ingredients': ingredients,
      'available': flavor.available,
      'picUrl': imageUrl,
      'picName': picName,
      'color': color.value.toString(), // Save color as hex string
    });

    if (flavor.name != name) {  // Delete old document if name was changed
      await FirebaseFirestore.instance.collection('flavors').doc(flavor.name).delete();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Die Sorte wurde erfolgreich geändert!'),
        duration: Duration(seconds: 1), 
      ),
    );
  } catch (e) {
    print('Error editing flavor: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Die Sorte konnte nicht geändert werden!'),
        duration: Duration(seconds: 2), 
      ),
    );
  }
}


void FlavorWindow(BuildContext context) async {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController ingredientsController = TextEditingController();
  XFile? pickedImage;
  Color selectedColor = Colors.white; // Initialize with default color

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Sorte hinzufügen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: priceController,
                decoration: InputDecoration(labelText: 'Preis'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: ingredientsController,
                decoration: InputDecoration(labelText: 'Zutaten'),
              ),
              Row(
                children: [
                  Text('Farbe: '),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Wähle eine Farbe'),
                            content: SingleChildScrollView(
                              child: ColorPicker(
                                pickerColor: selectedColor,
                                onColorChanged: (Color color) {
                                  setState(() {
                                    selectedColor = color;
                                  });
                                },
                                showLabel: true,
                                pickerAreaHeightPercent: 0.8,
                                enableAlpha: false,          // Disable alpha value
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              if (pickedImage != null)
                Image.file(
                  File(pickedImage!.path),
                  height: 100,
                ),
              ElevatedButton(
                onPressed: () async {
                  final XFile? pickedFile = await _imagePicker.pickImage(
                    source: ImageSource.gallery,
                  );
                  setState(() {
                    pickedImage = pickedFile;
                  });
                },
                child: Text('Bild auswählen'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              final String name = nameController.text.trim();
              final String priceText = priceController.text.trim();
              final String ingredientsText = ingredientsController.text.trim();
              if (name.isNotEmpty &&
                  priceText.isNotEmpty &&
                  ingredientsText.isNotEmpty) {
                final double? price = double.tryParse(priceText);
                if (price != null) {
                  final String ingredients = ingredientsText;

                  if (pickedImage != null) {
                    final Flavor newFlavor = Flavor(
                      name: name,
                      price: price,
                      ingredients: ingredients,
                      image: pickedImage!.path,
                      available: true,
                      picName: "",
                      color: selectedColor,
                    );

                    addFlavor(newFlavor);
                    Navigator.pop(context);
                  } else {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Fehler'),
                          content: Text('Bitte ein Bild auswählen.'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                } else {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Fehler'),
                        content: Text('Der Preis muss eine Zahl sein.'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                }
              } else {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Fehler'),
                      content: Text('Bitte alles ausfüllen.'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('OK'),
                        ),
                      ],
                    );
                  },
                );
              }
            },
            child: Text('Hinzufügen'),
          ),
        ],
      );
    },
  );
}

void editFlavor(BuildContext context, Flavor flavor) async {
  final TextEditingController nameController =
      TextEditingController(text: flavor.name);
  final TextEditingController priceController =
      TextEditingController(text: flavor.price.toString());
  final TextEditingController ingredientsController =
      TextEditingController(text: flavor.ingredients);
  XFile? pickedImage = flavor.image.isNotEmpty ? XFile(flavor.image) : null;
  Color selectedColor = flavor.color; // Initialize with flavor's color

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Sorte bearbeiten'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pickedImage != null)
                CachedNetworkImage(imageUrl: flavor.image, height: 100), 
              ElevatedButton(
                onPressed: () async {
                  final XFile? pickedFile = await _imagePicker.pickImage(
                    source: ImageSource.gallery,
                  );
                  setState(() {
                    pickedImage = pickedFile;
                  });
                },
                child: Text('Bild auswählen'),
              ),
              Row(
                children: [
                  Text('Farbe: '),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Wähle eine Farbe'),
                            content: SingleChildScrollView(
                              child: ColorPicker(
                                pickerColor: selectedColor,
                                onColorChanged: (Color color) {
                                  setState(() {
                                    selectedColor = color;
                                  });
                                },
                                showLabel: true,
                                pickerAreaHeightPercent: 0.8,
                                enableAlpha: false,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: priceController,
                decoration: InputDecoration(labelText: 'Preis'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: ingredientsController,
                decoration: InputDecoration(labelText: 'Zutaten'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              final String name = nameController.text;
              final double? price = double.tryParse(priceController.text);
              if (price != null) {
                final String ingredients = ingredientsController.text;
                updateFlavor(flavor, name, price, ingredients, (pickedImage?.path ?? '').toString(), selectedColor);
                Navigator.pop(context);
              } else {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Fehler'),
                      content: Text('Der Preis muss eine Zahl sein.'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('OK'),
                        ),
                      ],
                    );
                  },
                );
              }
            },
            child: Text('Speichern'),
          ),
          TextButton(
            onPressed: () {
              try{
                // Delete image from storage
                firebase_storage.Reference storageRef =
                  firebase_storage.FirebaseStorage.instance.ref().child('flavor_images').child(flavor.picName);
                storageRef.delete();
                // Delete flavor's document
                FirebaseFirestore.instance.collection('flavors').doc(flavor.name).delete();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Die Sorte wurde gelöscht!'),
                      duration: Duration(seconds: 1)
                    ),
                  );
                } catch (e) {
                  print('Error deleting flavor: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Die Sorte konnte nicht gelöscht werden!'),
                      duration: Duration(seconds: 2)
                    ),
                  );
                }

              Navigator.pop(context);
            },
            child: Text('Löschen'),
          ),
        ],
      );
    },
  );
}

  void moveFlavor(Flavor Flavor, bool toAvailable) async {
    await FirebaseFirestore.instance.collection('flavors').doc(Flavor.name).set({
    'price': Flavor.price,
    'ingredients': Flavor.ingredients,
    'available': !Flavor.available,   // Set document with current data but with inverted availablitiy
    'picUrl': Flavor.image,
    'picName': Flavor.picName,
    'color': Flavor.color.value.toString(),
    });
  }

  void toMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapScreen())
    );
  }

  @override
  Widget build(BuildContext context) {
  availableFlavors.sort((a, b) => a.name.compareTo(b.name));
  unavailableFlavors.sort((a, b) => a.name.compareTo(b.name));
  
  return StreamBuilder<QuerySnapshot>(           // Stream for automatic refresh when collection changes
    stream: FirebaseFirestore.instance.collection('flavors').snapshots(),
    builder: (context, snapshot) {
      // Show loading screen until data has been received
      if (!snapshot.hasData){
        return IntroScreen();      
      }
      else{
        availableFlavors=[];
        unavailableFlavors=[];   // Reset lists of flavors and readd them
        final List<DocumentSnapshot> documents = snapshot.data!.docs;
        bool isCorrupt = false;   // Variable in case something is wrong with a document in the collection

        // Loop through the documents and add them as flavors
        documents.forEach((document) {
          final Map<String, dynamic> data = document.data() as Map<String, dynamic>;

          // Check if the document is corrupt
          if (data['price'] == null ||
              data['ingredients'] == null ||
              data['available'] == null ||
              data['picUrl'] == null ||
              data['picName'] == null ||
              data['color'] == null) {
            isCorrupt = true;
          }

          // If not corrupt, populate the Flavor object with data from the document
          late Flavor newFlavor;
          if (!isCorrupt) {
            newFlavor = Flavor(
              name: document.id,
              price: data['price'].toDouble(),
              ingredients: data['ingredients'],
              available: data['available'],
              image: data['picUrl'],
              picName: data['picName'],
              color: Color(int.parse(data['color'])),
            );
            if (newFlavor.available == true) {     // add flavor to lists, depends on availablity
              availableFlavors.add(newFlavor);
            } else {
              unavailableFlavors.add(newFlavor);
            }
            // load flavor's image, is skipped if it already has been before reload
            _preloadImage(newFlavor.image);        
          }
        });
        // If a flavor is corrupt, ask to delete the collection, should only pop up in worst-case scenario
        if(isCorrupt){
          return AlertDialog(
                title: Text("Corrupt Collection"),
                content: Text("Die Sammlung ist korrupt und muss neu erstellt werden. ACHTUNG: Dadurch werden alle Sorten gelöscht! Die App muss danach neu gestartet werden!"),
                actions: <Widget>[
                  TextButton(
                    onPressed: () async {
                    // Get all documents in the collection
                    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('flavors').get();

                    // Loop through each document and delete it
                    querySnapshot.docs.forEach((document) {
                      document.reference.delete();
                    });
                    setState(() {
                      isCorrupt = false;
                    });
                    Navigator.of(context).pop();
                  },
                    child: Text("Delete"),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel"),
                  ),
                ],
              );
      }
        else{
          return Scaffold(
          body: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 20),
                  Text(
                    'Verfügbare Sorten',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: availableFlavors.length,
                      itemBuilder: (BuildContext context, int index) {
                        // Calculate font color depending on flavor color
                        Color textColor = availableFlavors[index].color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
                        return InkWell(
                          onTap: () =>
                              editFlavor(context, availableFlavors[index]),
                          onLongPress: () =>
                              moveFlavor(availableFlavors[index], false),
                          child: Card(
                            elevation: 5,
                            color: availableFlavors[index].color,     // Set Card color to flavor color
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    availableFlavors[index].name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    '${availableFlavors[index].price.toStringAsFixed(2)} €',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    // Show "..." if more characters than 100 characters
                                    'Zutaten: ${availableFlavors[index].ingredients.length < 100 ? availableFlavors[index].ingredients : "..."}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 10),
                  Divider(color: Colors.black),
                  SizedBox(height: 10),
                  Text(
                    'Leere Sorten',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: unavailableFlavors.length,
                      itemBuilder: (BuildContext context, int index) {
                        // Calculate font color depending on flavor color
                        Color textColor = unavailableFlavors[index].color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
                        return InkWell(
                          
                          onTap: () =>
                              editFlavor(context, unavailableFlavors[index]),
                          onLongPress: () =>
                              moveFlavor(unavailableFlavors[index], true),
                          child: Card(
                            elevation: 5,
                            color: unavailableFlavors[index].color,    // Set Card color to flavor color
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    unavailableFlavors[index].name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    '${unavailableFlavors[index].price.toStringAsFixed(2)} €',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    // Show "..." if more characters than 100 characters
                                    'Zutaten: ${unavailableFlavors[index].ingredients.length < 100 ? unavailableFlavors[index].ingredients : "..."}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: InkWell(
                  onTap: () {
                    FlavorWindow(context);
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                      color: Colors.white,
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: InkWell(
                  onTap: () {
                    toMap(context);
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                      color: Colors.white,
                    ),
                    child: Icon(
                      Icons.map,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      }
      }
    );
  }
}

class IntroScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator()
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Set<Marker> markers = {};
  final Set<Polyline> polylines = {};
  final List<String> markerIds = []; // List tracking markers already added before the map was opened
  final List<LatLng> polylineCoordinates = [];
  final List<String> newMarkerIds = []; // List tracking every marker including those added while the map is open
  GeoPoint currentPosition = const GeoPoint(47.420491, 12.855098); // default values in case the position isn't available
  @override
  void initState() {
    super.initState();
    
    _loadData(); 
  }

  Future<void> _loadData() async {
    try {
      // Get the latest coordinates
      QuerySnapshot coordinatesSnapshot =  await FirebaseFirestore.instance.collection('coordinates').get();
      final data = coordinatesSnapshot.docs.last.data()! as Map<String, dynamic>;
      currentPosition = data['position'];
    }
    catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Warnung: Der derzeitige Standort des Wagens ist nicht vorhanden!')
        ));
    }

    try {
      // Loop through collection 'route' and get all of the markers with their position and id
      QuerySnapshot markersSnapshot =
          await FirebaseFirestore.instance.collection('route').get();
      markersSnapshot.docs.forEach((doc) {
        GeoPoint pos = doc['position'];
        String markerId = doc.id;
        markers.add(
          Marker(
            markerId: MarkerId(markerId),
            position: LatLng(pos.latitude, pos.longitude),
          ),
        );
        markerIds.add(markerId);  
        newMarkerIds.add(markerId); 
      });
      updatePolylineCoordinates();
      } 
    catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error')
        ));
    }
  }

  Future<void> saveRouteData() async {
    // loop through old markers, and remove those, that aren't in the new list
    for (int i = 0; i < markerIds.length; i++) {
      if (newMarkerIds.contains(markerIds[i]) == false){
        await FirebaseFirestore.instance.collection('route').doc(markerIds[i]).delete();
      }
    }
    // loop through the new markers, and add those, that weren't in the old list
    for (int i = 0; i < newMarkerIds.length; i++) {
      if (markerIds.contains(newMarkerIds[i]) == false){
        String markerId = newMarkerIds[i];
        // add them in order of their ids as geopoints
        Marker marker = markers.firstWhere(
          (marker) => marker.markerId.value == markerId,
        );
        await FirebaseFirestore.instance.collection('route').doc(markerId).set({
            'position': GeoPoint(marker.position.latitude, marker.position.longitude),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Route')),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {},
            onTap: addMarker,
            markers: markers,
            polylines: polylines,
            initialCameraPosition: CameraPosition(
              target: LatLng(currentPosition.latitude, currentPosition.longitude),
              zoom: 12,
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: InkWell(
              onTap: _deleteRoute,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                  color: Colors.white,
                ),
                child: Icon(
                  Icons.delete,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void addMarker(LatLng pos) {
    setState(() {
      String markerId = DateTime.now().millisecondsSinceEpoch.toString();
      markers.add(
        Marker(
          markerId: MarkerId(markerId),
          position: pos,
        ),
      );
      newMarkerIds.add(markerId);   // add the new marker to the list containing the new markers
      updatePolylineCoordinates();
    });
  }

  void updatePolylineCoordinates() {
    polylineCoordinates.clear();
    for (String markerId in newMarkerIds) {
      Marker marker = markers.firstWhere(
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

  void _deleteRoute() {
    setState(() {
      polylines.clear();
      markers.clear();
      polylineCoordinates.clear();
      newMarkerIds.clear();
    });
  }

  @override
  void dispose() {
    _saveDataAndDispose();   // Called when exit button is pressed, second function as dispose can't be async
    super.dispose();
  }

  Future<void> _saveDataAndDispose() async {
    await saveRouteData(); // Save new marker data to Firestore
  }
}


class Flavor {
  late String name;
  late double price;
  late String ingredients;
  late String image;
  late bool available;
  late String picName;
  late Color color;

  Flavor({
    required this.name,
    required this.price,
    required this.ingredients,
    required this.image,
    required this.available,
    required this.picName,
    required this.color
  });

  factory Flavor.fromJson(Map<String, dynamic> json) {
    return Flavor(
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      ingredients: json['ingredients'] as String,
      image: json['picUrl'] as String,
      picName: json['picName'] as String,
      available: json['available'] as bool,
      color: json['color'] as Color
    );
  }
}