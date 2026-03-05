#!/bin/bash
set -e

OUTPUT_DIR="./results_python_hot"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ITERATIONS=5
ACTION_NAME="network-bench-python"

mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "PYTHON - HOT START Benchmark"
echo "========================================"
echo "Configuration: $(hostname)"
echo "Timestamp: $TIMESTAMP"
echo "Iterations: $ITERATIONS"
echo "Action: $ACTION_NAME"
echo "========================================"
echo ""

# Ensure action exists and is warmed up
echo "Setting up action..."
wsk -i action delete "$ACTION_NAME" 2>/dev/null || true
wsk -i action create "$ACTION_NAME" \
    ../python/network_benchmark.py \
    --kind python:3 >/dev/null

# Warm up with one invocation
echo "Warming up action..."
wsk -i action invoke "$ACTION_NAME" --result >/dev/null
sleep 3
echo ""

for i in $(seq 1 $ITERATIONS); do
    echo "Iteration $i/$ITERATIONS (HOT START)"
    echo "----------------------------------------"
    
    # Invoke without deleting (hot start)
    RESULT_FILE="$OUTPUT_DIR/python_hot_${TIMESTAMP}_iter${i}.json"
    echo "  Invoking action (keeping pod alive)..."
    
    START_TIME=$(date +%s%N)
    wsk -i action invoke "$ACTION_NAME" --result > "$RESULT_FILE"
    END_TIME=$(date +%s%N)
    
    INVOCATION_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)
    
    # Add metadata
    TMP_FILE=$(mktemp)
    jq ". + {
        invocation_time_s: $INVOCATION_TIME, 
        iteration: $i, 
        cold_start: false,
        language: \"python\",
        timestamp: \"$TIMESTAMP\",
        hostname: \"$(hostname)\"
    }" "$RESULT_FILE" > "$TMP_FILE"
    mv "$TMP_FILE" "$RESULT_FILE"
    
    echo "  ✓ Invocation time: ${INVOCATION_TIME}s"
    echo "  ✓ Saved to: $RESULT_FILE"
    echo ""
    
    # Small wait to avoid rate limiting
    sleep 2
done

echo "========================================"
echo "PYTHON HOT START - Complete!"
echo "Results in: $OUTPUT_DIR"
echo "Total files: $(ls -1 $OUTPUT_DIR | wc -l)"
echo "========================================"