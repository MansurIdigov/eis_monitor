import os.path
import sys
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QPalette, QColor
from PyQt6.QtWidgets import (
    QApplication,
    QComboBox,
    QDialog,
    QFileDialog,
    QGridLayout,
    QInputDialog,
    QLabel,
    QListWidget,
    QPushButton,
    QVBoxLayout,
    QColorDialog
)
from google.cloud import firestore
from firebase_admin import credentials, initialize_app, storage
import time

db = firestore.Client.from_service_account_json("...") # Keyfile for service account for Firestore

cred = credentials.Certificate("...") # Keyfile for service account for Firebase storage
initialize_app(cred, {'storageBucket': 'eis-monitoring.appspot.com'})        # Storage bucket
bucket = storage.bucket()

FILE_FILTERS = [
    "Portable Network Graphics files (*.png)",
    "Joint Photographic Experts Group files (*.jpeg)",
    "All files (*)",
]

class IceCreamFlavor:
    def __init__(self, name, price=0.0, available=True, ingredients="", image_file="", image_url="", color=0):
        self.name = name
        self.price = price
        self.available = available
        self.ingredients = ingredients
        self.image_file = image_file            # Variable containing image file name
        self.image_url = image_url              # Variable containing download url of image file
        self.color = color

    def __str__(self):
        return f"{self.name} - {self.price:.2f}"

class DeletedIceCream:
    def __init__(self, name, image_file):
        self.name = name
        self.image_file = image_file

class MainWindow(QDialog):
    def __init__(self):
        super().__init__()

        self.setGeometry(600, 100, 400, 200)
        self.qlayout = QGridLayout()
        self.setLayout(self.qlayout)
        self.setWindowTitle("Eis")

        self.flavors = []
        self.deleted_flavors = []



        self.qlist_available = QListWidget()
        self.qlist_unavailable = QListWidget()

        self.qlist_available.setSortingEnabled(True)
        self.qlist_unavailable.setSortingEnabled(True)

        self.qlist_available.itemSelectionChanged.connect(self.clear_unavailable_selection)
        self.qlist_unavailable.itemSelectionChanged.connect(self.clear_available_selection)

        self.qlabel_available = QLabel("Verfügbare Sorten")
        self.qlabel_unavailable = QLabel("Leere Sorten")
        self.qlabel_error = QLabel("")
        self.qlabel_error.setStyleSheet("color: red")

        self.qlabel_available.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.qlabel_unavailable.setAlignment(Qt.AlignmentFlag.AlignCenter)

        self.qbutton_add = QPushButton("Hinzufügen")
        self.qbutton_rename = QPushButton("Umbenennen")
        self.qbutton_move = QPushButton("Verschieben")
        self.qbutton_delete = QPushButton("Löschen")
        self.qbutton_price = QPushButton("Preis ändern")
        self.qbutton_image = QPushButton("Bild ändern")
        self.qbutton_show_ingredients = QPushButton("Zutaten anzeigen")
        self.qbutton_edit_ingredients = QPushButton("Zutaten bearbeiten")
        self.qbutton_change_color = QPushButton("Farbe ändern")
        self.qbutton_refresh = QPushButton("Aktualisieren")

        self.qbutton_add.clicked.connect(self.add_ice)
        self.qbutton_rename.clicked.connect(self.rename_ice)
        self.qbutton_move.clicked.connect(self.move_ice)
        self.qbutton_delete.clicked.connect(self.delete_ice)
        self.qbutton_price.clicked.connect(self.change_price)
        self.qbutton_image.clicked.connect(self.change_image)
        self.qbutton_show_ingredients.clicked.connect(self.show_ingredients)
        self.qbutton_edit_ingredients.clicked.connect(self.edit_ingredients)
        self.qbutton_change_color.clicked.connect(self.change_color)
        self.qbutton_refresh.clicked.connect(self.refresh_ice)

        self.qcombo_theme = QComboBox()
        self.qcombo_theme.addItems(["Hell", "Grün", "Blau", "Orange", "Pink", "Dunkel", "Discord"])

        self.qcombo_theme.currentIndexChanged.connect(self.index_changed)

        self.qlayout.addWidget(self.qlabel_available, 0, 0)
        self.qlayout.addWidget(self.qlabel_unavailable, 0, 1)
        self.qlayout.addWidget(self.qlist_available, 1, 0, 9, 1)
        self.qlayout.addWidget(self.qlist_unavailable, 1, 1, 9, 1)

        self.qlayout.addWidget(self.qbutton_add, 2, 2, 1, 1)
        self.qlayout.addWidget(self.qbutton_rename, 3, 2, 1, 1)
        self.qlayout.addWidget(self.qbutton_move, 4, 2, 1, 1)
        self.qlayout.addWidget(self.qbutton_delete, 5, 2, 1, 1)
        self.qlayout.addWidget(self.qbutton_price, 6, 2, 1, 1)
        self.qlayout.addWidget(self.qbutton_image, 7, 2, 1, 1)
        self.qlayout.addWidget(self.qbutton_show_ingredients, 8, 2, 1, 1)
        self.qlayout.addWidget(self.qbutton_edit_ingredients, 9, 2, 1, 1)
        self.qlayout.addWidget(self.qbutton_change_color, 10, 2, 1, 1)
        self.qlayout.addWidget(self.qbutton_refresh, 11, 0, 1, 1)
        self.qlayout.addWidget(self.qcombo_theme, 11, 2, 1, 1)
        self.qlayout.addWidget(self.qlabel_error, 12, 0, 1, 3)

        self.update_list_widgets()
        self.refresh_ice()


    # Flavors are saved into variable 'newFlavors' and saved into 'self.flavors' if no error occured
    def refresh_ice(self):
        self.flavors = []
        self.deleted_flavors = []
        newFlavors = []
        try:
            data = db.collection("flavors").get()
            for i in data:
                newFlavor = IceCreamFlavor(name=i.id, price=i.get('price'), available=i.get('available'),
                                           ingredients=i.get('ingredients'), image_file=i.get('picName'),
                                           color=i.get('color'), image_url=i.get('picUrl'))
                newFlavors.append(newFlavor)
        except Exception:
            self.qlabel_error.setStyleSheet("color: red")
            self.qlabel_error.setText("Die Sorten konnten nicht abgefragt werden.")
            return
        self.flavors = newFlavors
        self.update_list_widgets()
        self.qlabel_error.setStyleSheet("color: green")
        self.qlabel_error.setText("Die Sorten wurden aktualisiert.")
    def add_ice(self):
        ice_name, ok = QInputDialog.getText(self, 'Eissorte hinzufügen', 'Namen eingeben:')
        if ok and ice_name:
            ice_price, ok = QInputDialog.getDouble(self, 'Preis eingeben', 'Preis eingeben:', min=0.0)
            if ok and ice_price:
                ice_ingredients, ok = QInputDialog.getText(self, 'Zutaten hinzufügen', 'Zutaten eingeben:')
                if ok and ice_ingredients:
                    initial_filter = FILE_FILTERS[2]
                    filters = ";;".join(FILE_FILTERS)

                    filename, selected_filter = QFileDialog.getOpenFileName(
                        self,
                        caption='Bild hinzufügen',
                        directory='',
                        filter=filters,
                        initialFilter=initial_filter,
                    )

                    if filename:
                        color_dialog = QColorDialog(self)
                        color_dialog.setWindowTitle("Farbe auswählen")
                        color = color_dialog.getColor()

                        if color.isValid():
                            try:
                                image_name = f"{str(time.time())}.jpg"             # Filename in storage with time as id
                                new_flavor = IceCreamFlavor(name=ice_name, price=ice_price, available=True, ingredients=ice_ingredients, image_file=image_name, color=color.rgb())

                                # Upload image to filepath defined with blob and make publicly available
                                blob = bucket.blob(f"flavor_images/{image_name}")
                                blob.upload_from_filename(filename)
                                blob.make_public()

                                new_flavor.image_url = blob.public_url
                                new_flavor.image_file = image_name
                                new_flavor.color = color.rgb()

                                db.collection('flavors').document(new_flavor.name).set({
                                    'price': new_flavor.price,
                                    'ingredients': new_flavor.ingredients,
                                    'available': new_flavor.available,
                                    'picUrl': new_flavor.image_url,
                                    'picName': new_flavor.image_file,
                                    'color': str(new_flavor.color)
                                })
                            except Exception:
                                self.qlabel_error.setStyleSheet("color: red")
                                self.qlabel_error.setText("Die Sorte konnte nicht hinzugefügt werden.")
                                return
                            self.flavors.append(new_flavor)
                            self.update_list_widgets()


    def rename_ice(self):
        selected_item = self.qlist_available.selectedItems()[0] if self.qlist_available.selectedItems() else None
        if not selected_item:
            selected_item = self.qlist_unavailable.selectedItems()[0] if self.qlist_unavailable.selectedItems() else None
        if selected_item:
            old_flavor_name = selected_item.text().split(' - ')[0]
            new_flavor_name, ok = QInputDialog.getText(self, 'Eissorte umbenennen', 'Neuen Namen eingeben:', text=old_flavor_name)
            if ok and new_flavor_name:
                for flavor in self.flavors:
                    if flavor.name == old_flavor_name:
                        try:
                            # Make collection under new name and delete old one
                            db.collection('flavors').document(new_flavor_name).set({
                                'price': flavor.price,
                                'ingredients': flavor.ingredients,
                                'available': flavor.available,
                                'picUrl': flavor.image_url,
                                'picName': flavor.image_file,
                                'color': str(flavor.color)
                            })
                            db.collection('flavors').document(flavor.name).delete()
                            flavor.name = new_flavor_name
                        except Exception:
                            self.qlabel_error.setStyleSheet("color: red")
                            self.qlabel_error.setText("Die Sorte konnte nicht umbenannt werden.")
                            return
                self.update_list_widgets()

    def move_ice(self):
        selected_item = self.qlist_available.selectedItems()[0] if self.qlist_available.selectedItems() else None
        if not selected_item:
            selected_item = self.qlist_unavailable.selectedItems()[0] if self.qlist_unavailable.selectedItems() else None
        if selected_item:
            flavor_name = selected_item.text().split(' - ')[0]
            for flavor in self.flavors:
                if flavor.name == flavor_name:
                    try:
                        # Update flavor's document with inverted availability
                        db.collection('flavors').document(flavor_name).update({'available': not flavor.available})
                        flavor.available = not flavor.available
                    except Exception:
                        self.qlabel_error.setStyleSheet("color: red")
                        self.qlabel_error.setText("Die Sorte konnte nicht verschoben werden.")
                        return
            self.update_list_widgets()

    def delete_ice(self):
        selected_item = self.qlist_available.selectedItems()[0] if self.qlist_available.selectedItems() else None
        if not selected_item:
            selected_item = self.qlist_unavailable.selectedItems()[0] if self.qlist_unavailable.selectedItems() else None
        if selected_item:
            flavor_name = selected_item.text().split(' - ')[0]
            image_file = next((flavor.image_file for flavor in self.flavors if flavor.name == flavor_name), "")
            try:
                # Delete image at filepath defined with blob and delete flavor's document
                blob = bucket.blob(f"flavor_images/{image_file}")
                blob.delete()
                db.collection('flavors').document(flavor_name).delete()
            except Exception:
                self.qlabel_error.setStyleSheet("color: red")
                self.qlabel_error.setText("Die Sorte konnte nicht gelöscht werden.")
                return
            self.deleted_flavors.append(DeletedIceCream(flavor_name, image_file))
            self.flavors = [flavor for flavor in self.flavors if flavor.name != flavor_name]
            self.update_list_widgets()
    def change_price(self):
        selected_item = self.qlist_available.selectedItems()[0] if self.qlist_available.selectedItems() else None
        if not selected_item:
            selected_item = self.qlist_unavailable.selectedItems()[0] if self.qlist_unavailable.selectedItems() else None
        if selected_item:
            flavor_name = selected_item.text().split(' - ')[0]
            current_price = float(selected_item.text().split(' - ')[1])
            new_price, ok = QInputDialog.getDouble(self, 'Preis ändern', 'Neuen Preis eingeben', value=current_price, min=0.0)
            if ok:
                for flavor in self.flavors:
                    if flavor.name == flavor_name:
                        try:
                            # Update flavor's document with new price
                            db.collection('flavors').document(flavor_name).update({'price': new_price})
                            flavor.price = new_price
                        except Exception:
                            self.qlabel_error.setStyleSheet("color: red")
                            self.qlabel_error.setText("Der Preis der Sorte konnte nicht verändert werden.")
                            return
                self.update_list_widgets()

    def change_image(self):
        initial_filter = FILE_FILTERS[2]
        filters = ";;".join(FILE_FILTERS)


        filename, selected_filter = QFileDialog.getOpenFileName(
            self,
            filter=filters,
            initialFilter=initial_filter,
        )


        if filename:
            selected_item = self.qlist_available.selectedItems()[0] if self.qlist_available.selectedItems() else None
            if not selected_item:
                selected_item = self.qlist_unavailable.selectedItems()[0] if self.qlist_unavailable.selectedItems() else None
            if selected_item:
                flavor_name = selected_item.text().split(' - ')[0]
                for flavor in self.flavors:
                    if flavor.name == flavor_name:
                        try:
                            # Upload new image under filepath defined with newBlob with current time as id
                            image_name = f"{str(time.time())}.jpg"
                            newBlob = bucket.blob(f"flavor_images/{image_name}")
                            newBlob.upload_from_filename(filename)
                            newBlob.make_public()
                            # Delete old image under old filepath
                            oldBlob = bucket.blob(f"flavor_images/{flavor.image_file}")
                            oldBlob.delete()
                            # Update filename and download url of flavor in document
                            db.collection('flavors').document(flavor_name).update({'picUrl': newBlob.public_url, 'picName': newBlob.name})
                        except Exception:
                            self.qlabel_error.setStyleSheet("color: red")
                            self.qlabel_error.setText("Das Bild der Sorte konnte nicht verändert werden.")
                            return
                        flavor.image_url = newBlob.public_url
                        flavor.image_file = newBlob.name
                    self.update_list_widgets()


    def show_ingredients(self):
        selected_item = self.qlist_available.selectedItems()[0] if self.qlist_available.selectedItems() else None
        if not selected_item:
            selected_item = self.qlist_unavailable.selectedItems()[0] if self.qlist_unavailable.selectedItems() else None
        if selected_item:
            flavor_name = selected_item.text().split(' - ')[0]
            ingredients = next((flavor.ingredients for flavor in self.flavors if flavor.name == flavor_name), "Zutaten nicht verfügbar.")
            self.ingredients_window = IngredientsWindow(flavor_name, ingredients)
            self.ingredients_window.show()


    def edit_ingredients(self):
        selected_item = self.qlist_available.selectedItems()[0] if self.qlist_available.selectedItems() else None
        if not selected_item:
            selected_item = self.qlist_unavailable.selectedItems()[0] if self.qlist_unavailable.selectedItems() else None
        if selected_item:
            flavor_name = selected_item.text().split(' - ')[0]
            current_ingredients = next((flavor.ingredients for flavor in self.flavors if flavor.name == flavor_name), "")
            new_ingredients, ok = QInputDialog.getText(self, 'Zutaten bearbeiten', 'Zutaten eingeben:', text=current_ingredients)
            if ok:
                for flavor in self.flavors:
                    if flavor.name == flavor_name:
                        # Update ingredients in flavor's document
                        try: db.collection('flavors').document(flavor_name).update({'ingredients': new_ingredients})
                        except Exception:
                            self.qlabel_error.setStyleSheet("color: red")
                            self.qlabel_error.setText("Die Zutaten der Sorte konnten nicht verändert werden.")
                            return
                        flavor.ingredients = new_ingredients
                self.update_list_widgets()

    def change_color(self):
        selected_item = self.qlist_available.selectedItems()[0] if self.qlist_available.selectedItems() else None
        if not selected_item:
            selected_item = self.qlist_unavailable.selectedItems()[0] if self.qlist_unavailable.selectedItems() else None
        if selected_item:
            flavor_name = selected_item.text().split(' - ')[0]
            for flavor in self.flavors:
                if flavor.name == flavor_name:
                    color_dialog = QColorDialog(self)
                    color_dialog.setWindowTitle("Farbe auswählen")
                    color_dialog.setCurrentColor(QColor(flavor.color))
                    new_color = color_dialog.getColor()

                    if new_color.isValid():
                        try:
                            # Update color in flavor's document
                            db.collection('flavors').document(flavor.name).update({'color': str(flavor.color)})
                        except Exception:
                            self.qlabel_error.setStyleSheet("color: red")
                            self.qlabel_error.setText("Die Farbe der Sorte konnte nicht verändert werden.")
                            return
                        flavor.color = new_color.rgb()
            self.update_list_widgets()
    def update_list_widgets(self):
        self.qlist_available.clear()
        self.qlist_unavailable.clear()
        for flavor in self.flavors:
            item_text = str(flavor)
            if flavor.available:
                self.qlist_available.addItem(item_text)
            else:
                self.qlist_unavailable.addItem(item_text)


    def clear_available_selection(self):
        self.qlist_available.clearSelection()


    def clear_unavailable_selection(self):
        self.qlist_unavailable.clearSelection()


    def index_changed(self, i):
        if i == 0:  #Light
            lightPalette = QPalette()
            lightPalette.setColor(QPalette.ColorRole.Window, QColor(243, 243, 243))
            lightPalette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.black)
            lightPalette.setColor(QPalette.ColorRole.Base, QColor(255, 255, 255))
            lightPalette.setColor(QPalette.ColorRole.Text, Qt.GlobalColor.black)
            lightPalette.setColor(QPalette.ColorRole.Button, QColor(243, 243, 243))
            lightPalette.setColor(QPalette.ColorRole.ButtonText, Qt.GlobalColor.black)
            lightPalette.setColor(QPalette.ColorRole.BrightText, Qt.GlobalColor.white)
            lightPalette.setColor(QPalette.ColorRole.Highlight, QColor(0, 144, 255))
            lightPalette.setColor(QPalette.ColorRole.HighlightedText, Qt.GlobalColor.white)
            app.setPalette(lightPalette)

        elif i == 1:  #Green
            darkPalette = QPalette()
            darkPalette.setColor(QPalette.ColorRole.Window, QColor(183, 228, 199))
            darkPalette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.black)
            darkPalette.setColor(QPalette.ColorRole.Base, QColor(216, 243, 220))
            darkPalette.setColor(QPalette.ColorRole.Text, Qt.GlobalColor.black)
            darkPalette.setColor(QPalette.ColorRole.Button, QColor(116, 198, 157))
            darkPalette.setColor(QPalette.ColorRole.ButtonText, Qt.GlobalColor.black)
            darkPalette.setColor(QPalette.ColorRole.BrightText, Qt.GlobalColor.white)
            darkPalette.setColor(QPalette.ColorRole.Highlight, QColor(82, 183, 136))
            darkPalette.setColor(QPalette.ColorRole.HighlightedText, Qt.GlobalColor.white)
            app.setPalette(darkPalette)

        elif i == 2:  #Blue
            darkPalette = QPalette()
            darkPalette.setColor(QPalette.ColorRole.Window, QColor(173, 232, 244))
            darkPalette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.black)
            darkPalette.setColor(QPalette.ColorRole.Base, QColor(202, 240, 248))
            darkPalette.setColor(QPalette.ColorRole.Text, Qt.GlobalColor.black)
            darkPalette.setColor(QPalette.ColorRole.Button, QColor(72, 202, 228))
            darkPalette.setColor(QPalette.ColorRole.ButtonText, Qt.GlobalColor.black)
            darkPalette.setColor(QPalette.ColorRole.BrightText, Qt.GlobalColor.white)
            darkPalette.setColor(QPalette.ColorRole.Highlight, QColor(72, 202, 228))
            darkPalette.setColor(QPalette.ColorRole.HighlightedText, Qt.GlobalColor.white)
            app.setPalette(darkPalette)

        elif i == 3:  #Orange
            darkPalette = QPalette()
            darkPalette.setColor(QPalette.ColorRole.Window, QColor(251, 196, 171))
            darkPalette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.black)
            darkPalette.setColor(QPalette.ColorRole.Base, QColor(255, 218, 185))
            darkPalette.setColor(QPalette.ColorRole.Text, Qt.GlobalColor.black)
            darkPalette.setColor(QPalette.ColorRole.Button, QColor(248, 173, 157))
            darkPalette.setColor(QPalette.ColorRole.ButtonText, Qt.GlobalColor.black)
            darkPalette.setColor(QPalette.ColorRole.BrightText, Qt.GlobalColor.white)
            darkPalette.setColor(QPalette.ColorRole.Highlight, QColor(244, 151, 142))
            darkPalette.setColor(QPalette.ColorRole.HighlightedText, Qt.GlobalColor.white)
            app.setPalette(darkPalette)

        elif i == 4:  #Pink
            darkPalette = QPalette()
            darkPalette.setColor(QPalette.ColorRole.Window, QColor(255, 204, 213))
            darkPalette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.black)
            darkPalette.setColor(QPalette.ColorRole.Base, QColor(255, 240, 243))
            darkPalette.setColor(QPalette.ColorRole.Text, Qt.GlobalColor.black)
            darkPalette.setColor(QPalette.ColorRole.Button, QColor(255, 179, 193))
            darkPalette.setColor(QPalette.ColorRole.ButtonText, Qt.GlobalColor.black)
            darkPalette.setColor(QPalette.ColorRole.BrightText, Qt.GlobalColor.white)
            darkPalette.setColor(QPalette.ColorRole.Highlight, QColor(255, 143, 163))
            darkPalette.setColor(QPalette.ColorRole.HighlightedText, Qt.GlobalColor.white)
            app.setPalette(darkPalette)

        elif i == 5:  #Dark
            darkPalette = QPalette()
            darkPalette.setColor(QPalette.ColorRole.Window, QColor(53, 53, 53))
            darkPalette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.white)
            darkPalette.setColor(QPalette.ColorRole.Base, QColor(42, 42, 42))
            darkPalette.setColor(QPalette.ColorRole.Text, Qt.GlobalColor.white)
            darkPalette.setColor(QPalette.ColorRole.Button, QColor(53, 53, 53))
            darkPalette.setColor(QPalette.ColorRole.ButtonText, Qt.GlobalColor.white)
            darkPalette.setColor(QPalette.ColorRole.BrightText, Qt.GlobalColor.white)
            darkPalette.setColor(QPalette.ColorRole.Highlight, QColor(180, 79, 227))
            darkPalette.setColor(QPalette.ColorRole.HighlightedText, Qt.GlobalColor.white)
            app.setPalette(darkPalette)

        elif i == 6:  #Discord
            darkPalette = QPalette()
            darkPalette.setColor(QPalette.ColorRole.Window, QColor(43, 45, 49))
            darkPalette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.gray)
            darkPalette.setColor(QPalette.ColorRole.Base, QColor(49, 51, 56))
            darkPalette.setColor(QPalette.ColorRole.Text, Qt.GlobalColor.gray)
            darkPalette.setColor(QPalette.ColorRole.Button, QColor(43, 45, 49))
            darkPalette.setColor(QPalette.ColorRole.ButtonText, Qt.GlobalColor.gray)
            darkPalette.setColor(QPalette.ColorRole.BrightText, Qt.GlobalColor.gray)
            darkPalette.setColor(QPalette.ColorRole.Highlight, QColor(64, 66, 73))
            darkPalette.setColor(QPalette.ColorRole.HighlightedText, Qt.GlobalColor.white)
            app.setPalette(darkPalette)


class IngredientsWindow(QDialog):
    def __init__(self, ice_name, ingredients):
        super().__init__()


        self.setWindowTitle(f"Zutaten für {ice_name}")
        self.setGeometry(700, 200, 300, 150)


        layout = QVBoxLayout()


        label_ice_name = QLabel(f"Eissorte: {ice_name}")
        label_ingredients = QLabel(f"Zutaten: {ingredients}")


        layout.addWidget(label_ice_name)
        layout.addWidget(label_ingredients)


        self.setLayout(layout)


app = QApplication(sys.argv)
app.setStyle("Fusion")
window = MainWindow()
window.show()
sys.exit(app.exec())