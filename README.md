# Network Benchmarks for Serverless Functions

These benchmarks are commonly used in serverless research papers to measure network performance.

## Benchmarks Included

### 1. TCP Latency Benchmark
- **Purpose**: Measures time to establish a TCP connection
- **Metric**: Connection establishment time in milliseconds
- **Research Use**: Cold start analysis, inter-service communication latency
- **Common in papers**: "Serverless in the Wild" (Berkeley), "SAND: Towards High-Performance Serverless Computing"

### 2. HTTP Request Latency Benchmark
- **Purpose**: Measures end-to-end HTTP request time
- **Metric**: Full HTTP GET request time in milliseconds
- **Research Use**: API latency analysis, function-to-function communication
- **Common in papers**: "Characterizing Serverless Platforms with ServerlessBench", "Peeking Behind the Curtains of Serverless Platforms"

### 3. DNS Resolution Benchmark
- **Purpose**: Measures DNS lookup time
- **Metric**: DNS query resolution time in milliseconds
- **Research Use**: Cold start overhead, network setup latency
- **Common in papers**: "The State of Serverless Applications: Collection, Characterization, and Community Consensus"

### 4. Bandwidth Benchmark
- **Purpose**: Measures download speed
- **Metric**: Throughput in Mbps
- **Research Use**: Data-intensive workload analysis, inter-function data transfer
- **Common in papers**: "ServerlessBench: A Performance Evaluation Framework for Serverless Computing", "Benchmarking Edge Computing"

## Deployment to OpenWhisk

### Python
```bash
# Create the action
wsk -i action create network-bench-python \
    /tmp/network-benchmarks/python/network_benchmark.py \
    --kind python:3.9

# Invoke it
wsk -i action invoke network-bench-python --result
```

### JavaScript (Node.js)
```bash
# Create the action
wsk -i action create network-bench-js \
    /tmp/network-benchmarks/javascript/network_benchmark.js \
    --kind nodejs:14

# Invoke it
wsk -i action invoke network-bench-js --result
```

### Java
```bash
# Build the JAR (requires Maven)
cd /tmp/network-benchmarks/java
mvn clean package

# Create the action
wsk -i action create network-bench-java \
    target/network-benchmark-1.0.jar \
    --main NetworkBenchmark \
    --kind java:8

# Invoke it
wsk -i action invoke network-bench-java --result
```

## Running Benchmarks for Your Research

### For VM + Container Configuration (Cluster 1)
Deploy and run each benchmark 5 times on your VM+Container cluster:
```bash
# Run 5 iterations
for i in {1..5}; do
    echo "Iteration $i"
    wsk -i action invoke network-bench-python --result > results_vm_python_$i.json
    sleep 5
done
```

### For MicroVM Configuration (Cluster 2)
Deploy and run each benchmark 5 times on your Kata+Firecracker cluster:
```bash
# Run 5 iterations
for i in {1..5}; do
    echo "Iteration $i"
    wsk -i action invoke network-bench-python --result > results_microvm_python_$i.json
    sleep 5
done
```

## Measuring Cold Start vs Hot Start
```bash
# Cold start - delete and recreate
wsk -i action delete network-bench-python
wsk -i action create network-bench-python python/network_benchmark.py --kind python:3.9
time wsk -i action invoke network-bench-python --result

# Hot start - immediate second invocation
time wsk -i action invoke network-bench-python --result
```

## Output Format

All benchmarks return JSON with this structure:
```json
{
  "timestamp": 1709563200000,
  "benchmarks": {
    "tcp_latency": {
      "metric": "tcp_latency",
      "iterations": 10,
      "min_ms": 5.2,
      "max_ms": 12.8,
      "avg_ms": 8.5,
      "median_ms": 8.1,
      "stdev_ms": 2.3,
      "latencies_ms": [5.2, 8.1, 7.9, ...]
    },
    "http_latency": { ... },
    "dns_resolution": { ... },
    "bandwidth": {
      "bandwidth_mbps": 45.2,
      ...
    }
  }
}
```

# Network Benchmarks - Quick Start Guide

## 1. Extract the Archive
```bash
tar -xzf network-benchmarks.tar.gz
cd network-benchmarks
```

## 2. Deploy All Benchmarks
```bash
./deploy_all.sh
```

This will:
- Build the Java JAR using Maven
- Deploy Python, JavaScript, and Java benchmarks to OpenWhisk
- Create actions: `network-bench-python`, `network-bench-js`, `network-bench-java`

## 3. Run All Benchmarks (5 iterations each)
```bash
./run_all_benchmarks.sh
```

This will:
- Run each benchmark 5 times
- Measure cold start (1st iteration) and hot start (iterations 2-5)
- Save results to `./benchmark_results/` directory
- Include invocation time metadata in each result

## 4. Compare Configurations

After running benchmarks on both clusters (VM+Container and MicroVM):
```bash
# Analyze Python results from both clusters
python3 analyze_results.py \
    'cluster1_results/network-bench-python_*.json' \
    'cluster2_results/network-bench-python_*.json'
```

## What Gets Measured

Each benchmark measures:
- **TCP Latency**: Time to establish TCP connection (to 8.8.8.8:53)
- **HTTP Latency**: End-to-end HTTP GET request time (to httpbin.org)
- **DNS Resolution**: DNS lookup time (for google.com)
- **Bandwidth**: Download speed in Mbps (1MB test file)

All with min/max/avg/median/stdev statistics across 10 iterations per metric.

## Research Paper References

These benchmarks are based on methodologies from:

1. **ServerlessBench** - UC Berkeley
2. **FunctionBench** - George Mason University  
3. **ENSURE** - Princeton University
4. **SeBS** - ETH Zurich Serverless Benchmark Suite