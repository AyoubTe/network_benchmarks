#!/bin/bash
set -e

echo "Deploying Network Benchmarks to OpenWhisk..."

# Python
echo "Deploying Python benchmark..."
wsk -i action delete network-bench-python 2>/dev/null || true
wsk -i action create network-bench-python \
    python/network_benchmark.py \
    --kind python:3

# JavaScript
echo "Deploying JavaScript benchmark..."
wsk -i action delete network-bench-js 2>/dev/null || true
wsk -i action create network-bench-js \
    javascript/network_benchmark.js \
    --kind nodejs:14


# Java
echo "Deploying Java benchmark..."
echo "  Building Java JAR with Maven..."
cd java
mvn clean package -q
cd ..

wsk -i action delete network-bench-java 2>/dev/null || true
wsk -i action create network-bench-java \
    java/target/network-benchmark-1.0.jar \
    --main NetworkBenchmark \
    --kind java:8

echo ""
echo "Deployment complete!"
echo ""
echo "Test the benchmarks:"
echo "  wsk -i action invoke network-bench-python --result"
echo "  wsk -i action invoke network-bench-js --result"
echo "  wsk -i action invoke network-bench-java --result"