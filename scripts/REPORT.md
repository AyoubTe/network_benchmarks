# Network Benchmark Results - Cluster 2 (MicroVM/Kata)
**Date:** March 5, 2026
**Configuration:** Kata Containers with QEMU 6.2.0 + virtio-9p

---

## KEY FINDINGS

### 1. PERFORMANCE RESULTS

| Language   | Start Type | Invocation Time | TCP Latency | HTTP Latency | DNS Latency |
|------------|------------|-----------------|-------------|--------------|-------------|
| Python     | Cold       | 23.9s ± 8.8s    | 7.74 ms     | 439 ms       | 9.89 ms     |
| Python     | Hot        | 4.49s ± 0.99s   | 7.10 ms     | 408 ms       | 6.02 ms     |
| JavaScript | Cold       | 23.8s ± 7.8s    | 8.46 ms     | 427 ms       | 6.99 ms     |
| JavaScript | Hot        | 4.67s ± 1.01s   | 7.57 ms     | 401 ms       | 3.47 ms     |
| Java       | Cold       | 16.5s ± 19.3s   | 8.38 ms     | 318 ms       | 27.50 ms    |
| Java       | Hot        | 4.81s ± 1.26s   | 7.34 ms     | 447 ms       | 1.00 ms     |

### 2. COLD START OVERHEAD

| Language   | Cold Start | Hot Start | Overhead      | % Increase |
|------------|------------|-----------|---------------|------------|
| Python     | 23.93s     | 4.49s     | +19.44s       | **433%**   |
| JavaScript | 23.79s     | 4.67s     | +19.11s       | **409%**   |
| Java       | 16.45s     | 4.81s     | +11.64s       | **242%**   |

---

## OBSERVATIONS

### Cold Start Performance:
- **Python & JavaScript**: Nearly identical cold start times (~24s)
- **Java**: Faster cold start (16.5s) but with high variance (±19.3s)
- **All languages**: Cold starts are 2.4x - 4.3x slower than hot starts

### Hot Start Performance:
- **All languages**: Similar hot start times (4.5-4.8s)
- **Low variance**: All under 1.3s standard deviation
- **Network metrics**: Consistent across all languages
  - TCP: 7-8.5ms
  - HTTP: 400-450ms
  - DNS: 1-10ms (Java fastest, Python slowest)

### Energy Consumption (from Grafana):
Based on the power consumption graphs:
- **Cold starts**: Show clear spikes to ~2900J during VM creation
- **Hot starts**: More stable at ~2810-2820J baseline
- **Pattern**: Each cold start creates a 70-80J spike above baseline

---

## KEY INSIGHTS FOR MEETING

1. **Cold Start Penalty is Significant**
   - Python/JS: 4-5x slower than hot starts
   - Java: 2.4x slower (JVM overhead less impactful than VM creation)

2. **MicroVM Overhead**
   - Cold starts take 15-24 seconds (VM creation + runtime initialization)
   - Hot starts are fast (~5s) showing runtime efficiency

3. **Network Performance**
   - Consistent across all runtimes (7-8ms TCP, 400ms HTTP)
   - No significant runtime-specific network overhead

4. **Energy Impact**
   - Cold starts consume ~70-80J more energy per invocation
   - For 5 iterations: Cold uses ~350-400J more than hot

---

## RECOMMENDATIONS

1. **For Production**:
   - Use pod keep-alive/warmup strategies
   - Pre-warm functions before expected traffic
   - Consider language choice: Java has best cold/hot ratio

2. **For Energy Efficiency**:
   - Minimize cold starts through intelligent scheduling
   - Keep pods alive during active periods
   - Hot starts save ~70J per invocation

3. **Next Steps**:
   - Compare with Cluster 1 (VM+Container)
   - Measure idle vs active power consumption
   - Test with real workload patterns