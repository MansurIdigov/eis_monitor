const connection = require('../db');

exports.getCurrentRoute = (req, res) => {
    const sql = 'SELECT * FROM route ORDER BY id ASC';
    connection.query(sql, (error, results) => {
        if (error) throw error;
        res.json(results);
    });
};

exports.postCurrentRoute = (req, res) => {

    const markersData = req.body;

    // Delete existing data from the route table
    const dropPromise = new Promise((resolve, reject) => {
        connection.query('DELETE FROM route', (error, results) => {
            if (error) {
                console.log(error);
                reject(error);
            } else {
                resolve(results);
            }
        });
    });

    // Insert new data into the route table
    const insertPromises = markersData.map(marker => {
        return new Promise((resolve, reject) => {
            const { id, latitude, longitude } = marker;
            const sql = 'INSERT INTO route (id, latitude, longitude) VALUES (?, ?, ?)';
            connection.query(sql, [id, latitude, longitude], (error, results) => {
                if (error) {
                    console.log(error);
                    reject(error);
                } else {
                    resolve(results);
                }
            });
        });
    });

    // Wait for all insert queries to finish
    Promise.all([dropPromise, ...insertPromises])
        .then(() => {
            res.status(200).send('Route data saved successfully');
        })
        .catch(error => {
            if (error.code === 'ER_DUP_ENTRY') {
                res.status(400).send('Error: Duplicate entry');
            } else {
                res.status(500).send('Internal server error');
            }
        });
};