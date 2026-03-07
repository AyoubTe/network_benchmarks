import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.URL;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import com.google.gson.Gson;
import com.google.gson.JsonObject;

public class NetworkBenchmark {
    
    private static final Gson gson = new Gson();
    
    public static JsonObject benchmarkTcpLatency(String host, int port, int iterations) {
        List<Long> latencies = new ArrayList<>();
        
        for (int i = 0; i < iterations; i++) {
            long start = System.currentTimeMillis();
            
            try (Socket socket = new Socket()) {
                socket.connect(new InetSocketAddress(host, port), 5000);
                long latency = System.currentTimeMillis() - start;
                latencies.add(latency);
            } catch (IOException e) {
                System.err.println("Connection failed: " + e.getMessage());
                latencies.add(-1L);
            }
        }
        
        List<Long> validLatencies = new ArrayList<>();
        for (Long l : latencies) {
            if (l > 0) validLatencies.add(l);
        }
        
        JsonObject result = new JsonObject();
        result.addProperty("metric", "tcp_latency");
        result.addProperty("host", host);
        result.addProperty("port", port);
        result.addProperty("iterations", iterations);
        result.add("latencies_ms", gson.toJsonTree(validLatencies));
        
        if (!validLatencies.isEmpty()) {
            result.addProperty("min_ms", Collections.min(validLatencies));
            result.addProperty("max_ms", Collections.max(validLatencies));
            result.addProperty("avg_ms", calculateAverage(validLatencies));
            result.addProperty("median_ms", calculateMedian(validLatencies));
            result.addProperty("stdev_ms", calculateStdDev(validLatencies));
        }
        
        return result;
    }
    
    public static JsonObject benchmarkHttpLatency(String urlString, int iterations) {
        List<Long> latencies = new ArrayList<>();
        
        for (int i = 0; i < iterations; i++) {
            long start = System.currentTimeMillis();
            
            try {
                URL url = new URL(urlString);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("GET");
                conn.setConnectTimeout(10000);
                conn.setReadTimeout(10000);
                
                BufferedReader in = new BufferedReader(
                    new InputStreamReader(conn.getInputStream())
                );
                
                String inputLine;
                StringBuilder content = new StringBuilder();
                while ((inputLine = in.readLine()) != null) {
                    content.append(inputLine);
                }
                
                in.close();
                conn.disconnect();
                
                long latency = System.currentTimeMillis() - start;
                latencies.add(latency);
                
            } catch (IOException e) {
                System.err.println("HTTP request failed: " + e.getMessage());
                latencies.add(-1L);
            }
        }
        
        List<Long> validLatencies = new ArrayList<>();
        for (Long l : latencies) {
            if (l > 0) validLatencies.add(l);
        }
        
        JsonObject result = new JsonObject();
        result.addProperty("metric", "http_latency");
        result.addProperty("url", urlString);
        result.addProperty("iterations", iterations);
        result.add("latencies_ms", gson.toJsonTree(validLatencies));
        
        if (!validLatencies.isEmpty()) {
            result.addProperty("min_ms", Collections.min(validLatencies));
            result.addProperty("max_ms", Collections.max(validLatencies));
            result.addProperty("avg_ms", calculateAverage(validLatencies));
            result.addProperty("median_ms", calculateMedian(validLatencies));
            result.addProperty("stdev_ms", calculateStdDev(validLatencies));
        }
        
        return result;
    }
    
    public static JsonObject benchmarkDnsResolution(String domain, int iterations) {
        List<Long> latencies = new ArrayList<>();
        
        for (int i = 0; i < iterations; i++) {
            long start = System.currentTimeMillis();
            
            try {
                InetAddress.getByName(domain);
                long latency = System.currentTimeMillis() - start;
                latencies.add(latency);
            } catch (UnknownHostException e) {
                System.err.println("DNS resolution failed: " + e.getMessage());
                latencies.add(-1L);
            }
        }
        
        List<Long> validLatencies = new ArrayList<>();
        for (Long l : latencies) {
            if (l > 0) validLatencies.add(l);
        }
        
        JsonObject result = new JsonObject();
        result.addProperty("metric", "dns_resolution");
        result.addProperty("domain", domain);
        result.addProperty("iterations", iterations);
        result.add("latencies_ms", gson.toJsonTree(validLatencies));
        
        if (!validLatencies.isEmpty()) {
            result.addProperty("min_ms", Collections.min(validLatencies));
            result.addProperty("max_ms", Collections.max(validLatencies));
            result.addProperty("avg_ms", calculateAverage(validLatencies));
            result.addProperty("median_ms", calculateMedian(validLatencies));
        }
        
        return result;
    }
    
    public static JsonObject benchmarkBandwidth(String urlString) {
        List<Double> downloadTimes = new ArrayList<>();
        double fileSizeMb = 0;
        
        for (int i = 0; i < 3; i++) {
            long start = System.currentTimeMillis();
            
            try {
                URL url = new URL(urlString);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("GET");
                conn.setConnectTimeout(30000);
                conn.setReadTimeout(30000);
                
                InputStream in = conn.getInputStream();
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                
                byte[] buffer = new byte[8192];
                int bytesRead;
                while ((bytesRead = in.read(buffer)) != -1) {
                    out.write(buffer, 0, bytesRead);
                }
                
                in.close();
                conn.disconnect();
                
                double downloadTime = (System.currentTimeMillis() - start) / 1000.0;
                downloadTimes.add(downloadTime);
                
                // Calculate file size
                long sizeBytes = out.size();
                fileSizeMb = sizeBytes / (1024.0 * 1024.0);
                
            } catch (IOException e) {
                System.err.println("Download failed: " + e.getMessage());
                JsonObject error = new JsonObject();
                error.addProperty("metric", "bandwidth");
                error.addProperty("url", urlString);
                error.addProperty("error", e.getMessage());
                return error;
            }
        }
        
        double avgTime = downloadTimes.stream()
            .mapToDouble(Double::doubleValue)
            .average()
            .orElse(0.0);
        double avgBandwidth = (fileSizeMb * 8) / avgTime;
        
        JsonObject result = new JsonObject();
        result.addProperty("metric", "bandwidth");
        result.addProperty("url", urlString);
        result.addProperty("file_size_mb", Math.round(fileSizeMb * 100.0) / 100.0);
        result.add("download_times_s", gson.toJsonTree(downloadTimes));
        result.addProperty("avg_download_time_s", avgTime);
        result.addProperty("bandwidth_mbps", avgBandwidth);
        result.addProperty("min_time_s", Collections.min(downloadTimes));
        result.addProperty("max_time_s", Collections.max(downloadTimes));
        
        return result;
    }
    
    private static double calculateAverage(List<Long> values) {
        return values.stream()
            .mapToLong(Long::longValue)
            .average()
            .orElse(0.0);
    }
    
    private static long calculateMedian(List<Long> values) {
        List<Long> sorted = new ArrayList<>(values);
        Collections.sort(sorted);
        int size = sorted.size();
        if (size == 0) return 0;
        if (size % 2 == 0) {
            return (sorted.get(size / 2 - 1) + sorted.get(size / 2)) / 2;
        } else {
            return sorted.get(size / 2);
        }
    }
    
    private static double calculateStdDev(List<Long> values) {
        double avg = calculateAverage(values);
        double sumSquaredDiff = values.stream()
            .mapToDouble(v -> Math.pow(v - avg, 2))
            .sum();
        return Math.sqrt(sumSquaredDiff / values.size());
    }
    
    public static JsonObject runAllBenchmarks() {
        JsonObject results = new JsonObject();
        results.addProperty("timestamp", System.currentTimeMillis());
        
        JsonObject benchmarks = new JsonObject();
        
        System.out.println("Running TCP Latency Benchmark...");
        benchmarks.add("tcp_latency", benchmarkTcpLatency("8.8.8.8", 53, 10));
        
        System.out.println("Running HTTP Latency Benchmark...");
        benchmarks.add("http_latency", benchmarkHttpLatency("http://httpbin.org/get", 10));
        
        System.out.println("Running DNS Resolution Benchmark...");
        benchmarks.add("dns_resolution", benchmarkDnsResolution("google.com", 10));
        
        System.out.println("Running Bandwidth Benchmark...");
        benchmarks.add("bandwidth", benchmarkBandwidth("https://hagimont.freeboxos.fr/hagimont/software/resteasy-jaxrs-3.0.9.Final-all.zip"));
        
        results.add("benchmarks", benchmarks);
        
        return results;
    }
    
    public static JsonObject main(JsonObject args) {
        return runAllBenchmarks();
    }
    
    public static void main(String[] args) {
        JsonObject results = runAllBenchmarks();
        System.out.println(gson.toJson(results));
    }
}