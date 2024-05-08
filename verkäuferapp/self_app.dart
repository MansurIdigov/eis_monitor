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
import 'package:flutter_colorpicker/flutter_colorpicker.dart';


String address = "https://82.194.143.119";

http.Response handleResponse(BuildContext context, http.Response response){
  if(response.statusCode == 422){
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${response.body}'),
      ),
    );
    throw Exception("422");
  }
  else if (response.statusCode == 200){
    return response; // Use the compute function to run parseFlavors in a separate isolate.
  }
  else{
    throw Exception("Es konnte keine Verbindung zum Server hergestellt werden.");
  }
}

List<Flavor> parseFlavors(String responseBody) {
  final parsed = (jsonDecode(responseBody) as List).cast<Map<String, dynamic>>();
  return parsed.map<Flavor>((json) => Flavor.fromJson(json)).toList();
}

Future<List<Flavor>> fetchFlavors(BuildContext context) async {
  try{
    print('$address/flavors');
    final response = await http.get(Uri.parse('$address/flavors'));
    print('$address/flavors');
    if(response.statusCode == 200)return compute(parseFlavors, response.body); // Use the compute function to run parseFlavors in a separate isolate.
    else{
      handleResponse(context, response);
      return Future.error("Es konnte keine Verbindung zum Server hergestellt werden."); 
    }
  } 
  catch(error){
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Es konnte keine Verbindung zum Server hergestellt werden'),
      ),
    );
    return Future.error("Es konnte keine Verbindung zum Server hergestellt werden.");
  }
}

Future<http.Response> postFlavor(BuildContext context, Flavor addedFlavor) async {
  final request = http.MultipartRequest('POST', Uri.parse("$address/flavors/add"));
  request.files.add(await http.MultipartFile.fromPath("picture", addedFlavor.image));
  request.fields['name'] = addedFlavor.name;
  request.fields['price'] = addedFlavor.price.toString();
  request.fields['ingredients'] = addedFlavor.ingredients;
  request.fields['available'] = addedFlavor.available.toString();
  request.fields['color'] = addedFlavor.color.value.toString();

  late var streamedResponse;
  streamedResponse = await request.send();
  var response = await http.Response.fromStream(streamedResponse);
  try{
    return handleResponse(context, response);
  }
  catch(error){
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Es konnte keine Verbindung zum Server hergestellt werden'),
      ),
    );
    return Future.error("Es konnte keine Verbindung zum Server hergestellt werden.");
  }

}

Future<http.Response> changeFlavor(BuildContext context, String name, String nameNew, double price, String ingredients, String image, Color color) async {
  final http.Response response = await http.put(
    Uri.parse("$address/flutter/flavors/change"),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'name': name,
      'nameNew': nameNew,
      'price': price.toString(),
      'ingredients': ingredients,
      'picFilePath': image,
      'color': color.value.toString()
    }),
  );
  try{
    return handleResponse(context, response);
  }
  catch(error){
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Es konnte keine Verbindung zum Server hergestellt werden'),
      ),
    );
    return Future.error("Es konnte keine Verbindung zum Server hergestellt werden.");
  }
}

Future<http.Response> changeFlavorPic(BuildContext context, String name, String nameNew, double price, String ingredients, String image, String imageNew, Color color) async {
  final request = http.MultipartRequest('PUT', Uri.parse("$address/flutter/flavors/change/pic"));
  if (await File(imageNew).exists()) {
    // Add file to request
    request.files.add(await http.MultipartFile.fromPath("picture", imageNew));
  } else {
    // If the file doesn't exist, print an error message
    print("File not found at path: $imageNew");
  }
  request.fields['name'] = name;
  request.fields['nameNew'] = nameNew;
  request.fields['price'] = price.toString();
  request.fields['ingredients'] = ingredients;
  request.fields['picFilePath'] = image;
  request.fields['color'] = color.value.toString();

  var streamedResponse = await request.send();
  var response = await http.Response.fromStream(streamedResponse);

  try{
    return handleResponse(context, response);
  }
  catch(error){
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Es konnte keine Verbindung zum Server hergestellt werden'),
      ),
    );
    return Future.error("Es konnte keine Verbindung zum Server hergestellt werden.");
  }
}

Future<http.Response> deleteFlavor(BuildContext context, name, String image) async {
  final http.Response response = await http.delete(
    Uri.parse("$address/flavors/delete"),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'name': name,
      'picFilePath': image,
    }),
  );
  try{
    return handleResponse(context, response);
  }
  catch(error){
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Es konnte keine Verbindung zum Server hergestellt werden'),
      ),
    );
    return Future.error("Es konnte keine Verbindung zum Server hergestellt werden.");
  }
}

Future<http.Response> putMoveFlavor(BuildContext context, String name, bool available) async {
  final http.Response response = await http.put(
    Uri.parse("$address/flavors/change/available"),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'availableNew': available.toString(),
      'name': name,
    }),
  );
  try{
    return handleResponse(context, response);
  }
  catch (error){
    return Future.error("Es konnte keine Verbindung zum Server hergestellt werden.");
  }
}

void main() {
  runApp(Eisverkauf());
}

class Eisverkauf extends StatelessWidget {
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
  late Future<List<Flavor>> futureFlavors;
  List imageUrls = [];

  


  @override
    void initState(){
      super.initState();
      refreshFlavors();

  }

  Future<void> refreshFlavors() async {
      availableFlavors = [];
      unavailableFlavors = [];
      imageUrls = [];
      futureFlavors = fetchFlavors(context);
      futureFlavors.then((flavors) {
      for (Flavor flavor in flavors) {
        print(flavor);
          if (flavor.available == 1) {
            setState(() {
              availableFlavors.add(flavor);
              
            });
          } else {
            setState(() {
              unavailableFlavors.add(flavor);
            });
          }
          imageUrls.add("$address/${flavor.image}");
        }
        _unloadImages(imageUrls);
        _preloadImages(imageUrls);
      }).catchError((error) {
        // Handle error if fetchFlavors fails
        print("Error fetching flavors: $error");
    });
  }

  Future<void> _preloadImages(List imageUrls) async {
    for (var url in imageUrls) {
      print("TEST: "+url);
      await precacheImage(CachedNetworkImageProvider(url), context);
    }
  }
  Future<void> _unloadImages(List imageUrls) async {
    for (var url in imageUrls) {
      print("TEST: "+url);
      await CachedNetworkImage.evictFromCache(url);
    }  
  }




  final ImagePicker _imagePicker = ImagePicker();

  void addFlavor(Flavor Flavor) {
    final List imageUrls = [];
    Future<http.Response> response = postFlavor(context, Flavor);
    response.then((resp) {
      setState(() {
        Flavor.image = jsonDecode(resp.body)['picFilePath'];
        availableFlavors.add(Flavor);
        print(Flavor.image);
        imageUrls.add("$address/${Flavor.image}");
      });
      _preloadImages(imageUrls);
    }).catchError((error) {
      // Handle error if fetchFlavors fails
      print("Error adding flavor: $error");
  });

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
                      available: 1,
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

  void editFlavor(BuildContext context, Flavor Flavor) async {
    final TextEditingController nameController =
        TextEditingController(text: Flavor.name);
    final TextEditingController priceController =
        TextEditingController(text: Flavor.price.toString());
    final TextEditingController ingredientsController =
        TextEditingController(text: Flavor.ingredients);
    XFile? pickedImage = Flavor.image.isNotEmpty ? XFile(Flavor.image) : null;
    Color selectedColor = Flavor.color; // Initialize with flavor's color

    print("$address/${Flavor.image}");
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
                  CachedNetworkImage(imageUrl: "$address/${Flavor.image}", height: 100),
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
              onPressed: () {
                final String name = nameController.text;
                final double? price = double.tryParse(priceController.text);
                if (price != null) {
                  final String ingredients =
                      ingredientsController.text;
                  Future<http.Response> response;
                  if(Flavor.image != (pickedImage?.path ?? '')){
                    response = changeFlavorPic(context,Flavor.name, name, price, ingredients, Flavor.image, (pickedImage?.path ?? '').toString(), selectedColor);
                  }
                  else{
                    response = changeFlavor(context,Flavor.name, name, price, ingredients, Flavor.image, selectedColor);
                  }
                  response.then((resp) {
                    final List url  = [];


                  if(Flavor.image!= (pickedImage?.path ?? '')){
                    url.add("$address/${jsonDecode(resp.body)['picFilePath']}");
                    CachedNetworkImage.evictFromCache("$address/${Flavor.image}");
                    _preloadImages(url);
                  }
                    setState(() {
                      Flavor.name = name;
                      Flavor.price = price;
                      Flavor.ingredients = ingredients;
                      Flavor.color = selectedColor;
                      Flavor.image = jsonDecode(resp.body)['picFilePath'];
                  });
                  }).catchError((error) {
                  // Handle error if fetchFlavors fails
                  print("Error changing flavor: $error");
                  });
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
                Future<http.Response> response;
                response = deleteFlavor(context,Flavor.name, Flavor.image);
                response.then((resp) {
                  CachedNetworkImage.evictFromCache("$address/${Flavor.image}");
                  setState(() {
                    availableFlavors.remove(Flavor);
                    unavailableFlavors.remove(Flavor);
                  });
                  
                }).catchError((error) {
                // Handle error if fetchFlavors fails
                print("Error changing flavor: $error");
                });
                Navigator.pop(context);
              },
              child: Text('Löschen'),
            ),
          ],
        );
      },
    );
  }

  void moveFlavor(Flavor Flavor, bool toAvailable) {
    Future<http.Response> response = putMoveFlavor(context, Flavor.name, toAvailable);
    response.then((resp) {
      setState(() {
        if (toAvailable) {
          unavailableFlavors.remove(Flavor);
          availableFlavors.add(Flavor);
          Flavor.available = 0;
        } else {
          availableFlavors.remove(Flavor);
          unavailableFlavors.add(Flavor);
          Flavor.available = 1;
        }
      });
    }).catchError((error) {
      // Handle error if fetchFlavors fails
      print("Error adding flavor: $error");
  });

  }

  void toMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    availableFlavors.sort((a, b) => a.name.compareTo(b.name));
    unavailableFlavors.sort((a, b) => a.name.compareTo(b.name));

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
                left: 155,
                child: InkWell(
                  onTap: () {
                    refreshFlavors();
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
                      Icons.refresh,
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
  final List<String> newMarkerIds = [];
  List<LatLng> polylineCoordinates = [];
  LatLng currentPosition = LatLng(47.420491, 12.855098); // Default position

  @override
  void initState() {
    super.initState();
    _loadData();
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
          markers.add(
            Marker(
              markerId: MarkerId(markerId),
              position: position,
            ),
          );
          newMarkerIds.add(markerId);
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
    for (String markerId in newMarkerIds) {
      final Marker marker = markers.firstWhere(
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

  Future<void> saveRouteData() async {
    // Prepare marker data to send to server
    List<Map<String, dynamic>> markersData = [];
    for (Marker marker in markers) {
      markersData.add({
        'id': marker.markerId.value,
        'latitude': marker.position.latitude,
        'longitude': marker.position.longitude,
      });
    }

    // Send marker data to server
    try {
      final response = await http.post(
        Uri.parse('$address/route'),
        body: json.encode(markersData),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) {
        print("fidao");
        throw Exception('Failed to save data');
      }
    } catch (error) {
      print(error);
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