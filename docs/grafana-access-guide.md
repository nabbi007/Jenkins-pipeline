# Grafana Dashboard Access Guide

## 🎯 Quick Access

**Grafana URL:** http://108.130.163.21:3000  
**Username:** admin  
**Password:** admin

## 📊 Available Dashboards

You now have **3 professional dashboards** deployed:

### 1. **Application & Redis Metrics** ⭐ NEW
**Purpose:** Monitor your backend API and Redis database

**Includes:**
- **Health Overview**
  - Backend Status (UP/DOWN gauge)
  - Redis Status (UP/DOWN gauge)
  - Total Request Rate
  - Error Rate percentage

- **API Performance**
  - Request Rate by Route (timeseries)
  - Response Status Code Distribution (pie chart)
  - Response Time Percentiles (p95, p50, p99)
  - Response Time by Route (p95)

- **Redis Metrics**
  - Connected Clients
  - Memory Used
  - Total Keys
  - Commands Rate (operations/sec)
  - Memory Usage over time
  - Keys per Database

**Refresh:** 10 seconds  
**Time Range:** Last 30 minutes

---

### 2. **System Metrics** ⭐ NEW
**Purpose:** Monitor infrastructure health and resource usage

**Includes:**
- **Health Overview**
  - CPU Usage (gauge with thresholds: yellow at 70%, red at 90%)
  - Memory Usage (gauge with thresholds)
  - Disk Usage (gauge with thresholds)
  - System Uptime

- **CPU Details**
  - CPU Usage by Mode (System, User, I/O Wait, Idle)
  - System Load Average (1m, 5m, 15m)

- **Memory Details**
  - Memory breakdown (Total, Used, Available, Cached, Buffers)
  - Memory Swap Activity

- **Disk & Network**
  - Disk I/O (Read/Write bytes/sec)
  - Network Traffic (Receive/Transmit)
  - Filesystem Usage
  - Disk IOPS

**Refresh:** 10 seconds  
**Time Range:** Last 30 minutes

---

### 3. **Backend Service Overview**
**Purpose:** Basic backend monitoring (existing dashboard)

---

## 🚀 How to Access

1. **Open your browser** and navigate to:
   ```
   http://108.130.163.21:3000
   ```

2. **Login** with credentials:
   - Username: `admin`
   - Password: `admin`

3. **Navigate to Dashboards:**
   - Click the **Dashboards icon** (grid/squares) in the left sidebar
   - OR click **Home** dropdown at the top

4. **Select a Dashboard:**
   - Click on **"Application & Redis Metrics"** for app monitoring
   - Click on **"System Metrics"** for infrastructure monitoring
   - Click on **"Backend Service Overview"** for basic backend stats

## 📈 Dashboard Features

### Navigation
- **Time Range Selector** (top right): Change from "Last 30m" to other ranges
- **Refresh Interval** (top right): Currently set to 10s auto-refresh
- **Zoom**: Click and drag on any graph to zoom into a time range
- **Query Inspector**: Click panel title → Inspect → Query to see PromQL

### Customization
- **Edit Panels**: Click panel title → Edit
- **Add Panels**: Click "Add" → "Visualization"
- **Share Dashboard**: Click share icon (top right)
- **Save Changes**: Click save icon (top right)

## ✅ Current Status

All metrics are **ACTIVE** and collecting data:

```
✓ backend: UP
✓ node_exporter: UP (2 instances)
✓ prometheus: UP
✓ redis: Collecting metrics
```

## 🔧 Technical Details

**Data Sources:**
- **Prometheus** at http://localhost:9090 (default datasource)
- **Loki** at http://localhost:3100 (for logs)

**Prometheus Scraping:**
- Backend API: http://172.31.3.138:3000/metrics
- Node Exporter: http://172.31.3.138:9100/metrics
- Redis Exporter: http://172.31.3.138:9121/metrics

**Installation Type:**
- Prometheus: Native binary + systemd
- Grafana: Native binary + systemd
- Loki/Promtail: Docker containers
- Node Exporter: Native binary + systemd (app EC2)

## 🎨 Professional Features

### Application Dashboard
- **Real-time monitoring** of API requests
- **Error tracking** with status code breakdown
- **Performance metrics** (latency percentiles)
- **Redis health** monitoring
- **Professional color schemes** and thresholds

### System Dashboard
- **Resource utilization** gauges
- **Threshold indicators** (green/yellow/red)
- **Historical trends** for capacity planning
- **Network and disk I/O** tracking
- **Production-grade** layout and organization

## 🎯 What You Can Monitor

### Application Metrics
- Is my backend healthy?
- What's my current request rate?
- Which endpoints are getting the most traffic?
- What's my error rate?
- How fast are my API responses?
- Is Redis healthy and responding?
- How much memory is Redis using?

### System Metrics
- Is my server overloaded?
- Am I running out of memory?
- Is disk space getting full?
- Are there network bottlenecks?
- What's the CPU breakdown?
- System load trends

## 📝 Notes

- Dashboards auto-refresh every 10 seconds
- All metrics are stored for 15 days in Prometheus
- You can create alerts based on any metric
- Export dashboards as JSON for backup
- Share dashboard links with your team

---

**Need help?** Check the Grafana documentation at https://grafana.com/docs/
