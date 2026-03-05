#!/usr/bin/env python3
"""
Network Benchmark for Serverless Functions
Commonly used metrics in serverless research papers
"""
import time
import socket
import http.client
import json
import statistics
from urllib.request import urlopen
from urllib.error import URLError

def benchmark_tcp_latency(host="8.8.8.8", port=53, iterations=10):
    """
    TCP Connection Latency Benchmark
    Measures time to establish TCP connection
    """
    latencies = []
    
    for i in range(iterations):
        start = time.time()
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            sock.connect((host, port))
            sock.close()
            latency = (time.time() - start) * 1000  # Convert to ms
            latencies.append(latency)
        except Exception as e:
            print(f"Connection failed: {e}")
            latencies.append(-1)
    
    valid_latencies = [l for l in latencies if l > 0]
    
    return {
        "metric": "tcp_latency",
        "host": host,
        "port": port,
        "iterations": iterations,
        "latencies_ms": valid_latencies,
        "min_ms": min(valid_latencies) if valid_latencies else 0,
        "max_ms": max(valid_latencies) if valid_latencies else 0,
        "avg_ms": statistics.mean(valid_latencies) if valid_latencies else 0,
        "median_ms": statistics.median(valid_latencies) if valid_latencies else 0,
        "stdev_ms": statistics.stdev(valid_latencies) if len(valid_latencies) > 1 else 0
    }

def benchmark_http_latency(url="http://httpbin.org/get", iterations=10):
    """
    HTTP Request Latency Benchmark
    Measures end-to-end HTTP request time
    """
    latencies = []
    
    for i in range(iterations):
        start = time.time()
        try:
            response = urlopen(url, timeout=10)
            response.read()
            latency = (time.time() - start) * 1000
            latencies.append(latency)
        except URLError as e:
            print(f"HTTP request failed: {e}")
            latencies.append(-1)
    
    valid_latencies = [l for l in latencies if l > 0]
    
    return {
        "metric": "http_latency",
        "url": url,
        "iterations": iterations,
        "latencies_ms": valid_latencies,
        "min_ms": min(valid_latencies) if valid_latencies else 0,
        "max_ms": max(valid_latencies) if valid_latencies else 0,
        "avg_ms": statistics.mean(valid_latencies) if valid_latencies else 0,
        "median_ms": statistics.median(valid_latencies) if valid_latencies else 0,
        "stdev_ms": statistics.stdev(valid_latencies) if len(valid_latencies) > 1 else 0
    }

def benchmark_bandwidth(url="http://speedtest.ftp.otenet.gr/files/test1Mb.db", size_mb=1):
    """
    Bandwidth Benchmark
    Measures download speed
    """
    download_times = []
    
    for i in range(3):
        start = time.time()
        try:
            response = urlopen(url, timeout=30)
            data = response.read()
            download_time = time.time() - start
            download_times.append(download_time)
            
            # Calculate bandwidth in Mbps
            size_bytes = len(data)
            bandwidth_mbps = (size_bytes * 8) / (download_time * 1000000)
            
        except URLError as e:
            print(f"Download failed: {e}")
            return {"error": str(e)}
    
    avg_time = statistics.mean(download_times)
    avg_bandwidth = (size_mb * 8) / avg_time
    
    return {
        "metric": "bandwidth",
        "url": url,
        "size_mb": size_mb,
        "download_times_s": download_times,
        "avg_download_time_s": avg_time,
        "bandwidth_mbps": avg_bandwidth,
        "min_time_s": min(download_times),
        "max_time_s": max(download_times)
    }

def benchmark_dns_resolution(domain="google.com", iterations=10):
    """
    DNS Resolution Latency
    Measures DNS lookup time
    """
    latencies = []
    
    for i in range(iterations):
        start = time.time()
        try:
            socket.gethostbyname(domain)
            latency = (time.time() - start) * 1000
            latencies.append(latency)
        except socket.gaierror as e:
            print(f"DNS resolution failed: {e}")
            latencies.append(-1)
    
    valid_latencies = [l for l in latencies if l > 0]
    
    return {
        "metric": "dns_resolution",
        "domain": domain,
        "iterations": iterations,
        "latencies_ms": valid_latencies,
        "min_ms": min(valid_latencies) if valid_latencies else 0,
        "max_ms": max(valid_latencies) if valid_latencies else 0,
        "avg_ms": statistics.mean(valid_latencies) if valid_latencies else 0,
        "median_ms": statistics.median(valid_latencies) if valid_latencies else 0
    }

def run_all_benchmarks():
    """
    OpenWhisk Action Handler - runs all network benchmarks
    """
    results = {
        "timestamp": time.time(),
        "benchmarks": {}
    }
    
    print("Running TCP Latency Benchmark...")
    results["benchmarks"]["tcp_latency"] = benchmark_tcp_latency()
    
    print("Running HTTP Latency Benchmark...")
    results["benchmarks"]["http_latency"] = benchmark_http_latency()
    
    print("Running DNS Resolution Benchmark...")
    results["benchmarks"]["dns_resolution"] = benchmark_dns_resolution()
    
    print("Running Bandwidth Benchmark...")
    results["benchmarks"]["bandwidth"] = benchmark_bandwidth()
    
    return results

def main(args):
    """
    OpenWhisk entry point
    """
    return run_all_benchmarks()

if __name__ == "__main__":
    # For local testing
    results = run_all_benchmarks()
    print(json.dumps(results, indent=2))
