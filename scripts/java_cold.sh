#!/bin/bash
set -e

OUTPUT_DIR="./results_java_cold"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ITERATIONS=5
ACTION_NAME="network-bench-java"

mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "JAVA - COLD START Benchmark"
echo "========================================"
echo "Configuration: $(hostname)"
echo "Timestamp: $TIMESTAMP"
echo "Iterations: $ITERATIONS"
echo "Action: $ACTION_NAME"
echo "========================================"
echo ""

# Ensure JAR is built
if [ ! -f "../java/target/network-benchmark-1.0.jar" ]; then
    echo "Building Java JAR..."
    cd ../java
    mvn clean package -q
    cd ../scripts
    echo ""
fi

for i in $(seq 1 $ITERATIONS); do
    echo "Iteration $i/$ITERATIONS (COLD START)"
    echo "----------------------------------------"
    
    # Delete action to ensure cold start
    echo "  Deleting action to force cold start..."
    wsk -i action delete "$ACTION_NAME" 2>/dev/null || true
    sleep 3
    
    # Recreate action
    echo "  Creating fresh action..."
    wsk -i action create "$ACTION_NAME" \
        ../java/target/network-benchmark-1.0.jar \
        --main NetworkBenchmark \
        --kind java:8 >/dev/null
    sleep 2
    
    # Invoke and measure
    RESULT_FILE="$OUTPUT_DIR/java_cold_${TIMESTAMP}_iter${i}.json"
    echo "  Invoking action..."
    
    START_TIME=$(date +%s%N)
    wsk -i action invoke "$ACTION_NAME" --result > "$RESULT_FILE"
    END_TIME=$(date +%s%N)
    
    INVOCATION_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)
    
    # Add metadata
    TMP_FILE=$(mktemp)
    jq ". + {
        invocation_time_s: $INVOCATION_TIME, 
        iteration: $i, 
        cold_start: true,
        language: \"java\",
        timestamp: \"$TIMESTAMP\",
        hostname: \"$(hostname)\"
    }" "$RESULT_FILE" > "$TMP_FILE"
    mv "$TMP_FILE" "$RESULT_FILE"
    
    echo "  ✓ Invocation time: ${INVOCATION_TIME}s"
    echo "  ✓ Saved to: $RESULT_FILE"
    echo ""
    
    # Wait between iterations (Java needs more time)
    sleep 5
done

echo "========================================"
echo "JAVA COLD START - Complete!"
echo "Results in: $OUTPUT_DIR"
echo "Total files: $(ls -1 $OUTPUT_DIR | wc -l)"
echo "========================================"