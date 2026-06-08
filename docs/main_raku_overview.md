# main.raku - Happy Numbers Web Server

## Overview

`main.raku` is the entry point for the Happy Numbers web application. It implements a lightweight HTTP server written in Raku (formerly Perl 6) that allows users to calculate happy numbers with customizable parameters.

## What is a Happy Number?

A happy number is a number defined by the following process:
1. Start with any positive integer
2. Replace the number by the sum of the squares of its digits
3. Repeat the process until the number equals 1 (happy) or it loops endlessly in a cycle that does not include 1 (sad)

For example, 7 is a happy number:
- 7 → 49 → 97 → 130 → 10 → 1

## Server Architecture

### Network Setup
- **Host**: 0.0.0.0 (listens on all interfaces)
- **Port**: 5000
- **Protocol**: HTTP/1.1

### Request Handling
The server:
1. Accepts client connections
2. Parses HTTP GET requests
3. Extracts query parameters (limit, base, pow, pure)
4. Calculates happy numbers using the `HappyNumbers::Calculator` module
5. Generates HTML response with formatted results
6. Sends HTTP response with appropriate headers

## Key Features

### 1. **Customizable Parameters**
- **limit**: Maximum number to check (default: 9, range: 1-1000)
- **base**: Number base for calculations (default: 10, range: 2-36)
- **pow**: Exponent for digit calculation (default: 2, range: 1-10)
- **pure**: Flag to filter pure happy numbers

### 2. **Result Visualization**
- **Summary Statistics**: Count of happy/pure happy numbers
- **Interactive Hash Table**: Browse all calculated numbers with their properties
- **Tree View**: Visual representation of number chains showing happy/sad classification
- **Sequences**: Display the calculation path for each number

### 3. **HTML Response**
- Responsive, clean UI with modern styling
- Interactive navigation with smooth scrolling
- Collapsible details sections for different data views
- Inline JavaScript for enhanced user interaction

## Code Structure

### Main Loop (Lines 16-77)
Accepts incoming HTTP connections and processes requests in a continuous loop:
- Accepts client socket
- Reads HTTP request headers
- Parses method and path
- Extracts query parameters
- Generates response body
- Sends formatted HTTP response

### HTML Generation Functions

#### `build-results-html($result)` (Lines 197-244)
Formats calculation results into HTML:
- Displays summary statistics
- Creates interactive hash table of numbers
- Shows tree visualization
- Lists sequences for each number

#### `build-tree-html(%happiness)` (Lines 80-195)
Generates tree visualization of number chains:
- Creates reverse mapping of number chains
- Identifies root nodes
- Handles cycles and disconnected components
- Prevents infinite loops in rendering
- Colors nodes as happy (green) or sad (red)

#### `default-template()` (Lines 246-299)
Provides HTML template with:
- CSS styling for responsive design
- Form for parameter input
- Placeholder for results injection
- JavaScript helper function for interactive navigation

## Parameter Validation

The server enforces safe ranges for all parameters:

```
limit:  1 ≤ limit ≤ 1000
base:   2 ≤ base ≤ 36
pow:    1 ≤ pow ≤ 10
pure:   boolean flag
```

## Dependencies

- **HappyNumbers Module**: Custom Raku module for calculations
- **IO::Socket::INET**: Network socket handling
- **templates.html**: Optional external template file

## How It Works

1. **Server Starts**: Listens on port 5000
2. **User Submits Form**: Provides limit, base, power parameters
3. **Calculation**: Calls `HappyNumbers::Calculator` to compute results
4. **Rendering**: Injects results into HTML template
5. **Response**: Sends formatted HTTP response to client
6. **Display**: Browser renders interactive results page

## File I/O

- Attempts to load `templates.html` from current directory
- Falls back to embedded template if external file not found
- Allows for customization without code changes

## Response Format

All responses are HTTP/1.1 with:
- Content-Type: text/html; charset=utf-8
- Content-Length: calculated from response body
- Connection: close (after single response)

## Performance Considerations

- Validates input ranges to prevent excessive computation
- Limits calculations to 1000 numbers maximum
- Uses efficient string substitution for template rendering
- Single-threaded request handling (processes one at a time)
