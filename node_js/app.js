const express = require('express');
const cors = require('cors');

const app = express();

const whitelist = ['http://82.194.143.119'];

const corsOptions = {
    origin: function (origin, callback) {
        if (whitelist.includes(origin)) {
            callback(null, true)
        } else {
            callback(new Error('Not allowed by CORS'))
        }
    }
};

app.use(cors());

app.use(express.json());
app.use(express.static(__dirname + '/public')); //Server soll ordner /pics zur Verfügung stellen

// Middleware for authentication only for non-GET requests
app.use((req, res, next) => {
    if (req.method !== 'GET') {
        const token = authHeader.split(' ')[1];
        const validToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
        if (token !== validToken) {
            return res.status(401).json({ error: 'Unauthorized' });
        }
    }
    next();
});

const routes = require('./routes'); 
app.use('/', routes);

const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server is running on port ${PORT}.`);
});
