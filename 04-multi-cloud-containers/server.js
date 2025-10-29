const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use(limiter);

// In-memory storage (replace with database in production)
let books = [
  {
    id: '1',
    title: 'The DevOps Handbook',
    author: 'Gene Kim',
    isbn: '978-1942788003',
    publishedYear: 2016,
    genre: 'Technology',
    description: 'A comprehensive guide to DevOps practices and principles.',
    price: 29.99,
    stock: 15,
    createdAt: new Date().toISOString()
  },
  {
    id: '2',
    title: 'Kubernetes in Action',
    author: 'Marko Luksa',
    isbn: '978-1617293726',
    publishedYear: 2017,
    genre: 'Technology',
    description: 'Learn Kubernetes from the ground up.',
    price: 39.99,
    stock: 8,
    createdAt: new Date().toISOString()
  },
  {
    id: '3',
    title: 'Terraform: Up & Running',
    author: 'Yevgeniy Brikman',
    isbn: '978-1492046905',
    publishedYear: 2019,
    genre: 'Technology',
    description: 'Infrastructure as Code with Terraform.',
    price: 34.99,
    stock: 12,
    createdAt: new Date().toISOString()
  }
];

// Middleware for logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to the Bookstore API',
    version: '1.0.0',
    endpoints: {
      books: '/api/books',
      health: '/health',
      metrics: '/metrics'
    },
    timestamp: new Date().toISOString()
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    memory: process.memoryUsage(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// Metrics endpoint
app.get('/metrics', (req, res) => {
  res.json({
    totalBooks: books.length,
    totalStock: books.reduce((sum, book) => sum + book.stock, 0),
    averagePrice: books.reduce((sum, book) => sum + book.price, 0) / books.length,
    genres: [...new Set(books.map(book => book.genre))],
    uptime: process.uptime(),
    memoryUsage: process.memoryUsage(),
    timestamp: new Date().toISOString()
  });
});

// Get all books
app.get('/api/books', (req, res) => {
  const { genre, author, search, limit = 10, offset = 0 } = req.query;
  let filteredBooks = [...books];

  // Filter by genre
  if (genre) {
    filteredBooks = filteredBooks.filter(book => 
      book.genre.toLowerCase().includes(genre.toLowerCase())
    );
  }

  // Filter by author
  if (author) {
    filteredBooks = filteredBooks.filter(book => 
      book.author.toLowerCase().includes(author.toLowerCase())
    );
  }

  // Search in title and description
  if (search) {
    filteredBooks = filteredBooks.filter(book => 
      book.title.toLowerCase().includes(search.toLowerCase()) ||
      book.description.toLowerCase().includes(search.toLowerCase())
    );
  }

  // Pagination
  const startIndex = parseInt(offset);
  const endIndex = startIndex + parseInt(limit);
  const paginatedBooks = filteredBooks.slice(startIndex, endIndex);

  res.json({
    books: paginatedBooks,
    pagination: {
      total: filteredBooks.length,
      limit: parseInt(limit),
      offset: parseInt(offset),
      hasMore: endIndex < filteredBooks.length
    }
  });
});

// Get book by ID
app.get('/api/books/:id', (req, res) => {
  const book = books.find(b => b.id === req.params.id);
  
  if (!book) {
    return res.status(404).json({ error: 'Book not found' });
  }
  
  res.json(book);
});

// Create new book
app.post('/api/books', (req, res) => {
  const { title, author, isbn, publishedYear, genre, description, price, stock } = req.body;
  
  // Validation
  if (!title || !author || !isbn || !price) {
    return res.status(400).json({ 
      error: 'Missing required fields: title, author, isbn, price' 
    });
  }

  // Check if ISBN already exists
  if (books.find(book => book.isbn === isbn)) {
    return res.status(409).json({ error: 'Book with this ISBN already exists' });
  }

  const newBook = {
    id: uuidv4(),
    title,
    author,
    isbn,
    publishedYear: publishedYear || new Date().getFullYear(),
    genre: genre || 'General',
    description: description || '',
    price: parseFloat(price),
    stock: parseInt(stock) || 0,
    createdAt: new Date().toISOString()
  };

  books.push(newBook);
  
  res.status(201).json(newBook);
});

// Update book
app.put('/api/books/:id', (req, res) => {
  const bookIndex = books.findIndex(b => b.id === req.params.id);
  
  if (bookIndex === -1) {
    return res.status(404).json({ error: 'Book not found' });
  }

  const updatedBook = {
    ...books[bookIndex],
    ...req.body,
    id: req.params.id, // Ensure ID doesn't change
    updatedAt: new Date().toISOString()
  };

  books[bookIndex] = updatedBook;
  
  res.json(updatedBook);
});

// Delete book
app.delete('/api/books/:id', (req, res) => {
  const bookIndex = books.findIndex(b => b.id === req.params.id);
  
  if (bookIndex === -1) {
    return res.status(404).json({ error: 'Book not found' });
  }

  const deletedBook = books.splice(bookIndex, 1)[0];
  
  res.json({ message: 'Book deleted successfully', book: deletedBook });
});

// Purchase book (reduce stock)
app.post('/api/books/:id/purchase', (req, res) => {
  const book = books.find(b => b.id === req.params.id);
  const { quantity = 1 } = req.body;
  
  if (!book) {
    return res.status(404).json({ error: 'Book not found' });
  }

  if (book.stock < quantity) {
    return res.status(400).json({ 
      error: 'Insufficient stock',
      available: book.stock,
      requested: quantity
    });
  }

  book.stock -= quantity;
  
  res.json({
    message: 'Purchase successful',
    book: book,
    purchased: quantity,
    total: book.price * quantity
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    error: 'Something went wrong!',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ 
    error: 'Route not found',
    path: req.originalUrl,
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Bookstore API server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});