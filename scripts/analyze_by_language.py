#!/usr/bin/env python3
"""
Analyze network benchmark results by language and start type
For energy consumption analysis
"""
import json
import glob
import statistics
import sys
from pathlib import Path

def load_results(directory):
    """Load all JSON results from a directory"""
    results = []
    json_files = glob.glob(f"{directory}/*.json")
    
    for f in json_files:
        try:
            with open(f, 'r') as fp:
                data = json.load(fp)
                results.append(data)
        except Exception as e:
            print(f"Warning: Could not load {f}: {e}")
    
    return results

def calculate_stats(values):
    """Calculate statistics for a list of values"""
    if not values:
        return None
    
    return {
        'count': len(values),
        'min': min(values),
        'max': max(values),
        'mean': statistics.mean(values),
        'median': statistics.median(values),
        'stdev': statistics.stdev(values) if len(values) > 1 else 0
    }

def analyze_invocation_times(results):
    """Analyze invocation times from results"""
    times = []
    for r in results:
        if 'invocation_time_s' in r:
            times.append(r['invocation_time_s'])
    return calculate_stats(times)

def analyze_network_metrics(results):
    """Analyze network benchmark metrics"""
    metrics = {}
    
    # TCP Latency
    tcp_latencies = []
    for r in results:
        if 'benchmarks' in r and 'tcp_latency' in r['benchmarks']:
            avg = r['benchmarks']['tcp_latency'].get('avg_ms')
            if avg:
                tcp_latencies.append(avg)
    if tcp_latencies:
        metrics['tcp_latency_ms'] = calculate_stats(tcp_latencies)
    
    # HTTP Latency
    http_latencies = []
    for r in results:
        if 'benchmarks' in r and 'http_latency' in r['benchmarks']:
            avg = r['benchmarks']['http_latency'].get('avg_ms')
            if avg:
                http_latencies.append(avg)
    if http_latencies:
        metrics['http_latency_ms'] = calculate_stats(http_latencies)
    
    # Bandwidth
    bandwidths = []
    for r in results:
        if 'benchmarks' in r and 'bandwidth' in r['benchmarks']:
            bw = r['benchmarks']['bandwidth'].get('bandwidth_mbps')
            if bw:
                bandwidths.append(bw)
    if bandwidths:
        metrics['bandwidth_mbps'] = calculate_stats(bandwidths)
    
    return metrics

def print_report(language, start_type, directory, results):
    """Print analysis report"""
    print(f"\n{'='*70}")
    print(f"  {language.upper()} - {start_type.upper()} START")
    print(f"{'='*70}")
    print(f"Directory: {directory}")
    print(f"Total samples: {len(results)}")
    print()
    
    # Invocation times
    invocation_stats = analyze_invocation_times(results)
    if invocation_stats:
        print("INVOCATION TIME (total function execution):")
        print(f"  Mean:   {invocation_stats['mean']:.3f}s ± {invocation_stats['stdev']:.3f}s")
        print(f"  Median: {invocation_stats['median']:.3f}s")
        print(f"  Min:    {invocation_stats['min']:.3f}s")
        print(f"  Max:    {invocation_stats['max']:.3f}s")
        print()
    
    # Network metrics
    network_metrics = analyze_network_metrics(results)
    if network_metrics:
        print("NETWORK METRICS:")
        
        if 'tcp_latency_ms' in network_metrics:
            stats = network_metrics['tcp_latency_ms']
            print(f"  TCP Latency:  {stats['mean']:.2f}ms ± {stats['stdev']:.2f}ms")
        
        if 'http_latency_ms' in network_metrics:
            stats = network_metrics['http_latency_ms']
            print(f"  HTTP Latency: {stats['mean']:.2f}ms ± {stats['stdev']:.2f}ms")
        
        if 'bandwidth_mbps' in network_metrics:
            stats = network_metrics['bandwidth_mbps']
            print(f"  Bandwidth:    {stats['mean']:.2f}Mbps ± {stats['stdev']:.2f}Mbps")
    
    print(f"{'='*70}\n")

def main():
    """Main analysis function"""
    
    # Define benchmark directories
    benchmarks = [
        ('python', 'cold', 'results_python_cold'),
        ('python', 'hot', 'results_python_hot'),
        ('javascript', 'cold', 'results_javascript_cold'),
        ('javascript', 'hot', 'results_javascript_hot'),
        ('java', 'cold', 'results_java_cold'),
        ('java', 'hot', 'results_java_hot'),
    ]
    
    print("\n" + "="*70)
    print("  NETWORK BENCHMARK ANALYSIS - BY LANGUAGE AND START TYPE")
    print("="*70)
    
    all_results = {}
    
    for language, start_type, directory in benchmarks:
        if Path(directory).exists():
            results = load_results(directory)
            if results:
                all_results[f"{language}_{start_type}"] = results
                print_report(language, start_type, directory, results)
            else:
                print(f"\nWarning: No results found in {directory}")
        else:
            print(f"\nWarning: Directory not found: {directory}")
    
    # Summary comparison
    if all_results:
        print("\n" + "="*70)
        print("  SUMMARY COMPARISON")
        print("="*70)
        print(f"\n{'Scenario':<25} {'Samples':<10} {'Mean Time (s)':<20} {'Std Dev (s)'}")
        print("-"*70)
        
        for key, results in sorted(all_results.items()):
            stats = analyze_invocation_times(results)
            if stats:
                print(f"{key:<25} {stats['count']:<10} {stats['mean']:<20.3f} {stats['stdev']:.3f}")
        
        print("="*70 + "\n")

if __name__ == "__main__":
    main()