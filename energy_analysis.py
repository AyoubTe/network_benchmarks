#!/usr/bin/env python3
import csv
import statistics

IDLE_BASELINE = 2800  # Joules

def analyze_energy_csv(filepath, name):
    """Analyze energy from CSV file"""
    energy_values = []
    
    try:
        with open(filepath, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                # Get the second column (energy value)
                # Skip the Time column, get cluster2-worker-1 value
                for col, value in row.items():
                    if col.lower() != 'time':
                        try:
                            energy_values.append(float(value))
                        except:
                            pass
                        break
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return None
    
    if not energy_values:
        return None
    
    return {
        'name': name,
        'samples': len(energy_values),
        'mean': statistics.mean(energy_values),
        'stdev': statistics.stdev(energy_values) if len(energy_values) > 1 else 0,
        'min': min(energy_values),
        'max': max(energy_values),
        'total': sum(energy_values),
        'overhead_per_invocation': statistics.mean(energy_values) - IDLE_BASELINE,
        'total_overhead': sum(energy_values) - (IDLE_BASELINE * len(energy_values))
    }

# Analyze all CSV files
results = []

csv_files = {
    'Java Cold': './benchmark_results/energy_consumption/NetBench_Java_Cold-data-2026-03-05_13_44_28.csv',
    'JavaScript Cold': './benchmark_results/energy_consumption/NetBench_JavaScript_Cold-data-2026-03-05_13_45_20.csv',
    'JavaScript Hot 1': './benchmark_results/energy_consumption/NetBench_JavaScript_Hot-data-2026-03-05_13_44_56.csv',
    'JavaScript Hot 2': './benchmark_results/energy_consumption/NetBench_JavaScript_Hot-data-2026-03-05_13_45_36.csv',
    'Python Cold': './benchmark_results/energy_consumption/NetBench_Python_Cold-data-2026-03-05_13_45_53.csv',
    'Python Hot': './benchmark_results/energy_consumption/NetBench_Python_Hot-data-2026-03-05_13_46_43.csv',
}

print("\n" + "="*100)
print("ENERGY CONSUMPTION ANALYSIS (Baseline: 2800J)")
print("="*100 + "\n")

for name, filepath in csv_files.items():
    result = analyze_energy_csv(filepath, name)
    if result:
        results.append(result)

if not results:
    print("ERROR: No data found! Check file paths.")
    import sys
    sys.exit(1)

# Print detailed table
print(f"{'Benchmark':<20} {'Samples':<8} {'Mean (J)':<12} {'StdDev':<10} {'Min (J)':<10} {'Max (J)':<10} {'Overhead/Inv':<15}")
print("-"*100)

for r in results:
    print(f"{r['name']:<20} {r['samples']:<8} {r['mean']:>9.1f}   {r['stdev']:>7.1f}   "
          f"{r['min']:>7.1f}   {r['max']:>7.1f}   {r['overhead_per_invocation']:>+10.1f}J")

print("\n" + "="*100 + "\n")

# Aggregate by language and type
aggregated = {}
for r in results:
    if 'Cold' in r['name']:
        if 'Java' in r['name']:
            key = 'Java Cold'
        elif 'JavaScript' in r['name']:
            key = 'JavaScript Cold'
        elif 'Python' in r['name']:
            key = 'Python Cold'
    elif 'Hot' in r['name']:
        if 'Java' in r['name']:
            key = 'Java Hot'
        elif 'JavaScript' in r['name']:
            if 'JavaScript Hot' not in aggregated:
                aggregated['JavaScript Hot'] = {'samples': [], 'overhead': []}
            aggregated['JavaScript Hot']['samples'].append(r['samples'])
            aggregated['JavaScript Hot']['overhead'].append(r['overhead_per_invocation'])
            continue
        elif 'Python' in r['name']:
            key = 'Python Hot'
    else:
        continue
    
    if key not in aggregated:
        aggregated[key] = {'samples': [], 'overhead': []}
    
    aggregated[key]['samples'].append(r['samples'])
    aggregated[key]['overhead'].append(r['overhead_per_invocation'])

# Print summary
print("ENERGY OVERHEAD SUMMARY (vs 2800J Idle Baseline):\n")
print(f"{'Benchmark':<20} {'Samples':<10} {'Avg Overhead/Invocation':<30}")
print("-"*70)

for key in sorted(aggregated.keys()):
    data = aggregated[key]
    total_samples = sum(data['samples'])
    avg_overhead = statistics.mean(data['overhead'])
    
    print(f"{key:<20} {total_samples:<10} {avg_overhead:>+8.1f}J")

print("\n" + "="*100 + "\n")

# Cold vs Hot comparison
print("COLD vs HOT ENERGY COMPARISON:\n")
print(f"{'Language':<15} {'Cold Overhead':<20} {'Hot Overhead':<20} {'Energy Saved':<20}")
print("-"*80)

for lang in ['Python', 'JavaScript', 'Java']:
    cold_key = f'{lang} Cold'
    hot_key = f'{lang} Hot'
    
    if cold_key in aggregated and hot_key in aggregated:
        cold_overhead = statistics.mean(aggregated[cold_key]['overhead'])
        hot_overhead = statistics.mean(aggregated[hot_key]['overhead'])
        savings = cold_overhead - hot_overhead
        savings_pct = (savings / cold_overhead * 100) if cold_overhead != 0 else 0
        
        print(f"{lang:<15} {cold_overhead:>+8.1f}J           {hot_overhead:>+8.1f}J           {savings:>+8.1f}J ({savings_pct:.0f}%)")

print("\n" + "="*100 + "\n")

# Total energy consumption for full benchmark
print("TOTAL ENERGY FOR COMPLETE BENCHMARK RUNS:\n")
print(f"{'Scenario':<25} {'Total Energy':<20} {'Total Overhead':<20} {'Efficiency Loss':<15}")
print("-"*85)

for r in results:
    efficiency = (r['total_overhead'] / r['total']) * 100
    print(f"{r['name']:<25} {r['total']:>10.1f}J        {r['total_overhead']:>+10.1f}J        {efficiency:>6.1f}%")

print("\n" + "="*100 + "\n")

