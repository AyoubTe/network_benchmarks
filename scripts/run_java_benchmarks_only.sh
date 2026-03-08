#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

MASTER_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="./benchmark_java_only_log_${MASTER_TIMESTAMP}.txt"

# Timing configuration (in seconds)
COLD_START_POD_DELETION_WAIT=240  # 4 minutes after pod deletion
COLD_START_ITERATION_WAIT=30      # 30 seconds between cold start iterations
HOT_START_ITERATION_WAIT=120      # 2 minutes between hot start iterations
TEST_TRANSITION_WAIT=300          # 5 minutes between different tests

echo "========================================"
echo "JAVA NETWORK BENCHMARK SUITE ONLY"
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
    
    for ((j=$seconds; j>0; j--)); do
        if [ $j -eq 60 ] || [ $j -eq 30 ] || [ $j -eq 10 ] || [ $j -le 5 ]; then
            printf "${YELLOW}  Waiting... %d seconds remaining${NC}\n" $j
        fi
        sleep 1
    done
    echo ""
}

# Clean old Java results only
log "Cleaning old Java results..."
rm -rf ./results_java_cold ./results_java_hot
log "✓ Old Java results cleaned"
echo ""

# Deploy Java action
log "Deploy Java OpenWhisk action..."

echo "Deploying Java benchmark..."
echo "  Building Java JAR with Maven..."
cd ./../java
mvn clean package -q
cd ./../scripts

wsk -i action delete network-bench-java 2>/dev/null || true
wsk -i action create network-bench-java \
    ./../java/target/network-benchmark-1.0.jar \
    --main NetworkBenchmark \
    --kind java:8

wait_with_countdown 30 "Allowing system to stabilize after updates..."

#############################################
# JAVA COLD START
#############################################
log "=========================================="
log "STARTING: Java Cold Start Benchmark"
log "=========================================="

OUTPUT_DIR="./results_java_cold"
ITERATIONS=5
ACTION_NAME="network-bench-java"
mkdir -p "$OUTPUT_DIR"

for iter_num in $(seq 1 $ITERATIONS); do
    log "Java Cold - Iteration $iter_num/$ITERATIONS"
    
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
    
    RESULT_FILE="$OUTPUT_DIR/java_cold_${MASTER_TIMESTAMP}_iter${iter_num}.json"
    log_info "DEBUG: Iteration variable = $iter_num, Target file = $RESULT_FILE"
    
    START_TIME=$(date +%s%N)
    wsk -i action invoke "$ACTION_NAME" --blocking --result > "$RESULT_FILE" 2>&1
    END_TIME=$(date +%s%N)
    
    INVOCATION_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)
    
    TMP_FILE="/tmp/java_cold_${iter_num}_${MASTER_TIMESTAMP}.json"
    jq --arg invtime "$INVOCATION_TIME" \
       --arg iteration "$iter_num" \
       --arg timestamp "$MASTER_TIMESTAMP" \
       --arg host "$(hostname)" \
       '. + {
        invocation_time_s: ($invtime | tonumber),
        iteration: ($iteration | tonumber),
        cold_start: true,
        language: "java",
        master_timestamp: $timestamp,
        hostname: $host
    }' "$RESULT_FILE" > "$TMP_FILE" 2>/dev/null
    
    if [ -f "$TMP_FILE" ]; then
        mv "$TMP_FILE" "$RESULT_FILE"
        log "✓ Invocation time: ${INVOCATION_TIME}s - Saved to: $RESULT_FILE"
    else
        log_error "Failed to add metadata to $RESULT_FILE"
    fi
    
    if [ $iter_num -lt $ITERATIONS ]; then
        wait_with_countdown $COLD_START_ITERATION_WAIT "Waiting before next iteration..."
    fi
done

log "✓ Java Cold Start Complete - $(ls -1 $OUTPUT_DIR/*.json 2>/dev/null | wc -l) files created"

echo "Wait 1 min before destroying the pod..."
sleep 60

POD_NAME=$(kubectl get pods -n openwhisk 2>/dev/null | grep "networkbenchjava" | awk '{print $1}' | head -1)
if [ -n "$POD_NAME" ]; then
    kubectl delete pod "$POD_NAME" -n openwhisk --force --grace-period=0 2>&1 | tee -a "$LOG_FILE"
fi

wait_with_countdown $TEST_TRANSITION_WAIT "Transition period before Java Hot Start test (5 mins)..."

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

for iter_num in $(seq 1 $ITERATIONS); do
    log "Java Hot - Iteration $iter_num/$ITERATIONS"
    
    RESULT_FILE="$OUTPUT_DIR/java_hot_${MASTER_TIMESTAMP}_iter${iter_num}.json"
    log_info "DEBUG: Iteration variable = $iter_num, Target file = $RESULT_FILE"
    
    START_TIME=$(date +%s%N)
    wsk -i action invoke "$ACTION_NAME" --blocking --result > "$RESULT_FILE" 2>&1
    END_TIME=$(date +%s%N)
    
    INVOCATION_TIME=$(echo "scale=3; ($END_TIME - $START_TIME) / 1000000000" | bc)
    
    TMP_FILE="/tmp/java_hot_${iter_num}_${MASTER_TIMESTAMP}.json"
    jq --arg invtime "$INVOCATION_TIME" \
       --arg iteration "$iter_num" \
       --arg timestamp "$MASTER_TIMESTAMP" \
       --arg host "$(hostname)" \
       --arg pod "$POD_NAME" \
       '. + {
        invocation_time_s: ($invtime | tonumber),
        iteration: ($iteration | tonumber),
        cold_start: false,
        language: "java",
        master_timestamp: $timestamp,
        hostname: $host,
        pod_name: $pod
    }' "$RESULT_FILE" > "$TMP_FILE" 2>/dev/null
    
    if [ -f "$TMP_FILE" ]; then
        mv "$TMP_FILE" "$RESULT_FILE"
        log "✓ Invocation time: ${INVOCATION_TIME}s - Saved to: $RESULT_FILE"
    else
        log_error "Failed to add metadata to $RESULT_FILE"
    fi
    
    if [ $iter_num -lt $ITERATIONS ]; then
        wait_with_countdown $HOT_START_ITERATION_WAIT "Waiting before next hot iteration (2 mins)..."
    fi
done

log "✓ Java Hot Start Complete - $(ls -1 $OUTPUT_DIR/*.json 2>/dev/null | wc -l) files created"

#############################################
# FINAL SUMMARY
#############################################
END_TIMESTAMP=$(date +%Y%m%d_%H%M%S)

log "=========================================="
log "JAVA BENCHMARKS COMPLETE!"
log "=========================================="
log "Master Timestamp: $MASTER_TIMESTAMP"
log "End Timestamp: $END_TIMESTAMP"
log ""
log "Results Summary:"
log "  - Java Cold:        $(ls -1 ./results_java_cold/*.json 2>/dev/null | wc -l) files"
log "  - Java Hot:         $(ls -1 ./results_java_hot/*.json 2>/dev/null | wc -l) files"
log ""
log "Full log saved to: $LOG_FILE"
log "=========================================="

echo ""
echo -e "${GREEN}✓ Java benchmarks completed successfully!${NC}"
echo ""
