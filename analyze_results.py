#!/usr/bin/env python3
"""
Analyze network benchmark results
Compares VM+Container vs MicroVM configurations
"""
import json
import glob
import statistics
import sys

def load_results(pattern):
    """Load all result files matching pattern"""
    files = glob.glob(pattern)
    results = []
    for f in files:
        with open(f, 'r') as fp:
            results.append(json.load(fp))
    return results

def analyze_metric(results, benchmark_name, metric_key):
    """Extract and analyze a specific metric across all runs"""
    values = []
    for r in results:
        if benchmark_name in r.get('benchmarks', {}):
            val = r['benchmarks'][benchmark_name].get(metric_key)
            if val is not None and val > 0:
                values.append(val)
    
    if not values:
        return None
    
    return {
        'min': min(values),
        'max': max(values),
        'mean': statistics.mean(values),
        'median': statistics.median(values),
        'stdev': statistics.stdev(values) if len(values) > 1 else 0,
        'count': len(values)
    }

def compare_configurations(vm_results, microvm_results):
    """Compare VM+Container vs MicroVM results"""
    
    comparisons = {}
    
    benchmarks = [
        ('tcp_latency', 'avg_ms', 'TCP Latency (ms)'),
        ('http_latency', 'avg_ms', 'HTTP Latency (ms)'),
        ('dns_resolution', 'avg_ms', 'DNS Resolution (ms)'),
        ('bandwidth', 'bandwidth_mbps', 'Bandwidth (Mbps)')
    ]
    
    for bench_name, metric_key, display_name in benchmarks:
        vm_stats = analyze_metric(vm_results, bench_name, metric_key)
        microvm_stats = analyze_metric(microvm_results, bench_name, metric_key)
        
        if vm_stats and microvm_stats:
            diff_pct = ((microvm_stats['mean'] - vm_stats['mean']) / vm_stats['mean']) * 100
            
            comparisons[display_name] = {
                'vm_container': vm_stats,
                'microvm': microvm_stats,
                'difference_percent': diff_pct,
                'winner': 'MicroVM' if (bench_name == 'bandwidth' and diff_pct > 0) or (bench_name != 'bandwidth' and diff_pct < 0) else 'VM+Container'
            }
    
    return comparisons

def print_report(comparisons):
    """Print comparison report"""
    print("\n" + "="*80)
    print("NETWORK BENCHMARK COMPARISON: VM+Container vs MicroVM")
    print("="*80 + "\n")
    
    for metric_name, data in comparisons.items():
        print(f"\n{metric_name}")
        print("-" * 60)
        print(f"  VM+Container:  {data['vm_container']['mean']:.2f} ± {data['vm_container']['stdev']:.2f}")
        print(f"  MicroVM:       {data['microvm']['mean']:.2f} ± {data['microvm']['stdev']:.2f}")
        print(f"  Difference:    {data['difference_percent']:+.1f}%")
        print(f"  Winner:        {data['winner']}")
    
    print("\n" + "="*80 + "\n")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 analyze_results.py <vm_results_pattern> <microvm_results_pattern>")
        print("Example: python3 analyze_results.py 'results_vm_*.json' 'results_microvm_*.json'")
        sys.exit(1)
    
    vm_pattern = sys.argv[1]
    microvm_pattern = sys.argv[2]
    
    print(f"Loading VM+Container results from: {vm_pattern}")
    vm_results = load_results(vm_pattern)
    print(f"  Loaded {len(vm_results)} result files")
    
    print(f"Loading MicroVM results from: {microvm_pattern}")
    microvm_results = load_results(microvm_pattern)
    print(f"  Loaded {len(microvm_results)} result files")
    
    if not vm_results or not microvm_results:
        print("ERROR: No results found!")
        sys.exit(1)
    
    comparisons = compare_configurations(vm_results, microvm_results)
    print_report(comparisons)