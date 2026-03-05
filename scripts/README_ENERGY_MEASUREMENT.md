# Energy Measurement Guide

## Overview

Each script runs a specific language in a specific start mode (cold or hot):

- **Cold Start**: Action is deleted and recreated before each invocation
- **Hot Start**: Action stays alive, pod is reused across invocations

## Individual Scripts

### Python
```bash
./python_cold.sh      # 5 iterations, cold start
./python_hot.sh       # 5 iterations, hot start
```

### JavaScript  
```bash
./javascript_cold.sh  # 5 iterations, cold start
./javascript_hot.sh   # 5 iterations, hot start
```

### Java
```bash
./java_cold.sh        # 5 iterations, cold start
./java_hot.sh         # 5 iterations, hot start
```

## Run All at Once
```bash
./run_all_measurements.sh
```

This runs all 6 scenarios sequentially with 30-second breaks between each.

## Energy Measurement Workflow

### For Each Cluster:

1. **Start your power meter/energy monitoring**

2. **Run a specific benchmark**:
```bash
   ./python_cold.sh
```

3. **Record energy consumption** for that specific run

4. **Wait for system to stabilize** (30-60 seconds)

5. **Repeat for next language/mode**

### Example Measurement Session:
```bash
# Measure Python cold start energy
echo "Starting Python Cold Start measurement..."
# Start energy meter NOW
./python_cold.sh
# Stop energy meter, record: Python_Cold_Energy = X joules

sleep 60  # Let system cool down

# Measure Python hot start energy  
echo "Starting Python Hot Start measurement..."
# Start energy meter NOW
./python_hot.sh
# Stop energy meter, record: Python_Hot_Energy = Y joules

# ... repeat for other languages
```

## Results Structure

Each script creates its own directory:
- `results_python_cold/` - Python cold start results
- `results_python_hot/` - Python hot start results
- `results_javascript_cold/` - JavaScript cold start results
- `results_javascript_hot/` - JavaScript hot start results
- `results_java_cold/` - Java cold start results
- `results_java_hot/` - Java hot start results

## Analysis

After collecting results from both clusters:
```bash
# Analyze all results
./analyze_by_language.py

# This shows:
# - Invocation times for each scenario
# - Network metrics (TCP, HTTP, bandwidth)
# - Statistical comparison
```

## For Your Research Paper

Create a table like this:

| Language | Start Type | Cluster | Energy (J) | Avg Time (s) | TCP Lat (ms) | HTTP Lat (ms) |
|----------|-----------|---------|------------|--------------|--------------|---------------|
| Python   | Cold      | VM+Cont | 125.3      | 2.451        | 8.5          | 145.2         |
| Python   | Cold      | MicroVM | 98.7       | 2.123        | 7.8          | 132.1         |
| Python   | Hot       | VM+Cont | 45.2       | 0.823        | 8.3          | 142.8         |
| Python   | Hot       | MicroVM | 38.1       | 0.751        | 7.9          | 130.5         |
| ...      | ...       | ...     | ...        | ...          | ...          | ...           |

## Important Notes

1. **Run on BOTH clusters** (VM+Container and MicroVM)
2. **Measure energy separately** for each script execution
3. **Wait between measurements** to avoid thermal effects
4. **Record cluster configuration** (hardware, network, etc.)
5. **Use the same network endpoints** on both clusters for fair comparison

## Prerequisites

- `wsk` CLI configured
- `jq` installed
- `bc` installed  
- Python 3 with json module
- Maven (for Java benchmarks)