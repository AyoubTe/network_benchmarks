#!/usr/bin/env python3
"""
Comprehensive Analysis: Cluster 1 (VM+Container) vs Cluster 2 (MicroVM)
"""

import json
import os
import glob
from statistics import mean, stdev, median
from collections import defaultdict

def load_results(base_dir):
    """Load all JSON results from a directory structure"""
    results = defaultdict(list)
    
    # Find all JSON files recursively
    json_files = glob.glob(os.path.join(base_dir, '**', '*.json'), recursive=True)
    
    for json_file in json_files:
        try:
            with open(json_file, 'r') as f:
                data = json.load(f)
                
                # Determine language and type from file path or data
                if 'language' in data and 'cold_start' in data:
                    lang = data['language']
                    start_type = 'cold' if data['cold_start'] else 'hot'
                    key = f"{lang}_{start_type}"
                    results[key].append(data)
                else:
                    # Try to infer from path
                    path_parts = json_file.split(os.sep)
                    for part in path_parts:
                        if 'python' in part.lower():
                            lang = 'python'
                        elif 'javascript' in part.lower() or 'js' in part.lower():
                            lang = 'javascript'
                        elif 'java' in part.lower() and 'javascript' not in part.lower():
                            lang = 'java'
                        else:
                            continue
                        
                        if 'cold' in part.lower():
                            start_type = 'cold'
                        elif 'hot' in part.lower():
                            start_type = 'hot'
                        else:
                            continue
                        
                        key = f"{lang}_{start_type}"
                        results[key].append(data)
                        break
        except Exception as e:
            print(f"Error loading {json_file}: {e}")
    
    return results

def extract_metrics(results):
    """Extract key metrics from results"""
    metrics = {}
    
    for key, data_list in results.items():
        if not data_list:
            continue
            
        # Extract invocation times
        inv_times = []
        for d in data_list:
            if 'invocation_time_s' in d:
                inv_times.append(d['invocation_time_s'])
        
        # Extract network metrics (average across all iterations)
        tcp_latencies = []
        http_latencies = []
        dns_latencies = []
        bandwidths = []
        
        for d in data_list:
            if 'benchmarks' in d:
                benchmarks = d['benchmarks']
                
                if 'tcp_latency' in benchmarks:
                    tcp_latencies.append(benchmarks['tcp_latency'].get('avg_ms', 0))
                if 'http_latency' in benchmarks:
                    http_latencies.append(benchmarks['http_latency'].get('avg_ms', 0))
                if 'dns_resolution' in benchmarks:
                    dns_latencies.append(benchmarks['dns_resolution'].get('avg_ms', 0))
                if 'bandwidth' in benchmarks:
                    bandwidths.append(benchmarks['bandwidth'].get('bandwidth_mbps', 0))
        
        metrics[key] = {
            'invocation_times': inv_times,
            'inv_mean': mean(inv_times) if inv_times else 0,
            'inv_stdev': stdev(inv_times) if len(inv_times) > 1 else 0,
            'inv_min': min(inv_times) if inv_times else 0,
            'inv_max': max(inv_times) if inv_times else 0,
            'inv_median': median(inv_times) if inv_times else 0,
            'tcp_ms': mean(tcp_latencies) if tcp_latencies else 0,
            'http_ms': mean(http_latencies) if http_latencies else 0,
            'dns_ms': mean(dns_latencies) if dns_latencies else 0,
            'bandwidth_mbps': mean(bandwidths) if bandwidths else 0,
            'count': len(inv_times)
        }
    
    return metrics

def print_comparison_table(cluster1_metrics, cluster2_metrics):
    """Print detailed comparison table"""
    
    print("\n" + "="*120)
    print("INVOCATION TIME COMPARISON (seconds)")
    print("="*120)
    print(f"{'Test':<20} {'Cluster':<10} {'Count':<7} {'Mean':<10} {'StdDev':<10} {'Min':<10} {'Max':<10} {'Median':<10}")
    print("-"*120)
    
    # Order: Python, JavaScript, Java; Cold then Hot
    order = [
        'python_cold', 'python_hot',
        'javascript_cold', 'javascript_hot', 
        'java_cold', 'java_hot'
    ]
    
    for test in order:
        if test in cluster1_metrics:
            m1 = cluster1_metrics[test]
            print(f"{test:<20} {'C1 (VM)':<10} {m1['count']:<7} {m1['inv_mean']:<10.2f} {m1['inv_stdev']:<10.2f} {m1['inv_min']:<10.2f} {m1['inv_max']:<10.2f} {m1['inv_median']:<10.2f}")
        
        if test in cluster2_metrics:
            m2 = cluster2_metrics[test]
            print(f"{test:<20} {'C2 (uVM)':<10} {m2['count']:<7} {m2['inv_mean']:<10.2f} {m2['inv_stdev']:<10.2f} {m2['inv_min']:<10.2f} {m2['inv_max']:<10.2f} {m2['inv_median']:<10.2f}")
        
        # Calculate difference
        if test in cluster1_metrics and test in cluster2_metrics:
            diff = cluster2_metrics[test]['inv_mean'] - cluster1_metrics[test]['inv_mean']
            pct = (diff / cluster1_metrics[test]['inv_mean'] * 100) if cluster1_metrics[test]['inv_mean'] > 0 else 0
            print(f"{'Difference':<20} {'(C2-C1)':<10} {'':<7} {diff:>+10.2f} {'':<10} {'':<10} {'':<10} {pct:>+9.1f}%")
        
        print()

def print_network_comparison(cluster1_metrics, cluster2_metrics):
    """Print network metrics comparison"""
    
    print("\n" + "="*100)
    print("NETWORK PERFORMANCE COMPARISON (milliseconds & Mbps)")
    print("="*100)
    print(f"{'Test':<20} {'Cluster':<10} {'TCP (ms)':<12} {'HTTP (ms)':<12} {'DNS (ms)':<12} {'BW (Mbps)':<12}")
    print("-"*100)
    
    order = [
        'python_cold', 'python_hot',
        'javascript_cold', 'javascript_hot',
        'java_cold', 'java_hot'
    ]
    
    for test in order:
        if test in cluster1_metrics:
            m1 = cluster1_metrics[test]
            print(f"{test:<20} {'C1 (VM)':<10} {m1['tcp_ms']:<12.2f} {m1['http_ms']:<12.2f} {m1['dns_ms']:<12.2f} {m1['bandwidth_mbps']:<12.2f}")
        
        if test in cluster2_metrics:
            m2 = cluster2_metrics[test]
            print(f"{test:<20} {'C2 (uVM)':<10} {m2['tcp_ms']:<12.2f} {m2['http_ms']:<12.2f} {m2['dns_ms']:<12.2f} {m2['bandwidth_mbps']:<12.2f}")
        
        print()

def print_cold_hot_analysis(cluster1_metrics, cluster2_metrics):
    """Analyze cold vs hot start overhead"""
    
    print("\n" + "="*100)
    print("COLD vs HOT START OVERHEAD ANALYSIS")
    print("="*100)
    print(f"{'Language':<15} {'Cluster':<10} {'Cold (s)':<12} {'Hot (s)':<12} {'Overhead':<15} {'Ratio':<10}")
    print("-"*100)
    
    languages = ['python', 'javascript', 'java']
    
    for lang in languages:
        cold_key = f"{lang}_cold"
        hot_key = f"{lang}_hot"
        
        # Cluster 1
        if cold_key in cluster1_metrics and hot_key in cluster1_metrics:
            cold = cluster1_metrics[cold_key]['inv_mean']
            hot = cluster1_metrics[hot_key]['inv_mean']
            overhead = cold - hot
            ratio = cold / hot if hot > 0 else 0
            print(f"{lang:<15} {'C1 (VM)':<10} {cold:<12.2f} {hot:<12.2f} {f'+{overhead:.2f}s':<15} {f'{ratio:.1f}x':<10}")
        
        # Cluster 2
        if cold_key in cluster2_metrics and hot_key in cluster2_metrics:
            cold = cluster2_metrics[cold_key]['inv_mean']
            hot = cluster2_metrics[hot_key]['inv_mean']
            overhead = cold - hot
            ratio = cold / hot if hot > 0 else 0
            print(f"{lang:<15} {'C2 (uVM)':<10} {cold:<12.2f} {hot:<12.2f} {f'+{overhead:.2f}s':<15} {f'{ratio:.1f}x':<10}")
        
        print()

def print_cluster_overhead_analysis(cluster1_metrics, cluster2_metrics):
    """Analyze MicroVM overhead vs VM+Container"""
    
    print("\n" + "="*100)
    print("MICROVM OVERHEAD ANALYSIS (Cluster 2 vs Cluster 1)")
    print("="*100)
    print(f"{'Test':<20} {'C1 Mean (s)':<15} {'C2 Mean (s)':<15} {'Overhead':<15} {'% Overhead':<12}")
    print("-"*100)
    
    order = [
        'python_cold', 'python_hot',
        'javascript_cold', 'javascript_hot',
        'java_cold', 'java_hot'
    ]
    
    for test in order:
        if test in cluster1_metrics and test in cluster2_metrics:
            c1_mean = cluster1_metrics[test]['inv_mean']
            c2_mean = cluster2_metrics[test]['inv_mean']
            overhead = c2_mean - c1_mean
            pct = (overhead / c1_mean * 100) if c1_mean > 0 else 0
            
            symbol = "+" if overhead > 0 else ""
            print(f"{test:<20} {c1_mean:<15.2f} {c2_mean:<15.2f} {f'{symbol}{overhead:.2f}s':<15} {f'{symbol}{pct:.1f}%':<12}")
    
    print()

def generate_summary(cluster1_metrics, cluster2_metrics):
    """Generate executive summary"""
    
    print("\n" + "="*100)
    print("EXECUTIVE SUMMARY")
    print("="*100)
    
    # Calculate average overhead
    overheads = []
    for test in ['python_cold', 'python_hot', 'javascript_cold', 'javascript_hot', 'java_cold', 'java_hot']:
        if test in cluster1_metrics and test in cluster2_metrics:
            c1 = cluster1_metrics[test]['inv_mean']
            c2 = cluster2_metrics[test]['inv_mean']
            pct = ((c2 - c1) / c1 * 100) if c1 > 0 else 0
            overheads.append(pct)
    
    avg_overhead = mean(overheads) if overheads else 0
    
    print(f"\n1. MICROVM PERFORMANCE IMPACT:")
    print(f"   - Average overhead: {avg_overhead:+.1f}%")
    
    if avg_overhead < 5:
        print(f"   ✓ MicroVM overhead is negligible (<5%)")
    elif avg_overhead < 10:
        print(f"   ⚠ MicroVM overhead is minimal (5-10%)")
    else:
        print(f"   ⚠ MicroVM overhead is significant (>10%)")
    
    # Network comparison
    print(f"\n2. NETWORK PERFORMANCE:")
    
    # Average network metrics
    c1_tcp_vals = [m['tcp_ms'] for m in cluster1_metrics.values() if m['tcp_ms'] > 0]
    c2_tcp_vals = [m['tcp_ms'] for m in cluster2_metrics.values() if m['tcp_ms'] > 0]
    
    c1_http_vals = [m['http_ms'] for m in cluster1_metrics.values() if m['http_ms'] > 0]
    c2_http_vals = [m['http_ms'] for m in cluster2_metrics.values() if m['http_ms'] > 0]
    
    if c1_tcp_vals and c2_tcp_vals:
        c1_tcp = mean(c1_tcp_vals)
        c2_tcp = mean(c2_tcp_vals)
        print(f"   - TCP Latency:  C1={c1_tcp:.1f}ms, C2={c2_tcp:.1f}ms (Δ={c2_tcp-c1_tcp:+.1f}ms)")
    
    if c1_http_vals and c2_http_vals:
        c1_http = mean(c1_http_vals)
        c2_http = mean(c2_http_vals)
        print(f"   - HTTP Latency: C1={c1_http:.1f}ms, C2={c2_http:.1f}ms (Δ={c2_http-c1_http:+.1f}ms)")
    
    if c1_tcp_vals and c2_tcp_vals and c1_http_vals and c2_http_vals:
        if abs(c2_tcp - c1_tcp) < 1 and abs(c2_http - c1_http) < 50:
            print(f"   ✓ Network performance is equivalent between clusters")
    
    # Cold vs Hot
    print(f"\n3. COLD vs HOT START EFFICIENCY:")
    
    for lang in ['python', 'javascript', 'java']:
        cold_key = f"{lang}_cold"
        hot_key = f"{lang}_hot"
        
        if cold_key in cluster2_metrics and hot_key in cluster2_metrics:
            cold = cluster2_metrics[cold_key]['inv_mean']
            hot = cluster2_metrics[hot_key]['inv_mean']
            ratio = cold / hot
            savings = ((cold - hot) / cold * 100)
            print(f"   - {lang.capitalize():12}: {ratio:.1f}x slower (cold), {savings:.0f}% time saved with hot starts")
    
    print("\n" + "="*100)

def save_to_csv(cluster1_metrics, cluster2_metrics):
    """Save results to CSV for further analysis"""
    
    with open('./cluster_comparison.csv', 'w') as f:
        f.write("Test,Cluster,Count,Mean_s,StdDev_s,Min_s,Max_s,Median_s,TCP_ms,HTTP_ms,DNS_ms,BW_Mbps\n")
        
        for test in sorted(cluster1_metrics.keys()):
            m = cluster1_metrics[test]
            f.write(f"{test},C1,{m['count']},{m['inv_mean']:.3f},{m['inv_stdev']:.3f},{m['inv_min']:.3f},{m['inv_max']:.3f},{m['inv_median']:.3f},{m['tcp_ms']:.2f},{m['http_ms']:.2f},{m['dns_ms']:.2f},{m['bandwidth_mbps']:.2f}\n")
        
        for test in sorted(cluster2_metrics.keys()):
            m = cluster2_metrics[test]
            f.write(f"{test},C2,{m['count']},{m['inv_mean']:.3f},{m['inv_stdev']:.3f},{m['inv_min']:.3f},{m['inv_max']:.3f},{m['inv_median']:.3f},{m['tcp_ms']:.2f},{m['http_ms']:.2f},{m['dns_ms']:.2f},{m['bandwidth_mbps']:.2f}\n")
    
    print(f"\n✓ Detailed results saved to: cluster_comparison.csv")

def main():
    print("\n" + "="*100)
    print("CLUSTER COMPARISON ANALYSIS")
    print("Cluster 1: VM + Container (Docker/runc)")
    print("Cluster 2: MicroVM (Kata Containers + QEMU 6.2.0)")
    print("="*100)
    
    # Load results
    print("\nLoading results...")
    cluster1_results = load_results('./cluster_1_results')
    cluster2_results = load_results('./cluster_2_results')
    
    # Extract metrics
    cluster1_metrics = extract_metrics(cluster1_results)
    cluster2_metrics = extract_metrics(cluster2_results)
    
    print(f"\nCluster 1 Tests Found: {len(cluster1_metrics)}")
    for key in sorted(cluster1_metrics.keys()):
        print(f"  - {key}: {cluster1_metrics[key]['count']} samples")
    
    print(f"\nCluster 2 Tests Found: {len(cluster2_metrics)}")
    for key in sorted(cluster2_metrics.keys()):
        print(f"  - {key}: {cluster2_metrics[key]['count']} samples")
    
    # Print all analyses
    print_comparison_table(cluster1_metrics, cluster2_metrics)
    print_network_comparison(cluster1_metrics, cluster2_metrics)
    print_cold_hot_analysis(cluster1_metrics, cluster2_metrics)
    print_cluster_overhead_analysis(cluster1_metrics, cluster2_metrics)
    generate_summary(cluster1_metrics, cluster2_metrics)
    
    # Save detailed results to CSV
    save_to_csv(cluster1_metrics, cluster2_metrics)

if __name__ == '__main__':
    main()