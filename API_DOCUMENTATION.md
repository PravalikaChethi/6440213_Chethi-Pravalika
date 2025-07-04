# API Documentation

## Project Overview
This documentation covers three main modules:
- **MODULE 1**: Web Development (HTML/CSS/JavaScript/Bootstrap)
- **MODULE 2**: Database Operations (SQL)
- **MODULE 3**: Core Java Programming

## MODULE 1: Web Development

### HTML Components (`index.html`)

#### Navigation API
```html
<nav>
  <a href="#home">Home</a>
  <a href="#events">Events</a>
  <a href="#contact">Contact</a>
</nav>
```
**Usage**: Primary navigation for the community portal

#### Event Registration Form
```html
<form onsubmit="showConfirmation(); return false;">
  <input type="text" placeholder="Your Name" required autofocus>
  <input type="email" placeholder="Your Email" required>
  <!-- Additional form fields -->
</form>
```
**APIs Used**: 
- `showConfirmation()` - Displays registration confirmation
- `validatePhone()` - Validates phone number format
- `countChars()` - Character counter for feedback

### JavaScript Functions

#### Core Utility Functions
```javascript
function getRandomColor() {
  const colors = ["red", "green", "blue", "orange"];
  const index = Math.floor(Math.random() * colors.length);
  return colors[index];
}
```
**Returns**: Random color string
**Usage**: Dynamic UI color changes

#### Form Validation Functions
```javascript
function validatePhone() {
  const phone = document.getElementById('phone').value;
  if (!/^\d{10}$/.test(phone)) {
    alert("Invalid phone number");
  }
}
```
**Parameters**: None (reads from DOM)
**Validation**: 10-digit phone number format

#### Geolocation API
```javascript
function findNearby() {
  navigator.geolocation.getCurrentPosition(
    (pos) => {
      const coords = pos.coords;
      document.getElementById("locationInfo").innerText = 
        `Latitude: ${coords.latitude}, Longitude: ${coords.longitude}`;
    }
  );
}
```
**Returns**: User's current coordinates
**Error Handling**: Displays error message on failure

### CSS Classes & Utilities

#### Layout Classes
- `.container` - Main content wrapper with centered layout
- `.event-img` - Styled event images (100x100px with border)
- `.highlight` - Yellow background highlight for important text

#### Form Styling
- `form input, form select, form textarea` - Unified form element styling
- `form button` - Primary action button styling with hover effects

### Bootstrap Components

#### Grid System
```html
<div class="container">
  <div class="row">
    <div class="col-md-4">Content</div>
    <div class="col-md-8">Main</div>
  </div>
</div>
```
**Breakpoints**: `col-sm-*`, `col-md-*`, `col-lg-*`

#### Navigation Components
```html
<nav class="navbar navbar-expand-lg navbar-light bg-light">
  <a class="navbar-brand" href="#">Logo</a>
  <form class="d-flex">
    <input class="form-control me-2" type="search">
    <button class="btn btn-outline-success">Search</button>
  </form>
</nav>
```

#### Modal Component
```html
<button data-bs-toggle="modal" data-bs-target="#exampleModal">
  Launch Modal
</button>
<div class="modal fade" id="exampleModal">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title">Title</h5>
      </div>
      <div class="modal-body">Content</div>
    </div>
  </div>
</div>
```

## MODULE 2: Database Operations

### Event Management Queries

#### User Event Retrieval
```sql
SELECT u.full_name, e.title, e.start_date
FROM Users u
JOIN Registrations r ON u.user_id = r.user_id
JOIN Events e ON r.event_id = e.event_id
WHERE e.status = 'upcoming' AND u.city = e.city
ORDER BY e.start_date;
```
**Purpose**: Get upcoming events for users in their city
**Returns**: User name, event title, start date

#### Event Rating Analysis
```sql
SELECT e.title, AVG(f.rating) AS avg_rating, COUNT(*) AS feedback_count
FROM Feedback f
JOIN Events e ON f.event_id = e.event_id
GROUP BY e.event_id
HAVING COUNT(*) >= 10
ORDER BY avg_rating DESC;
```
**Purpose**: Find top-rated events with significant feedback
**Minimum**: 10+ feedback entries required

### User Analytics Queries

#### Inactive User Detection
```sql
SELECT * FROM Users
WHERE user_id NOT IN (
  SELECT user_id FROM Registrations
  WHERE registration_date >= CURDATE() - INTERVAL 90 DAY
);
```
**Purpose**: Identify users inactive for 90+ days
**Use Case**: Re-engagement campaigns

#### City Activity Analysis
```sql
SELECT u.city, COUNT(DISTINCT r.user_id) AS total_users
FROM Users u
JOIN Registrations r ON u.user_id = r.user_id
GROUP BY u.city
ORDER BY total_users DESC
LIMIT 5;
```
**Returns**: Top 5 most active cities by user registration

### Session Management

#### Peak Hours Analysis
```sql
SELECT e.title, COUNT(*) AS session_count
FROM Sessions s
JOIN Events e ON s.event_id = e.event_id
WHERE TIME(s.start_time) BETWEEN '10:00:00' AND '11:59:59'
GROUP BY s.event_id;
```
**Time Range**: 10 AM - 12 PM analysis
**Purpose**: Optimize session scheduling

## MODULE 3: Core Java Programming

### Basic Utilities (Exercises 1-20)

#### Calculator Class
```java
public class Calculator {
    public static void main(String[] args) {
        // Supports +, -, *, / operations
        // Includes division by zero protection
    }
}
```
**Features**: Basic arithmetic with error handling

#### Data Type Demonstration
```java
public class DataTypes {
    public static void main(String[] args) {
        int i = 10;
        float f = 3.14f;
        double d = 3.14159;
        char c = 'A';
        boolean b = true;
    }
}
```
**Purpose**: Showcase Java primitive types

#### Factorial Calculator
```java
public static int factorial(int n) {
    return (n == 0) ? 1 : n * factorial(n - 1);
}
```
**Algorithm**: Recursive implementation
**Base Case**: factorial(0) = 1

#### Method Overloading Example
```java
static int add(int a, int b) { return a + b; }
static double add(double a, double b) { return a + b; }
static int add(int a, int b, int c) { return a + b + c; }
```
**Demonstrates**: Compile-time polymorphism

### Object-Oriented Programming

#### Car Class
```java
class Car {
    String make, model;
    int year;
    
    Car(String make, String model, int year) {
        this.make = make;
        this.model = model;
        this.year = year;
    }
    
    void displayDetails() {
        System.out.println("Make: " + make + ", Model: " + model + ", Year: " + year);
    }
}
```
**Features**: Constructor, instance variables, methods

#### Inheritance Example
```java
class Animal {
    void makeSound() { System.out.println("Some sound"); }
}

class Dog extends Animal {
    @Override
    void makeSound() { System.out.println("Bark"); }
}
```
**Concept**: Method overriding in inheritance

#### Interface Implementation
```java
interface Playable {
    void play();
}

class Guitar implements Playable {
    public void play() {
        System.out.println("Strumming the guitar");
    }
}
```

### Advanced Features (Exercises 21-41)

#### Custom Exception Handling
```java
class InvalidAgeException extends Exception {
    public InvalidAgeException(String message) {
        super(message);
    }
}
```
**Usage**: Custom validation for age-related operations

#### File I/O Operations
```java
// File Writing
BufferedWriter writer = new BufferedWriter(new FileWriter("output.txt"));
writer.write(text);
writer.close();

// File Reading
BufferedReader reader = new BufferedReader(new FileReader("output.txt"));
String line;
while ((line = reader.readLine()) != null) {
    System.out.println(line);
}
```

#### Collections Framework

##### ArrayList Implementation
```java
ArrayList<String> students = new ArrayList<>();
students.add(name);
for (String s : students) {
    System.out.println(s);
}
```

##### HashMap Usage
```java
HashMap<Integer, String> students = new HashMap<>();
students.put(id, name);
String student = students.getOrDefault(lookupId, "Not Found");
```

#### Multithreading
```java
class MyThread extends Thread {
    public void run() {
        System.out.println("Running in " + Thread.currentThread().getName());
    }
}
```

#### Lambda Expressions & Streams
```java
// Lambda sorting
Collections.sort(names, (a, b) -> a.compareToIgnoreCase(b));

// Stream filtering
List<Integer> even = numbers.stream()
    .filter(n -> n % 2 == 0)
    .collect(Collectors.toList());
```

#### Records (Java 14+)
```java
record Person(String name, int age) {}

// Usage with streams
people.stream()
      .filter(p -> p.age() >= 21)
      .forEach(System.out::println);
```

#### JDBC Database Operations
```java
// Connection
Connection conn = DriverManager.getConnection("jdbc:sqlite:students.db");

// Insert operation
PreparedStatement ps = conn.prepareStatement("INSERT INTO students (id, name) VALUES (?, ?)");
ps.setInt(1, id);
ps.setString(2, name);
ps.executeUpdate();
```

#### Network Programming
```java
// Server
ServerSocket server = new ServerSocket(1234);
Socket socket = server.accept();

// Client
Socket socket = new Socket("localhost", 1234);
```

#### HTTP Client API (Java 11+)
```java
HttpClient client = HttpClient.newHttpClient();
HttpRequest request = HttpRequest.newBuilder()
        .uri(URI.create("https://api.github.com"))
        .build();
HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
```

#### Reflection API
```java
Class<?> cls = Class.forName("java.lang.String");
Method[] methods = cls.getDeclaredMethods();
for (Method m : methods) {
    System.out.println(m.getName());
}
```

#### Virtual Threads (Java 21)
```java
for (int i = 0; i < 100_000; i++) {
    Thread.startVirtualThread(() -> System.out.println("Running virtual thread"));
}
```

#### ExecutorService & Callable
```java
ExecutorService executor = Executors.newFixedThreadPool(3);
List<Callable<String>> tasks = List.of(
    () -> "Task 1",
    () -> "Task 2",
    () -> "Task 3"
);
List<Future<String>> results = executor.invokeAll(tasks);
```

## Usage Examples

### Frontend Integration
```javascript
// Event registration workflow
document.getElementById("registerBtn").onclick = function() {
    if (validatePhone()) {
        showConfirmation();
        savePreference();
    }
};
```

### Database Integration
```sql
-- Complete event management query
SELECT e.title, COUNT(DISTINCT r.user_id) AS registrations,
       AVG(f.rating) AS avg_rating
FROM Events e
LEFT JOIN Registrations r ON e.event_id = r.event_id
LEFT JOIN Feedback f ON e.event_id = f.event_id
WHERE e.status = 'completed'
GROUP BY e.event_id;
```

### Java Application Structure
```java
public class EventManagementApp {
    private Database db;
    private WebInterface ui;
    
    public void initialize() {
        db = new Database();
        ui = new WebInterface();
        ui.setEventHandler(this::handleEvent);
    }
}
```

## Error Handling

### JavaScript
- Form validation with user feedback
- Geolocation error handling
- Network request error management

### SQL
- JOIN operations with proper NULL handling
- Data validation in WHERE clauses
- Transaction rollback capabilities

### Java
- Try-catch for exception management
- Custom exceptions for business logic
- Resource management with try-with-resources

## Performance Considerations

- **Frontend**: Use event delegation for dynamic content
- **Database**: Proper indexing on JOIN columns
- **Java**: Use Stream API for large data processing
- **Threading**: Virtual threads for high-concurrency applications

## Security Best Practices

- Input validation in all forms
- Prepared statements for SQL queries
- Proper exception handling without exposing internal details
- HTTPS for API communications