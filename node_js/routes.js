const express = require('express');
const router = express.Router();
const path = require('path');


const { body, validationResult, matchedData } = require('express-validator');


const coordinateController = require('./controllers/coordinateController');
const flavorController = require('./controllers/flavorController');
const currentRouteController = require('./controllers/currentRouteController');

const multer = require('multer');
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, path.join(__dirname, '/public/flavor_pics/')) 
    },
    filename: function (req, file, callback) {
        var string = JSON.stringify (req.body);
        var data = JSON.parse(string);
        callback(null, data.name + '.png');
    }

});

const upload = multer({
    storage: storage,
    limits: {files:1, fileSize: 1024*1024*5},
    fileFilter: function (req, file, callback) {
        var oldExt = path.extname(file.originalname);
        if(oldExt !== '.png' && oldExt !== '.jpg' && oldExt !== '.jpeg') {
            return callback(new Error('Only images are allowed'))
        }
        callback(null, true)
    }
});

const rootDirectory = __dirname

// Coordinate routes
router.get('/coordinates', coordinateController.getCoordinates);
router.post('/coordinates', [
    body('time').notEmpty().escape().matches(/^[0-9 -:]+$/),
    body('longitude').notEmpty().isNumeric(),
    body('latitude').notEmpty().isNumeric(),
    (req, res, next) => {
        const results = validationResult(req);
        if (results.isEmpty()) {
            const data = matchedData(req);
            coordinateController.postCoordinates(data, res, next);
        }
        else{
            return res.status(400).json({ errors: results.array() });
        }

    }
]);

// Flavor routes
router.get('/flavors', flavorController.getFlavors);

router.post('/flavors/add', [
    upload.single('picture'), // Handle file upload
    body('name').notEmpty().escape().matches(/^[A-Za-z0-9 ]+$/)
        .withMessage("Der Name darf keine besonderen Zeichen enthalten"), 
    body('price').notEmpty().escape().matches(/^[0-9 .,]+$/),
    body('color').notEmpty().escape().matches(/^[0-9"]+$/),
    body('ingredients').notEmpty().escape().matches(/^[A-Za-z0-9 .,'!&]+$/), 
    body('available').notEmpty().escape(),
    (req, res) => {
        const result = validationResult(req);
        if(result.isEmpty()) {
            const file = req.file;
            if (!file) {
                return res.status(400).send('No file uploaded.');
            }
            const data = matchedData(req);
            const picFilePath = "flavor_pics/" + file.filename;
            flavorController.addFlavor(data, picFilePath, res);
        }
        else{
            const errorMessages = errors.array().map(error => error.msg);
            console.log(errorMessages);
            return res.status(422).send('Error:' + errorMessages);
        }

    }
]);

router.put('/flutter/flavors/change', [
    // Validate request body fields using express-validator
    body('name').notEmpty().escape().matches(/^[A-Za-z0-9 ]+$/),
    body('nameNew').notEmpty().escape().matches(/^[A-Za-z0-9 .,'!&]+$/).withMessage("Der Name darf keine besonderen Zeichen enthalten"),
    body('price').notEmpty().escape().matches(/^[A-Za-z0-9 .,'!&]+$/),
    body('color').notEmpty().escape().matches(/^[0-9"]+$/),
    body('ingredients').notEmpty().escape().matches(/^[A-Za-z0-9 .,'!&%_]+$/).withMessage("Die Zutaten dürfen höchstens die Zeichen . , ' ! & % _ enthalten!"),
    body('picFilePath').notEmpty().matches(/^[A-Za-z0-9 .,'!&/_]*$/),
    (req, res) => {
        const result = validationResult(req);
        if(result.isEmpty()) {
            const data = matchedData(req);
            flavorController.updateFlavor(data, res, rootDirectory);
        } else {
            // If validation fails, send error response with validation messages
            const errorMessages = result.array().map(error => error.msg);
            console.log(errorMessages);
            return res.status(422).send('Fehler: ' + errorMessages);
        }
    }
]);

router.put('/flutter/flavors/change/pic', upload.single('picture'), [
    body('name').notEmpty().escape().matches(/^[A-Za-z0-9 ]+$/).withMessage("Der Name darf keine besonderen Zeichen enthalten"),
    body('nameNew').notEmpty().escape().matches(/^[A-Za-z0-9 .,'!&]+$/).withMessage("Der Name darf keine besonderen Zeichen enthalten"),
    body('price').notEmpty().escape().matches(/^[A-Za-z0-9 .,'!&]+$/),
    body('color').notEmpty().escape().matches(/^[0-9"]+$/),
    body('ingredients').notEmpty().escape().matches(/^[A-Za-z0-9 .,'!&%_]+$/).withMessage("Die Zutaten dürfen höchstens die Zeichen . , ' ! & % _ enthalten!"),
    body('picFilePath').notEmpty().matches(/^[A-Za-z0-9 .,'!&/_-]*$/),
    (req, res) => {
        // Check for validation errors
        const result = validationResult(req);
        console.log(result);
        if(result.isEmpty()) {
            const data = matchedData(req);
            const file = req.file;
            if (!file) {
                return res.status(400).send('No file uploaded.');
            }
            flavorController.updateFlavor(data, res, rootDirectory);
        } else {
            // If validation fails, send error response with validation messages
            const errorMessages = result.array().map(error => error.msg);
            console.log(errorMessages);
            return res.status(422).send('Fehler: ' + errorMessages);
        }
    }
]);

// Route to change flavor name
router.put('/flavors/change/name', [
    body('nameNew').notEmpty().escape().matches(/^[A-Za-z0-9 ]+$/),
    body('name').notEmpty().escape().matches(/^[A-Za-z0-9 .,'!&]+$/),
    body('picFilePath').notEmpty().matches(/^[A-Za-z0-9 .,'!&/_]*$/),
], (req, res) => {
    const result = validationResult(req);
    if(result.isEmpty()){
        const data = matchedData(req);
        flavorController.dbChange('name', data.nameNew, data.name, res, data.picFilePath, rootDirectory);
    }
    else{
        const errorMessages = result.array().map(error => error.msg);
        console.log(errorMessages);
        return res.status(422).send('Fehler: ' + errorMessages);
    }
});

// Route to change flavor ingredients
router.put('/flavors/change/ingredients', [
    body('ingredientsNew').notEmpty().escape().matches(/^[A-Za-z0-9 .,'!&]+$/),
    body('name').notEmpty().escape().matches(/^[A-Za-z0-9 .,'!&]+$/),
], (req, res) => {
    const result = validationResult(req);
    if(result.isEmpty()){
        const data = matchedData(req);
        flavorController.dbChange('ingredients', data.ingredientsNew, data.name, res, rootDirectory);
    }
    else{
        const errorMessages = result.array().map(error => error.msg);
        console.log(errorMessages);
        return res.status(422).send('Fehler: ' + errorMessages);
    }
});

// Route to change flavor price
router.put('/flavors/change/price', [
    body('priceNew').notEmpty().escape().matches(/^[0-9 .,]+$/),
    body('name').notEmpty().escape().matches(/^[A-Za-z0-9 .,'!&]+$/),
], (req, res) => {
    const result = validationResult(req);
    if(result.isEmpty()){
        const data = matchedData(req);
        flavorController.dbChange('price', data.priceNew, data.name, res, rootDirectory);
    }
    else{
        const errorMessages = result.array().map(error => error.msg);
        console.log(errorMessages);
        return res.status(422).send('Fehler: ' + errorMessages);
    }
});

// Route to change flavor availability
router.put('/flavors/change/available', [
    body('availableNew').notEmpty().escape().matches(/^[A-Za-z0-9 .,'!&]+$/).toBoolean(),
    body('name').notEmpty().escape().matches(/^[A-Za-z0-9 .,'!&]+$/),
], (req, res) => {
    const result = validationResult(req);
    if(result.isEmpty()){
        const data = matchedData(req);
        flavorController.dbChange('available', data.availableNew, data.name, res, rootDirectory);
    }
    else{
        const errorMessages = result.array().map(error => error.msg);
        console.log(errorMessages);
        return res.status(422).send('Fehler: ' + errorMessages);
    }
});

// Route to change flavor color
router.put('/flavors/change/color', [
    body('colorNew').notEmpty().escape().matches(/^[0-9"]+$/),
    body('name').notEmpty().escape().matches(/^[A-Za-z0-9 .,'!&]+$/),
], (req, res) => {
    const result = validationResult(req);
    if(result.isEmpty()){
        const data = matchedData(req);
        flavorController.dbChange('color', data.colorNew, data.name, res, rootDirectory);
    }
    else{
        const errorMessages = result.array().map(error => error.msg);
        console.log(errorMessages);
        return res.status(422).send('Fehler: ' + errorMessages);
    }
});

router.put('/flavors/change/pic', upload.single('picture'), [
    body('picFilePath').notEmpty().matches(/^[A-Za-z0-9 .,'!&/_]*$/), 
    body('name').notEmpty().matches(/^[A-Za-z0-9 .,'!&]+$/),
    (req, res) => {
        // Check for validation errors
        const result = validationResult(req);
        console.log(result);
        if(result.isEmpty()) {
            const data = matchedData(req);
            const file = req.file;
            if (!file) {
                return res.status(400).send('No file uploaded.');
            }
            return res.status(201).send('Pic has been changed!');
        } else {
            // If validation fails, send error response with validation messages
            const errorMessages = result.array().map(error => error.msg);
            console.log(errorMessages);
            return res.status(422).send('Fehler: ' + errorMessages);
        }
    }
]);

router.delete('/flavors/delete',[
    body('picFilePath').notEmpty().matches(/^[A-Za-z0-9 .,'!&/_]*$/), 
    body('name').notEmpty().matches(/^[A-Za-z0-9 .,'!&]+$/),
    (req, res) => {
        // Check for validation errors
        const result = validationResult(req);
        console.log(result);
        if(result.isEmpty()) {
            const data = matchedData(req);
            flavorController.deleteFlavor(data, res, rootDirectory);
        } else {
            // If validation fails, send error response with validation messages
            const errorMessages = result.array().map(error => error.msg);
            console.log(errorMessages);
            return res.status(422).send('Fehler: ' + errorMessages);
        }
    }
]);

// Current route routes
router.get('/route', currentRouteController.getCurrentRoute);
router.post('/route', [
    body().isArray().withMessage('Data should be an array'),
    body('*').isObject().withMessage('Each marker should be an object'),
    body('*.id').notEmpty().matches(/^[0-9]+$/).withMessage('Invalid Markder ID'),
    body('*.latitude').notEmpty().escape().matches(/^[0-9.]+$/).withMessage('Invalid latitude'),
    body('*.longitude').notEmpty().escape().matches(/^[0-9.]+$/).withMessage('Invalid longitude'),
    (req, res, next) => {
        const results = validationResult(req);
        if (results.isEmpty()) {
            currentRouteController.postCurrentRoute(req, res, next);
        }
        else{
            return res.status(400).json({ errors: errors.array() });
        }
    }
]);

module.exports = router;