const logger = require('../utils/logger');

class PerformanceMonitor {
  constructor() {
    this.metrics = new Map();
    this.activeRequests = new Map();
    this.performanceThresholds = {
      api_response: 2000, // 2 seconds
      ai_analysis: 5000, // 5 seconds
      nerf_analysis: 10000, // 10 seconds
      camera_connection: 3000, // 3 seconds
      database_query: 1000, // 1 second
      image_processing: 3000 // 3 seconds
    };
    
    this.alertCallbacks = new Set();
    this.metricsBuffer = [];
    this.bufferSize = 1000;
    
    // Start periodic cleanup
    this.startCleanupTimer();
  }

  // Middleware for Express.js to monitor API performance
  apiPerformanceMiddleware() {
    return (req, res, next) => {
      const startTime = process.hrtime.bigint();
      const requestId = `${req.method}_${req.path}_${Date.now()}`;
      
      // Store request start
      this.activeRequests.set(requestId, {
        method: req.method,
        path: req.path,
        startTime,
        userAgent: req.get('User-Agent'),
        ip: req.ip
      });
      
      // Capture response end
      const originalEnd = res.end;
      res.end = (...args) => {
        const endTime = process.hrtime.bigint();
        const duration = Number(endTime - startTime) / 1000000; // Convert to milliseconds
        
        // Record performance metric
        this.recordMetric('api_response', {
          method: req.method,
          path: req.path,
          statusCode: res.statusCode,
          duration,
          requestId,
          timestamp: new Date().toISOString()
        });
        
        // Check for performance issues
        this.checkPerformanceThreshold('api_response', duration, {
          method: req.method,
          path: req.path,
          statusCode: res.statusCode
        });
        
        // Clean up active request
        this.activeRequests.delete(requestId);
        
        // Call original end
        originalEnd.apply(res, args);
      };
      
      next();
    };
  }

  // Record a performance metric
  recordMetric(category, data) {
    const metric = {
      category,
      ...data,
      timestamp: data.timestamp || new Date().toISOString()
    };
    
    // Add to buffer
    this.metricsBuffer.push(metric);
    if (this.metricsBuffer.length > this.bufferSize) {
      this.metricsBuffer.shift(); // Remove oldest
    }
    
    // Update category metrics
    if (!this.metrics.has(category)) {
      this.metrics.set(category, {
        count: 0,
        totalDuration: 0,
        avgDuration: 0,
        minDuration: Infinity,
        maxDuration: 0,
        recentSamples: [],
        errorCount: 0
      });
    }
    
    const categoryMetrics = this.metrics.get(category);
    categoryMetrics.count++;
    
    if (data.duration !== undefined) {
      categoryMetrics.totalDuration += data.duration;
      categoryMetrics.avgDuration = categoryMetrics.totalDuration / categoryMetrics.count;
      categoryMetrics.minDuration = Math.min(categoryMetrics.minDuration, data.duration);
      categoryMetrics.maxDuration = Math.max(categoryMetrics.maxDuration, data.duration);
      
      // Keep recent samples for trend analysis
      categoryMetrics.recentSamples.push({
        duration: data.duration,
        timestamp: metric.timestamp
      });
      
      if (categoryMetrics.recentSamples.length > 100) {
        categoryMetrics.recentSamples.shift();
      }
    }
    
    if (data.error || (data.statusCode && data.statusCode >= 400)) {
      categoryMetrics.errorCount++;
    }
    
    // Log slow operations
    if (data.duration && this.performanceThresholds[category] && 
        data.duration > this.performanceThresholds[category]) {
      logger.warn(`Slow ${category} detected`, {
        duration: data.duration,
        threshold: this.performanceThresholds[category],
        details: data
      });
    }
  }

  // Monitor async operation performance
  async monitorAsync(category, operation, context = {}) {
    const startTime = process.hrtime.bigint();
    let result, error;
    
    try {
      result = await operation();
      return result;
    } catch (err) {
      error = err;
      throw err;
    } finally {
      const endTime = process.hrtime.bigint();
      const duration = Number(endTime - startTime) / 1000000;
      
      this.recordMetric(category, {
        duration,
        error: error?.message,
        success: !error,
        ...context
      });
    }
  }

  // Monitor sync operation performance
  monitorSync(category, operation, context = {}) {
    const startTime = process.hrtime.bigint();
    let result, error;
    
    try {
      result = operation();
      return result;
    } catch (err) {
      error = err;
      throw err;
    } finally {
      const endTime = process.hrtime.bigint();
      const duration = Number(endTime - startTime) / 1000000;
      
      this.recordMetric(category, {
        duration,
        error: error?.message,
        success: !error,
        ...context
      });
    }
  }

  // Check if performance exceeds threshold
  checkPerformanceThreshold(category, duration, context = {}) {
    const threshold = this.performanceThresholds[category];
    if (threshold && duration > threshold) {
      const alert = {
        type: 'performance_threshold_exceeded',
        category,
        duration,
        threshold,
        severity: this.calculateSeverity(duration, threshold),
        context,
        timestamp: new Date().toISOString()
      };
      
      this.triggerAlert(alert);
    }
  }

  calculateSeverity(duration, threshold) {
    const ratio = duration / threshold;
    if (ratio > 3) return 'critical';
    if (ratio > 2) return 'high';
    if (ratio > 1.5) return 'medium';
    return 'low';
  }

  // Add alert callback
  onAlert(callback) {
    this.alertCallbacks.add(callback);
  }

  // Remove alert callback
  offAlert(callback) {
    this.alertCallbacks.delete(callback);
  }

  // Trigger alert
  triggerAlert(alert) {
    logger.warn('Performance alert triggered', alert);
    
    for (const callback of this.alertCallbacks) {
      try {
        callback(alert);
      } catch (error) {
        logger.error('Error in alert callback:', error);
      }
    }
  }

  // Get performance summary
  getPerformanceSummary() {
    const summary = {
      overview: {
        totalCategories: this.metrics.size,
        totalRequests: Array.from(this.metrics.values()).reduce((sum, m) => sum + m.count, 0),
        activeRequests: this.activeRequests.size,
        bufferSize: this.metricsBuffer.length
      },
      categories: {},
      slowestOperations: this.getSlowestOperations(),
      errorRates: this.getErrorRates(),
      trends: this.getTrends()
    };
    
    // Process each category
    for (const [category, metrics] of this.metrics) {
      summary.categories[category] = {
        count: metrics.count,
        avgDuration: Math.round(metrics.avgDuration * 100) / 100,
        minDuration: metrics.minDuration === Infinity ? 0 : Math.round(metrics.minDuration * 100) / 100,
        maxDuration: Math.round(metrics.maxDuration * 100) / 100,
        errorCount: metrics.errorCount,
        errorRate: metrics.count > 0 ? (metrics.errorCount / metrics.count * 100).toFixed(2) + '%' : '0%',
        threshold: this.performanceThresholds[category] || 'N/A',
        recentAvg: this.getRecentAverage(metrics.recentSamples)
      };
    }
    
    return summary;
  }

  // Get recent average for trend analysis
  getRecentAverage(samples, windowSize = 10) {
    if (!samples || samples.length === 0) return 0;
    
    const recentSamples = samples.slice(-windowSize);
    const total = recentSamples.reduce((sum, sample) => sum + sample.duration, 0);
    return Math.round((total / recentSamples.length) * 100) / 100;
  }

  // Get slowest operations
  getSlowestOperations(limit = 10) {
    const slowOperations = this.metricsBuffer
      .filter(metric => metric.duration !== undefined)
      .sort((a, b) => b.duration - a.duration)
      .slice(0, limit)
      .map(metric => ({
        category: metric.category,
        duration: Math.round(metric.duration * 100) / 100,
        timestamp: metric.timestamp,
        context: this.sanitizeContext(metric)
      }));
    
    return slowOperations;
  }

  // Get error rates by category
  getErrorRates() {
    const errorRates = {};
    
    for (const [category, metrics] of this.metrics) {
      if (metrics.count > 0) {
        errorRates[category] = {
          errorCount: metrics.errorCount,
          totalCount: metrics.count,
          errorRate: ((metrics.errorCount / metrics.count) * 100).toFixed(2) + '%'
        };
      }
    }
    
    return errorRates;
  }

  // Get performance trends
  getTrends() {
    const trends = {};
    const now = Date.now();
    const oneHourAgo = now - (60 * 60 * 1000);
    
    for (const [category, metrics] of this.metrics) {
      const recentSamples = metrics.recentSamples.filter(
        sample => new Date(sample.timestamp).getTime() > oneHourAgo
      );
      
      if (recentSamples.length > 5) {
        const firstHalf = recentSamples.slice(0, Math.floor(recentSamples.length / 2));
        const secondHalf = recentSamples.slice(Math.floor(recentSamples.length / 2));
        
        const firstHalfAvg = firstHalf.reduce((sum, s) => sum + s.duration, 0) / firstHalf.length;
        const secondHalfAvg = secondHalf.reduce((sum, s) => sum + s.duration, 0) / secondHalf.length;
        
        const trendPercentage = ((secondHalfAvg - firstHalfAvg) / firstHalfAvg * 100);
        
        trends[category] = {
          trend: trendPercentage > 10 ? 'degrading' : 
                trendPercentage < -10 ? 'improving' : 'stable',
          change: Math.round(trendPercentage * 100) / 100,
          sampleCount: recentSamples.length
        };
      }
    }
    
    return trends;
  }

  // Sanitize context for logging
  sanitizeContext(metric) {
    const context = { ...metric };
    delete context.category;
    delete context.duration;
    delete context.timestamp;
    return context;
  }

  // Get metrics for specific category
  getCategoryMetrics(category) {
    return this.metrics.get(category) || null;
  }

  // Get recent metrics
  getRecentMetrics(category = null, limit = 50) {
    let metrics = this.metricsBuffer;
    
    if (category) {
      metrics = metrics.filter(m => m.category === category);
    }
    
    return metrics.slice(-limit);
  }

  // Clear metrics
  clearMetrics(category = null) {
    if (category) {
      this.metrics.delete(category);
      this.metricsBuffer = this.metricsBuffer.filter(m => m.category !== category);
    } else {
      this.metrics.clear();
      this.metricsBuffer = [];
    }
  }

  // Set custom threshold
  setThreshold(category, threshold) {
    this.performanceThresholds[category] = threshold;
  }

  // Get system resource usage
  getSystemMetrics() {
    const memUsage = process.memoryUsage();
    const cpuUsage = process.cpuUsage();
    
    return {
      memory: {
        rss: Math.round(memUsage.rss / 1024 / 1024 * 100) / 100, // MB
        heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024 * 100) / 100, // MB
        heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024 * 100) / 100, // MB
        external: Math.round(memUsage.external / 1024 / 1024 * 100) / 100, // MB
        arrayBuffers: Math.round(memUsage.arrayBuffers / 1024 / 1024 * 100) / 100 // MB
      },
      cpu: {
        user: cpuUsage.user,
        system: cpuUsage.system
      },
      uptime: Math.round(process.uptime()),
      activeHandles: process._getActiveHandles().length,
      activeRequests: process._getActiveRequests().length
    };
  }

  // Export metrics for external systems
  exportMetrics(format = 'json') {
    const data = {
      timestamp: new Date().toISOString(),
      summary: this.getPerformanceSummary(),
      systemMetrics: this.getSystemMetrics(),
      recentMetrics: this.getRecentMetrics()
    };
    
    switch (format) {
      case 'prometheus':
        return this.convertToPrometheusFormat(data);
      case 'csv':
        return this.convertToCSVFormat(data);
      default:
        return JSON.stringify(data, null, 2);
    }
  }

  // Convert to Prometheus format
  convertToPrometheusFormat(data) {
    let output = '';
    
    // API response metrics
    for (const [category, metrics] of Object.entries(data.summary.categories)) {
      output += `# HELP ${category}_duration_ms Average duration in milliseconds\n`;
      output += `# TYPE ${category}_duration_ms gauge\n`;
      output += `${category}_duration_ms ${metrics.avgDuration}\n\n`;
      
      output += `# HELP ${category}_count_total Total number of operations\n`;
      output += `# TYPE ${category}_count_total counter\n`;
      output += `${category}_count_total ${metrics.count}\n\n`;
      
      output += `# HELP ${category}_errors_total Total number of errors\n`;
      output += `# TYPE ${category}_errors_total counter\n`;
      output += `${category}_errors_total ${metrics.errorCount}\n\n`;
    }
    
    // System metrics
    output += `# HELP memory_usage_mb Memory usage in MB\n`;
    output += `# TYPE memory_usage_mb gauge\n`;
    output += `memory_usage_mb{type="heapUsed"} ${data.systemMetrics.memory.heapUsed}\n`;
    output += `memory_usage_mb{type="heapTotal"} ${data.systemMetrics.memory.heapTotal}\n`;
    output += `memory_usage_mb{type="rss"} ${data.systemMetrics.memory.rss}\n\n`;
    
    return output;
  }

  // Convert to CSV format
  convertToCSVFormat(data) {
    const rows = [
      ['timestamp', 'category', 'duration', 'method', 'path', 'statusCode', 'error']
    ];
    
    for (const metric of data.recentMetrics) {
      rows.push([
        metric.timestamp,
        metric.category,
        metric.duration || '',
        metric.method || '',
        metric.path || '',
        metric.statusCode || '',
        metric.error || ''
      ]);
    }
    
    return rows.map(row => row.join(',')).join('\n');
  }

  // Start cleanup timer
  startCleanupTimer() {
    // Clean up old metrics every hour
    setInterval(() => {
      const oneHourAgo = Date.now() - (60 * 60 * 1000);
      
      // Clean up metrics buffer
      this.metricsBuffer = this.metricsBuffer.filter(
        metric => new Date(metric.timestamp).getTime() > oneHourAgo
      );
      
      // Clean up recent samples in category metrics
      for (const metrics of this.metrics.values()) {
        metrics.recentSamples = metrics.recentSamples.filter(
          sample => new Date(sample.timestamp).getTime() > oneHourAgo
        );
      }
      
      logger.debug('Performance metrics cleanup completed');
    }, 60 * 60 * 1000); // Every hour
  }
}

// Global instance
const performanceMonitor = new PerformanceMonitor();

module.exports = performanceMonitor;