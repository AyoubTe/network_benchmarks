#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

MASTER_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="./benchmark_master_log_${MASTER_TIMESTAMP}.txt"

# Timing configuration (in seconds)
COLD_START_POD_DELETION_WAIT=240  # 4 minutes after pod deletion
COLD_START_ITERATION_WAIT=30      # 30 seconds between cold start iterations
HOT_START_ITERATION_WAIT=120      # 2 minutes between hot start iterations
TEST_TRANSITION_WAIT=300          # 5 minutes between different tests

echo "========================================"
echo "COMPREHENSIVE NETWORK BENCHMARK SUITE"
echo "========================================"
echo "Master Timestamp: $MASTER_TIMESTAMP"
echo "Log file: $LOG_FILE"
echo ""
echo "Timing Configuration:"
echo "  - Cold start pod deletion wait: ${COLD_START_POD_DELETION_WAIT}s (4 mins)"
echo "  - Cold start iteration wait: ${COLD_START_ITERATION_WAIT}s"
echo "  - Hot start iteration wait: ${HOT_START_ITERATION_WAIT}s (2 mins)"
echo "  - Test transition wait: ${TEST_TRANSITION_WAIT}s (5 mins)"
echo "========================================"
echo "" | tee -a "$LOG_FILE"

# Function to log with timestamp
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

# Function to wait with countdown
wait_with_countdown() {
    local seconds=$1
    local message=$2

    log_info "$message"

    for ((i=$seconds; i>0; i--)); do
        if [ $i -eq 60 ] || [ $i -eq 30 ] || [ $i -eq 10 ] || [ $i -le 5 ]; then
            printf "${YELLOW}  Waiting... %d seconds remaining${NC}\n" $i
        fi
        sleep 1
    done
    echo ""
}

# Clean old results
log "Cleaning old results..."
rm -rf ./results_python_cold ./results_python_hot
rm -rf ./results_javascript_cold ./results_javascript_hot
rm -rf ./results_java_cold ./results_java_hot
log "✓ Old results cleaned"
echo ""

# Ensure all actions use the updated code
log "Updating all OpenWhisk actions with latest code..."

# Update Python
log_info "Updating Python action..."
wsk -i action update network-bench-python ../python/network_benchmark_fixed.py --kind python:3 2>&1 | tee -a "$LOG_FILE"

# Update JavaScript
log_info "Updating JavaScript action..."
wsk -i action update network-bench-js ../javascript/network_benchmark_fixed.js --kind nodejs:14 2>&1 | tee -a "$LOG_FILE"

# Update Java (rebuild first)
log_info "Rebuilding and updating Java action..."
cd ../java
mvn clean package -q 2>&1 | tee -a "$LOG_FILE"
cd ../scripts
wsk -i action update network-bench-java ../java/target/network-benchmark-1.0.jar --main NetworkBenchmark --kind java:8 2>&1 | tee -a "$LOG_FILE"

log "✓ All actions updated"
echo ""

wait_with_countdown 30 "Allowing system to stabilize after updates..."

#############################################
# PYTHON COLD START
#############################################
log "=========================================="
log "STARTING: Python Cold Start Benchmark"
log "=========================================="

OUTPUT_DIR="./results_python_cold"
ITERATIONS=5
ACTION_NAME="network-bench-python"
mkdir -p "$OUTPUT_DIR"

for i in $(seq 1 $ITERATIONS); do
    log "Python Cold - Iteration $i/$ITERATIONS"

    # Delete pod
    POD_NAME=$(kubectl get pods -n openwhisk 2>/dev/null | grep "networkbenchpython" | awk '{print $1}' | head -1)
    if [ -n "$POD_NAME" ]; then
        log_info "Deleting pod: $POD_NAME"
        kubectl delete pod "$POD_NAME" -n openwhisk --force --grace-period=0 2>&1 | tee -a "$LOG_FILE"
        wait_with_countdown $COLD_START_POD_DELETION_WAIT "Waiting for pod deletion to complete and system to stabilize (4 mins)..."
    else
        log_warning "No existing pod found"
    fi

    # Ensure action exists
    wsk -i action get "$ACTION_NAME" >/dev/null 2>&1 || {
        log_info "Creating action..."
        wsk -i action create "$ACTION_NAME" ../python/network_benchmark_fixed.py --kind python:3 2>&1 | tee -a "$LOG_FILE"
    }

    # Invoke
    RESULT_FILE="$OUTPUT_DIR/python_cold_${MASTER_TIMESTAMP}_iter${i}.json"
    START_TIME=$(date +%s%N)
    wsk -i action invoke "$ACTION_NAME" --blocking --result > "$RESULT_FILE" 2>&1
    END_TIME=$(date +%s%N)

    INVOCATION_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)

    # Add metadata
    TMP_FILE=$(mktemp)
    jq ". + {
        invocation_time_s: $INVOCATION_TIME,
        iteration: $i,
        cold_start: true,
        language: \"python\",
        master_timestamp: \"$MASTER_TIMESTAMP\",
        hostname: \"$(hostname)\"
    }" "$RESULT_FILE" > "$TMP_FILE" 2>/dev/null
    mv "$TMP_FILE" "$RESULT_FILE"

    log "✓ Invocation time: ${INVOCATION_TIME}s - Saved to: $RESULT_FILE"

    if [ $i -lt $ITERATIONS ]; then
        wait_with_countdown $COLD_START_ITERATION_WAIT "Waiting before next iteration..."
    fi
done

log "✓ Python Cold Start Complete"

# Clean up pod
POD_NAME=$(kubectl get pods -n openwhisk 2>/dev/null | grep "networkbenchpython" | awk '{print $1}' | head -1)
if [ -n "$POD_NAME" ]; then
    kubectl delete pod "$POD_NAME" -n openwhisk --force --grace-period=0 2>&1 | tee -a "$LOG_FILE"
fi

wait_with_countdown $TEST_TRANSITION_WAIT "Transition period before next test (5 mins)..."

#############################################
# PYTHON HOT START
#############################################
log "=========================================="
log "STARTING: Python Hot Start Benchmark"
log "=========================================="

OUTPUT_DIR="./results_python_hot"
mkdir -p "$OUTPUT_DIR"

# Setup action
wsk -i action delete "$ACTION_NAME" 2>/dev/null || true
wsk -i action create "$ACTION_NAME" ../python/network_benchmark_fixed.py --kind python:3 2>&1 | tee -a "$LOG_FILE"

# Warmup
log_info "Warming up action..."
wsk -i action invoke "$ACTION_NAME" --result >/dev/null 2>&1
sleep 120
log_info "Waiting 2 mins after warming up..."

POD_NAME=$(kubectl get pods -n openwhisk 2>/dev/null | grep "networkbenchpython" | awk '{print $1}' | head -1)
log_info "Using pod: $POD_NAME"

for i in $(seq 1 $ITERATIONS); do
    log "Python Hot - Iteration $i/$ITERATIONS"

    RESULT_FILE="$OUTPUT_DIR/python_hot_${MASTER_TIMESTAMP}_iter${i}.json"
    START_TIME=$(date +%s%N)
    wsk -i action invoke "$ACTION_NAME" --blocking --result > "$RESULT_FILE" 2>&1
    END_TIME=$(date +%s%N)

    INVOCATION_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)

    TMP_FILE=$(mktemp)
    jq ". + {
        invocation_time_s: $INVOCATION_TIME,
        iteration: $i,
        cold_start: false,
        language: \"python\",
        master_timestamp: \"$MASTER_TIMESTAMP\",
        hostname: \"$(hostname)\",
        pod_name: \"$POD_NAME\"
    }" "$RESULT_FILE" > "$TMP_FILE" 2>/dev/null
    mv "$TMP_FILE" "$RESULT_FILE"

    log "✓ Invocation time: ${INVOCATION_TIME}s - Saved to: $RESULT_FILE"

    if [ $i -lt $ITERATIONS ]; then
        wait_with_countdown $HOT_START_ITERATION_WAIT "Waiting before next hot iteration (2 mins)..."
    fi
done

log "✓ Python Hot Start Complete"

# Clean up
POD_NAME=$(kubectl get pods -n openwhisk 2>/dev/null | grep "networkbenchpython" | awk '{print $1}' | head -1)
if [ -n "$POD_NAME" ]; then
    kubectl delete pod "$POD_NAME" -n openwhisk --force --grace-period=0 2>&1 | tee -a "$LOG_FILE"
fi

wait_with_countdown $TEST_TRANSITION_WAIT "Transition period before next test (5 mins)..."

#############################################
# JAVASCRIPT COLD START
#############################################
log "=========================================="
log "STARTING: JavaScript Cold Start Benchmark"
log "=========================================="

OUTPUT_DIR="./results_javascript_cold"
ACTION_NAME="network-bench-js"
mkdir -p "$OUTPUT_DIR"

for i in $(seq 1 $ITERATIONS); do
    log "JavaScript Cold - Iteration $i/$ITERATIONS"

    POD_NAME=$(kubectl get pods -n openwhisk 2>/dev/null | grep "networkbenchjs" | awk '{print $1}' | head -1)
    if [ -n "$POD_NAME" ]; then
        log_info "Deleting pod: $POD_NAME"
        kubectl delete pod "$POD_NAME" -n openwhisk --force --grace-period=0 2>&1 | tee -a "$LOG_FILE"
        wait_with_countdown $COLD_START_POD_DELETION_WAIT "Waiting for pod deletion to complete (4 mins)..."
    else
        log_warning "No existing pod found"
    fi

    wsk -i action get "$ACTION_NAME" >/dev/null 2>&1 || {
        log_info "Creating action..."
        wsk -i action create "$ACTION_NAME" ../javascript/network_benchmark_fixed.js --kind nodejs:14 2>&1 | tee -a "$LOG_FILE"
    }

    RESULT_FILE="$OUTPUT_DIR/javascript_cold_${MASTER_TIMESTAMP}_iter${i}.json"
    START_TIME=$(date +%s%N)
    wsk -i action invoke "$ACTION_NAME" --blocking --result > "$RESULT_FILE" 2>&1
    END_TIME=$(date +%s%N)

    INVOCATION_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)

    TMP_FILE=$(mktemp)
    jq ". + {
        invocation_time_s: $INVOCATION_TIME,
        iteration: $i,
        cold_start: true,
        language: \"javascript\",
        master_timestamp: \"$MASTER_TIMESTAMP\",
        hostname: \"$(hostname)\"
    }" "$RESULT_FILE" > "$TMP_FILE" 2>/dev/null
    mv "$TMP_FILE" "$RESULT_FILE"

    log "✓ Invocation time: ${INVOCATION_TIME}s - Saved to: $RESULT_FILE"

    if [ $i -lt $ITERATIONS ]; then
        wait_with_countdown $COLD_START_ITERATION_WAIT "Waiting before next iteration..."
    fi
done

log "✓ JavaScript Cold Start Complete"

POD_NAME=$(kubectl get pods -n openwhisk 2>/dev/null | grep "networkbenchjs" | awk '{print $1}' | head -1)
if [ -n "$POD_NAME" ]; then
    kubectl delete pod "$POD_NAME" -n openwhisk --force --grace-period=0 2>&1 | tee -a "$LOG_FILE"
fi

wait_with_countdown $TEST_TRANSITION_WAIT "Transition period before next test (5 mins)..."

#############################################
# JAVASCRIPT HOT START
#############################################
log "=========================================="
log "STARTING: JavaScript Hot Start Benchmark"
log "=========================================="

OUTPUT_DIR="./results_javascript_hot"
mkdir -p "$OUTPUT_DIR"

wsk -i action delete "$ACTION_NAME" 2>/dev/null || true
wsk -i action create "$ACTION_NAME" ../javascript/network_benchmark_fixed.js --kind nodejs:14 2>&1 | tee -a "$LOG_FILE"

log_info "Warming up action..."
wsk -i action invoke "$ACTION_NAME" --result >/dev/null 2>&1
sleep 120
log_info "Waiting 2 mins after warming up..."

POD_NAME=$(kubectl get pods -n openwhisk 2>/dev/null | grep "networkbenchjs" | awk '{print $1}' | head -1)
log_info "Using pod: $POD_NAME"

for i in $(seq 1 $ITERATIONS); do
    log "JavaScript Hot - Iteration $i/$ITERATIONS"

    RESULT_FILE="$OUTPUT_DIR/javascript_hot_${MASTER_TIMESTAMP}_iter${i}.json"
    START_TIME=$(date +%s%N)
    wsk -i action invoke "$ACTION_NAME" --blocking --result > "$RESULT_FILE" 2>&1
    END_TIME=$(date +%s%N)

    INVOCATION_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)

    TMP_FILE=$(mktemp)
    jq ". + {
        invocation_time_s: $INVOCATION_TIME,
        iteration: $i,
        cold_start: false,
        language: \"javascript\",
        master_timestamp: \"$MASTER_TIMESTAMP\",
        hostname: \"$(hostname)\",
        pod_name: \"$POD_NAME\"
    }" "$RESULT_FILE" > "$TMP_FILE" 2>/dev/null
    mv "$TMP_FILE" "$RESULT_FILE"

    log "✓ Invocation time: ${INVOCATION_TIME}s - Saved to: $RESULT_FILE"

    if [ $i -lt $ITERATIONS ]; then
        wait_with_countdown $HOT_START_ITERATION_WAIT "Waiting before next hot iteration (2 mins)..."
    fi
done

log "✓ JavaScript Hot Start Complete"

POD_NAME=$(kubectl get pods -n openwhisk 2>/dev/null | grep "networkbenchjs" | awk '{print $1}' | head -1)
if [ -n "$POD_NAME" ]; then
    kubectl delete pod "$POD_NAME" -n openwhisk --force --grace-period=0 2>&1 | tee -a "$LOG_FILE"
fi

wait_with_countdown $TEST_TRANSITION_WAIT "Transition period before next test (5 mins)..."

#############################################
# JAVA COLD START
#############################################
log "=========================================="
log "STARTING: Java Cold Start Benchmark"
log "=========================================="

OUTPUT_DIR="./results_java_cold"
ACTION_NAME="network-bench-java"
mkdir -p "$OUTPUT_DIR"

for i in $(seq 1 $ITERATIONS); do
    log "Java Cold - Iteration $i/$ITERATIONS"

    POD_NAME=$(kubectl get pods -n openwhisk 2>/dev/null | grep "networkbenchjava" | awk '{print $1}' | head -1)
    if [ -n "$POD_NAME" ]; then
        log_info "Deleting pod: $POD_NAME"
        kubectl delete pod "$POD_NAME" -n openwhisk --force --grace-period=0 2>&1 | tee -a "$LOG_FILE"
        wait_with_countdown $COLD_START_POD_DELETION_WAIT "Waiting for pod deletion to complete (4 mins)..."
    else
        log_warning "No existing pod found"
    fi

    wsk -i action get "$ACTION_NAME" >/dev/null 2>&1 || {
        log_info "Creating action..."
        wsk -i action create "$ACTION_NAME" ../java/target/network-benchmark-1.0.jar --main NetworkBenchmark --kind java:8 2>&1 | tee -a "$LOG_FILE"
    }

    RESULT_FILE="$OUTPUT_DIR/java_cold_${MASTER_TIMESTAMP}_iter${i}.json"
    START_TIME=$(date +%s%N)
    wsk -i action invoke "$ACTION_NAME" --blocking --result > "$RESULT_FILE" 2>&1
    END_TIME=$(date +%s%N)

    INVOCATION_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)

    TMP_FILE=$(mktemp)
    jq ". + {
        invocation_time_s: $INVOCATION_TIME,
        iteration: $i,
        cold_start: true,
        language: \"java\",
        master_timestamp: \"$MASTER_TIMESTAMP\",
        hostname: \"$(hostname)\"
    }" "$RESULT_FILE" > "$TMP_FILE" 2>/dev/null
    mv "$TMP_FILE" "$RESULT_FILE"

    log "✓ Invocation time: ${INVOCATION_TIME}s - Saved to: $RESULT_FILE"

    if [ $i -lt $ITERATIONS ]; then
        wait_with_countdown $COLD_START_ITERATION_WAIT "Waiting before next iteration..."
    fi
done

log "✓ Java Cold Start Complete"

POD_NAME=$(kubectl get pods -n openwhisk 2>/dev/null | grep "networkbenchjava" | awk '{print $1}' | head -1)
if [ -n "$POD_NAME" ]; then
    kubectl delete pod "$POD_NAME" -n openwhisk --force --grace-period=0 2>&1 | tee -a "$LOG_FILE"
fi

wait_with_countdown $TEST_TRANSITION_WAIT "Transition period before final test (5 mins)..."

#############################################
# JAVA HOT START
#############################################
log "=========================================="
log "STARTING: Java Hot Start Benchmark"
log "=========================================="

OUTPUT_DIR="./results_java_hot"
mkdir -p "$OUTPUT_DIR"

wsk -i action delete "$ACTION_NAME" 2>/dev/null || true
wsk -i action create "$ACTION_NAME" ../java/target/network-benchmark-1.0.jar --main NetworkBenchmark --kind java:8 2>&1 | tee -a "$LOG_FILE"

log_info "Warming up action (JVM warmup)..."
wsk -i action invoke "$ACTION_NAME" --result >/dev/null 2>&1
sleep 120
log_info "Waiting 2 mins after warming up..."

POD_NAME=$(kubectl get pods -n openwhisk 2>/dev/null | grep "networkbenchjava" | awk '{print $1}' | head -1)
log_info "Using pod: $POD_NAME"

for i in $(seq 1 $ITERATIONS); do
    log "Java Hot - Iteration $i/$ITERATIONS"

    RESULT_FILE="$OUTPUT_DIR/java_hot_${MASTER_TIMESTAMP}_iter${i}.json"
    START_TIME=$(date +%s%N)
    wsk -i action invoke "$ACTION_NAME" --blocking --result > "$RESULT_FILE" 2>&1
    END_TIME=$(date +%s%N)

    INVOCATION_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)

    TMP_FILE=$(mktemp)
    jq ". + {
        invocation_time_s: $INVOCATION_TIME,
        iteration: $i,
        cold_start: false,
        language: \"java\",
        master_timestamp: \"$MASTER_TIMESTAMP\",
        hostname: \"$(hostname)\",
        pod_name: \"$POD_NAME\"
    }" "$RESULT_FILE" > "$TMP_FILE" 2>/dev/null
    mv "$TMP_FILE" "$RESULT_FILE"

    log "✓ Invocation time: ${INVOCATION_TIME}s - Saved to: $RESULT_FILE"

    if [ $i -lt $ITERATIONS ]; then
        wait_with_countdown $HOT_START_ITERATION_WAIT "Waiting before next hot iteration (2 mins)..."
    fi
done

log "✓ Java Hot Start Complete"

#############################################
# FINAL SUMMARY
#############################################
END_TIMESTAMP=$(date +%Y%m%d_%H%M%S)

log "=========================================="
log "ALL BENCHMARKS COMPLETE!"
log "=========================================="
log "Master Timestamp: $MASTER_TIMESTAMP"
log "End Timestamp: $END_TIMESTAMP"
log ""
log "Results Summary:"
log "  - Python Cold:      $(ls -1 ./results_python_cold/*.json 2>/dev/null | wc -l) files"
log "  - Python Hot:       $(ls -1 ./results_python_hot/*.json 2>/dev/null | wc -l) files"
log "  - JavaScript Cold:  $(ls -1 ./results_javascript_cold/*.json 2>/dev/null | wc -l) files"
log "  - JavaScript Hot:   $(ls -1 ./results_javascript_hot/*.json 2>/dev/null | wc -l) files"
log "  - Java Cold:        $(ls -1 ./results_java_cold/*.json 2>/dev/null | wc -l) files"
log "  - Java Hot:         $(ls -1 ./results_java_hot/*.json 2>/dev/null | wc -l) files"
log ""
log "Full log saved to: $LOG_FILE"
log "=========================================="

echo ""
echo -e "${GREEN}✓ All benchmarks completed successfully!${NC}"
echo ""