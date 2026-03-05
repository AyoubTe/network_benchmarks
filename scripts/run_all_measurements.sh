#!/bin/bash
set -e

echo "========================================"
echo "COMPLETE ENERGY MEASUREMENT SUITE"
echo "========================================"
echo "This will run ALL language benchmarks"
echo "in BOTH cold and hot start modes."
echo ""
echo "Total: 6 benchmark scenarios"
echo "  - Python Cold Start (5 iterations)"
echo "  - Python Hot Start (5 iterations)"
echo "  - JavaScript Cold Start (5 iterations)"
echo "  - JavaScript Hot Start (5 iterations)"
echo "  - Java Cold Start (5 iterations)"
echo "  - Java Hot Start (5 iterations)"
echo ""
echo "Estimated time: ~15-20 minutes"
echo "========================================"
echo ""

read -p "Press Enter to start, or Ctrl+C to cancel..."

# Python
echo ""
echo "========== PYTHON COLD START =========="
./python_cold.sh

echo ""
echo "Waiting 30 seconds before next benchmark..."
sleep 30

echo ""
echo "========== PYTHON HOT START =========="
./python_hot.sh

echo ""
echo "Waiting 30 seconds before next benchmark..."
sleep 30

# JavaScript
echo ""
echo "========== JAVASCRIPT COLD START =========="
./javascript_cold.sh

echo ""
echo "Waiting 30 seconds before next benchmark..."
sleep 30

echo ""
echo "========== JAVASCRIPT HOT START =========="
./javascript_hot.sh

echo ""
echo "Waiting 30 seconds before next benchmark..."
sleep 30

# Java
echo ""
echo "========== JAVA COLD START =========="
./java_cold.sh

echo ""
echo "Waiting 30 seconds before next benchmark..."
sleep 30

echo ""
echo "========== JAVA HOT START =========="
./java_hot.sh

echo ""
echo "========================================"
echo "ALL BENCHMARKS COMPLETE!"
echo "========================================"
echo ""
echo "Results directories:"
ls -d results_*/
echo ""
echo "Total result files: $(find results_* -name '*.json' 2>/dev/null | wc -l)"
echo ""