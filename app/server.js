// Basic Express server example
// If you use the 'tasky' app from [https://github.com/jeffthorne/tasky](https://github.com/jeffthorne/tasky)
// you would use its server.js or adapt it

const express = require('express');
const mongoose = require('mongoose');
const path =require('path'); // Required for serving static files if you have a frontend

const app = express();
const port = process.env.PORT || 3000;

// Middleware to parse JSON
app.use(express.json());

// MongoDB Connection URI from environment variable (passed by Kubernetes secret)
const mongoURI = process.env.MONGODB_URI;

if (!mongoURI) {
    console.error("FATAL ERROR: MONGODB_URI environment variable is not set.");
    process.exit(1); // Exit if DB connection string is missing
}

mongoose.connect(mongoURI, { useNewUrlParser: true, useUnifiedTopology: true })
    .then(() => console.log('MongoDB Connected successfully!'))
    .catch(err => {
        console.error('MongoDB connection error:', err);
        process.exit(1); // Exit if DB connection fails
    });

// Basic schema and model (example)
const itemSchema = new mongoose.Schema({
    name: String,
    date: { type: Date, default: Date.now }
});
const Item = mongoose.model('Item', itemSchema);

// Basic Routes
app.get('/', (req, res) => {
    res.send('Wiz Technical Exercise Web App is running! Try /items to see data.');
});

// Get all items
app.get('/items', async (req, res) => {
    try {
        const items = await Item.find();
        res.json(items);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// Create an item
app.post('/items', async (req, res) => {
    const newItem = new Item({
        name: req.body.name
    });
    try {
        const savedItem = await newItem.save();
        res.status(201).json(savedItem);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// Serve wizexercise.txt for verification
app.get('/wizexercise.txt', (req, res) => {
  res.sendFile(path.join(__dirname, 'wizexercise.txt'));
});


app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
