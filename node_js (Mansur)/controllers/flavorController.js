const connection = require('../db');
const fs = require('fs');
const path = require('path');

exports.addFlavor = (data, picFilePath, res) => {
    const sql = `
    INSERT INTO flavors SET name = ?, price = ?, ingredients = ?, 
                            available = ?, picFilePath = ?, color = ?`;
    const params = [data.name, data.price, data.ingredients, 
                    Boolean(data.available), picFilePath, data.color];
    connection.query(sql, params, (error, results) => {
        if (error) {
            if (error.code == 'ER_DUP_ENTRY') {
                return res.status(422).send('Error: Die Sorte existiert bereits!');
            } else if (error.code == 'ER_WARN_DATA_OUT_OF_RANGE') {
                return res.status(422)
                        .send('Error: Der Preis kann maximal 9999.90€ betragen!')
            } else {
                // Other database errors
                throw error;
            }
            
        } else {
            return res.send({'picFilePath':picFilePath});
        }
    });
};

exports.getFlavors = ((req, res) => {
    const sql = 'SELECT * FROM flavors';
    console.log("jfioajioe")
    connection.query(sql, (error, results) => {
        if (error) throw error;
        res.json(results);
    })
});

exports.updateFlavor = (data, res, rootDirectory) => {
    const sql = 'UPDATE flavors SET name = ?, price = ?, ingredients = ?, picFilePath = ?, color = ? WHERE name = ?';
    const newPicFilePath = data.picFilePath.replace(data.name, data.nameNew)
    const params = [data.nameNew, data.price, data.ingredients, newPicFilePath, data.color, data.name]
    connection.query(sql, params, (error, results) => {
        if (error) {
            if (error.code == 'ER_DUP_ENTRY') {
                // Duplicate entry error handling
                res.status(422).send('Error: Die Sorte existiert bereits!');
            } else if (error.code == 'ER_WARN_DATA_OUT_OF_RANGE') {
                res.status(422).send('Error: Der Preis kann maximal 9999.90€ betragen!')
            } else if (error.code == 'ER_BAD_FIELD_ERROR'){
                res.status(422).send('Das Attribut existiert nicht!')
            }
            else if (results.affectedRows == 0){ 
                res.status(422).send("Die Sorte existiert nicht in der Datenbank!");
            } else {
                // Other database errors
                throw error; // You may want to handle other database errors differently
            }
            
        }
        console.log(results);
        console.log(rootDirectory)
        if(data.nameNew != data.name){
            fs.rename(path.join(rootDirectory, '/public/'+ data.picFilePath), path.join(rootDirectory, '/public/'+ newPicFilePath), (err) => {
                if (err) {
                    console.error(err);
                    return;
                }
            console.log('File renamed!');
            });
        }
        return res.send({'picFilePath':newPicFilePath});
     });
};

exports.dbChange = (attr, val, name, res, picFilePath='', rootDirectory) => {
    if(attr == 'name'){
        var sql = 'UPDATE flavors SET name = ?, picFilePath = ? WHERE name = ?';
        var params = [val, picFilePath.replace(name, val), name];
    }
    else{
        var sql = 'UPDATE flavors SET ?? = ? WHERE name = ?';
        var params = [attr, val, name];
    }
    connection.query(sql, params, (error, results) => {
        console.log(results);
        if (error) {
            if (error.code == 'ER_DUP_ENTRY') {
                // Duplicate entry error handling
                res.status(422).send('Error: Die Sorte existiert bereits!');
            } else if (error.code == 'ER_WARN_DATA_OUT_OF_RANGE') {
                res.status(422).send('Error: Der Preis kann maximal 9999.90€ betragen!')
            } else if (error.code == 'ER_BAD_FIELD_ERROR'){
                res.status(422).send('Das Attribut existiert nicht!')
            } else if (results.affectedRows == 0){ 
                res.status(422).send("Die Sorte existiert nicht in der Datenbank!");
            } else {
                // Other database errors
                throw error; // You may want to handle other database errors differently
            }
            
        } else if (attr == 'name'){
            console.log(rootDirectory)
            fs.rename(path.join(rootDirectory, '/public/'+ picFilePath), path.join(rootDirectory, '/public/'+ picFilePath.replace(name, val)), (err) => {
                if (err) {
                    console.error(err);
                    return;
                }
            // File deleted successfully
            console.log('File renamed!');
            });
            res.send({'picFilePath':picFilePath.replace(name, val)})
        }
        else res.send('Das Attribut wurde geändert!');
    });
}

exports.deleteFlavor = (data, res, rootDirectory) => {
    fs.unlink(path.join(rootDirectory, '/public/'+ data.picFilePath), (err) => {
        if (err) {
            console.error(err);
            return;
        }
    // File deleted successfully
    console.log('File deleted!');
    });

    const sql = 'DELETE FROM eis_monitoring.flavors WHERE name = ?';
    connection.query(sql, [data.name], (error, results) => {
        if (error) throw error;
        if (results.affectedRows == 0) res.status(400).send("Die Sorte existiert nicht in der Datenbank!");
        else res.send('Die Sorte wurde gelöscht!');
    });
}