const connection = require('../db');

exports.getCoordinates = (req, res) => {
  const sql = 'SELECT * FROM coordinates ORDER BY time DESC LIMIT 1';
  connection.query(sql, (error, results) => {
      if (error) throw error;
      res.json(results);
  });
};

exports.postCoordinates = (data, res) => {
  const sql = 'INSERT INTO coordinates SET time = ?, longitude = ?, latitude = ?';
  connection.query(sql, [data.time, data.longitude, data.latitude], (error, results) => {
      if (error) {
          if (error.code == 'ER_DUP_ENTRY') {
              // Duplicate entry error handling
              res.status(400).send('Error: Es können keine 2 Koordinatenwerte zur selben Zeit existieren!');
          } 
          else {
              // Other database errors
              throw error; // You may want to handle other database errors differently
          }
      }
      else {
          res.status(201).send(`Coordinates added!`);
      }
  })
};