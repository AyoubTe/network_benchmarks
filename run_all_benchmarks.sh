#!/bin/bash
set -e

OUTPUT_DIR="./benchmark_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ITERATIONS=5

mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "Running Network Benchmarks"
echo "Configuration: $(kubectl config current-context 2>/dev/null || echo 'Unknown')"
echo "Timestamp: $TIMESTAMP"
echo "Iterations: $ITERATIONS"
echo "========================================"
echo ""

# Function to run benchmark multiple times
run_benchmark() {
    local ACTION_NAME=$1
    local LANG=$2
    
    echo "Testing $LANG benchmark ($ACTION_NAME)..."
    
    for i in $(seq 1 $ITERATIONS); do
        echo "  Iteration $i/$ITERATIONS..."
        
        RESULT_FILE="$OUTPUT_DIR/${ACTION_NAME}_${TIMESTAMP}_iter${i}.json"
        
        # Measure cold start (delete and recreate action)
        if [ "$i" -eq 1 ]; then
            echo "    (Cold start measurement)"
            wsk -i action delete "$ACTION_NAME" 2>/dev/null || true
            
            if [ "$LANG" == "python" ]; then
                wsk -i action create "$ACTION_NAME" python/network_benchmark.py --kind python:3.9 >/dev/null
            elif [ "$LANG" == "javascript" ]; then
                wsk -i action create "$ACTION_NAME" javascript/network_benchmark.js --kind nodejs:14 >/dev/null
            elif [ "$LANG" == "java" ]; then
                wsk -i action create "$ACTION_NAME" java/target/network-benchmark-1.0.jar --main NetworkBenchmark --kind java:8 >/dev/null
            fi
            
            sleep 2
        fi
        
        # Invoke and save result
        START_TIME=$(date +%s%N)
        wsk -i action invoke "$ACTION_NAME" --result > "$RESULT_FILE"
        END_TIME=$(date +%s%N)
        
        INVOCATION_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)
        echo "    Invocation time: ${INVOCATION_TIME}s"
        
        # Add metadata to result file
        TMP_FILE=$(mktemp)
        jq ". + {invocation_time_s: $INVOCATION_TIME, iteration: $i, cold_start: $([ "$i" -eq 1 ] && echo true || echo false)}" "$RESULT_FILE" > "$TMP_FILE"
        mv "$TMP_FILE" "$RESULT_FILE"
        
        sleep 5
    done
    
    echo ""
}

# Run benchmarks for each language
run_benchmark "network-bench-python" "python"
run_benchmark "network-bench-js" "javascript"
run_benchmark "network-bench-java" "java"

echo "========================================"
echo "Benchmarks Complete!"
echo "Results saved to: $OUTPUT_DIR"
echo "========================================"
echo ""
echo "To analyze results:"
echo "  python3 analyze_results.py '$OUTPUT_DIR/network-bench-python_*.json' '$OUTPUT_DIR/network-bench-js_*.json'"