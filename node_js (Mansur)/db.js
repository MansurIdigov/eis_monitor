const mysql = require('mysql2');

const connection = mysql.createConnection({
    host: '192.168.0.132',
    user: 'node_js',
    password: {PASSWORT},
    database: 'eis_monitoring'
});

connection.connect(error => {
    if (error) throw error;
    console.log('Die Verbindung war erfolgreich.');
});

module.exports = connection;

