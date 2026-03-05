#!/bin/bash
set -e

OUTPUT_DIR="./results_javascript_cold"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ITERATIONS=5
ACTION_NAME="network-bench-js"

mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "JAVASCRIPT - COLD START Benchmark"
echo "========================================"
echo "Configuration: $(hostname)"
echo "Timestamp: $TIMESTAMP"
echo "Iterations: $ITERATIONS"
echo "Action: $ACTION_NAME"
echo "========================================"
echo ""

for i in $(seq 1 $ITERATIONS); do
    echo "Iteration $i/$ITERATIONS (COLD START)"
    echo "----------------------------------------"
    
    # Find and delete the specific pod for this action
    echo "  Finding and deleting pod for $ACTION_NAME..."
    POD_NAME=$(kubectl get pods -n openwhisk | grep "networkbenchjs" | awk '{print $1}' | head -1)
    if [ -n "$POD_NAME" ]; then
        echo "  Deleting pod: $POD_NAME"
        kubectl delete pod "$POD_NAME" -n openwhisk --force --grace-period=0
        sleep 30
    else
        echo "  No existing pod found (first run)"
    fi
    
    # Ensure action exists
    wsk -i action get "$ACTION_NAME" >/dev/null 2>&1 || {
        echo "  Creating action..."
        wsk -i action create "$ACTION_NAME" \
            ../javascript/network_benchmark.js \
            --kind nodejs:14 >/dev/null
    }

    sleep 2
    
    # Invoke and measure
    RESULT_FILE="$OUTPUT_DIR/javascript_cold_${TIMESTAMP}_iter${i}.json"
    echo "  Invoking action..."
    
    START_TIME=$(date +%s%N)
    wsk -i action invoke "$ACTION_NAME" --blocking --result > "$RESULT_FILE"
    END_TIME=$(date +%s%N)
    
    INVOCATION_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)
    
    # Add metadata
    TMP_FILE=$(mktemp)
    jq ". + {
        invocation_time_s: $INVOCATION_TIME, 
        iteration: $i, 
        cold_start: true,
        language: \"javascript\",
        timestamp: \"$TIMESTAMP\",
        hostname: \"$(hostname)\"
    }" "$RESULT_FILE" > "$TMP_FILE"
    mv "$TMP_FILE" "$RESULT_FILE"
    
    echo "  ✓ Invocation time: ${INVOCATION_TIME}s"
    echo "  ✓ Saved to: $RESULT_FILE"
    echo ""
    
    # Wait between iterations
    sleep 5
done

echo "========================================"
echo "JAVASCRIPT COLD START - Complete!"
echo "Results in: $OUTPUT_DIR"
echo "Total files: $(ls -1 $OUTPUT_DIR | wc -l)"
echo "========================================"