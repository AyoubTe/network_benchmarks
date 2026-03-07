/**
 * Network Benchmark for Serverless Functions (Node.js)
 * Updated with new bandwidth test URL
 */

const http = require('http');
const https = require('https');
const dns = require('dns').promises;
const net = require('net');

async function benchmarkTcpLatency(host = '8.8.8.8', port = 53, iterations = 10) {
    const latencies = [];
    
    for (let i = 0; i < iterations; i++) {
        const start = Date.now();
        
        try {
            await new Promise((resolve, reject) => {
                const socket = net.connect(port, host, () => {
                    socket.end();
                    resolve();
                });
                socket.on('error', reject);
                socket.setTimeout(5000);
                socket.on('timeout', () => {
                    socket.destroy();
                    reject(new Error('Timeout'));
                });
            });
            
            const latency = Date.now() - start;
            latencies.push(latency);
        } catch (error) {
            console.error(`Connection failed: ${error.message}`);
            latencies.push(-1);
        }
    }
    
    const validLatencies = latencies.filter(l => l > 0);
    
    return {
        metric: 'tcp_latency',
        host,
        port,
        iterations,
        latencies_ms: validLatencies,
        min_ms: Math.min(...validLatencies),
        max_ms: Math.max(...validLatencies),
        avg_ms: validLatencies.reduce((a, b) => a + b, 0) / validLatencies.length,
        median_ms: validLatencies.sort((a, b) => a - b)[Math.floor(validLatencies.length / 2)],
        stdev_ms: calculateStdDev(validLatencies)
    };
}

async function benchmarkHttpLatency(url = 'http://httpbin.org/get', iterations = 10) {
    const latencies = [];
    
    for (let i = 0; i < iterations; i++) {
        const start = Date.now();
        
        try {
            await new Promise((resolve, reject) => {
                const client = url.startsWith('https') ? https : http;
                const req = client.get(url, (res) => {
                    let data = '';
                    res.on('data', chunk => data += chunk);
                    res.on('end', () => resolve(data));
                });
                req.on('error', reject);
                req.setTimeout(10000);
                req.on('timeout', () => {
                    req.destroy();
                    reject(new Error('Timeout'));
                });
            });
            
            const latency = Date.now() - start;
            latencies.push(latency);
        } catch (error) {
            console.error(`HTTP request failed: ${error.message}`);
            latencies.push(-1);
        }
    }
    
    const validLatencies = latencies.filter(l => l > 0);
    
    return {
        metric: 'http_latency',
        url,
        iterations,
        latencies_ms: validLatencies,
        min_ms: Math.min(...validLatencies),
        max_ms: Math.max(...validLatencies),
        avg_ms: validLatencies.reduce((a, b) => a + b, 0) / validLatencies.length,
        median_ms: validLatencies.sort((a, b) => a - b)[Math.floor(validLatencies.length / 2)],
        stdev_ms: calculateStdDev(validLatencies)
    };
}

async function benchmarkDnsResolution(domain = 'google.com', iterations = 10) {
    const latencies = [];
    
    for (let i = 0; i < iterations; i++) {
        const start = Date.now();
        
        try {
            await dns.resolve4(domain);
            const latency = Date.now() - start;
            latencies.push(latency);
        } catch (error) {
            console.error(`DNS resolution failed: ${error.message}`);
            latencies.push(-1);
        }
    }
    
    const validLatencies = latencies.filter(l => l > 0);
    
    return {
        metric: 'dns_resolution',
        domain,
        iterations,
        latencies_ms: validLatencies,
        min_ms: Math.min(...validLatencies),
        max_ms: Math.max(...validLatencies),
        avg_ms: validLatencies.reduce((a, b) => a + b, 0) / validLatencies.length,
        median_ms: validLatencies.sort((a, b) => a - b)[Math.floor(validLatencies.length / 2)]
    };
}

async function benchmarkBandwidth(url = 'https://hagimont.freeboxos.fr/hagimont/software/resteasy-jaxrs-3.0.9.Final-all.zip') {
    const downloadTimes = [];
    let fileSizeMb = null;
    
    for (let i = 0; i < 3; i++) {
        const start = Date.now();
        
        try {
            const data = await new Promise((resolve, reject) => {
                const client = url.startsWith('https') ? https : http;
                const req = client.get(url, (res) => {
                    const chunks = [];
                    res.on('data', chunk => chunks.push(chunk));
                    res.on('end', () => resolve(Buffer.concat(chunks)));
                });
                req.on('error', reject);
                req.setTimeout(30000);
            });
            
            const downloadTime = (Date.now() - start) / 1000; // Convert to seconds
            downloadTimes.push(downloadTime);
            
            // Calculate file size
            const sizeBytes = data.length;
            fileSizeMb = sizeBytes / (1024 * 1024);
            
        } catch (error) {
            console.error(`Download failed: ${error.message}`);
            return { 
                metric: 'bandwidth',
                url,
                error: error.message 
            };
        }
    }
    
    const avgTime = downloadTimes.reduce((a, b) => a + b, 0) / downloadTimes.length;
    const avgBandwidth = (fileSizeMb * 8) / avgTime; // Mbps
    
    return {
        metric: 'bandwidth',
        url,
        file_size_mb: Math.round(fileSizeMb * 100) / 100,
        download_times_s: downloadTimes,
        avg_download_time_s: avgTime,
        bandwidth_mbps: avgBandwidth,
        min_time_s: Math.min(...downloadTimes),
        max_time_s: Math.max(...downloadTimes)
    };
}

function calculateStdDev(values) {
    const avg = values.reduce((a, b) => a + b, 0) / values.length;
    const squareDiffs = values.map(value => Math.pow(value - avg, 2));
    const avgSquareDiff = squareDiffs.reduce((a, b) => a + b, 0) / squareDiffs.length;
    return Math.sqrt(avgSquareDiff);
}

async function runAllBenchmarks() {
    const results = {
        timestamp: Date.now(),
        benchmarks: {}
    };
    
    console.log('Running TCP Latency Benchmark...');
    results.benchmarks.tcp_latency = await benchmarkTcpLatency();
    
    console.log('Running HTTP Latency Benchmark...');
    results.benchmarks.http_latency = await benchmarkHttpLatency();
    
    console.log('Running DNS Resolution Benchmark...');
    results.benchmarks.dns_resolution = await benchmarkDnsResolution();
    
    console.log('Running Bandwidth Benchmark...');
    results.benchmarks.bandwidth = await benchmarkBandwidth();
    
    return results;
}

async function main(params) {
    return await runAllBenchmarks();
}

if (require.main === module) {
    runAllBenchmarks().then(results => {
        console.log(JSON.stringify(results, null, 2));
    }).catch(error => {
        console.error('Error:', error);
        process.exit(1);
    });
}

exports.main = main;