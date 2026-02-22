# Enhanced Application Metrics Guide

## 📊 Current vs. Enhanced Metrics

### ✅ What You Currently Have (Working Now):

**Basic HTTP Metrics:**
- `http_requests_total` - Total HTTP requests by method, route, status_code
- `http_request_duration_seconds` - Request latency histogram
- `http_errors_total` - Total 4xx and 5xx errors
- Default Node.js metrics (CPU, memory, GC, etc.)

**Working Dashboards:**
- Application & Redis Metrics dashboard
- System Metrics dashboard
- Basic request rate, error rate visualizations

### ⭐ NEW Enhanced Metrics (Added to Code - Requires Redeploy):

## Business Metrics

### 1. **Vote Tracking**
```promql
votes_total{option="Engineering"}      # Total votes cast for each option (counter)
votes_total{option="Product"}
votes_total{option="Design"}

votes_current{option="Engineering"}    # Current vote count (gauge, real-time)
votes_total_count                       # Total of all votes (gauge)
```

**Use Cases:**
- Track which option is winning in real-time
- Monitor voting trends over time  
- Set alerts on vote milestones
- Calculate vote distribution percentages

### 2. **User Engagement**
```promql
poll_views_total           # How many times poll was viewed
results_views_total        # How many times results were viewed
```

**Use Cases:**
- Track user engagement
- Measure conversion rate: votes / poll_views
- Identify if users are checking results
- Monitor traffic patterns

### 3. **Application Health**
```promql
redis_connection_status    # 1=connected, 0=disconnected
http_requests_in_progress{method="POST",route="/api/vote"}  # Active requests being processed
```

**Use Cases:**
- Alert when Redis goes down
- Monitor concurrent request load
- Identify bottlenecks
- Capacity planning

## HTTP Metrics (Improved)

### 4. **Better Latency Tracking**
The histogram buckets are now more granular:
```
Buckets: 1ms, 5ms, 10ms, 50ms, 100ms, 200ms, 500ms, 1s, 2s, 5s
```

**Queries:**
```promql
# 95th percentile latency (fixed query)
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# 50th percentile (median)
histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# 99th percentile
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
```

## Professional Dashboard Panels You Can Add

### Business KPIs Panel

**Total Votes (Big Number)**
```promql
votes_total_count
```

**Vote Distribution (Pie Chart)**
```promql
votes_current
```

**Voting Rate (Time Series)**
```promql
rate(votes_total[1m])
```

**Most Popular Option (Table)**
```promql
sort_desc(votes_current)
```

### Engagement Metrics Panel

**Poll Views vs Votes (Comparison)**
```promql
poll_views_total
sum(votes_total)
```

**Conversion Rate (Percentage)**
```promql
(sum(votes_total) / poll_views_total) * 100
```

**Results Page Traffic**
```promql
rate(results_views_total[5m])
```

### Health Monitoring Panel

**Redis Connection (Gauge)**
```promql
redis_connection_status
```

**Active Requests (Gauge)**
```promql
sum(http_requests_in_progress)
```

**Request Queue Depth**
```promql
sum(http_requests_in_progress) by (route)
```

## How to Deploy Enhanced Metrics

### Option 1: Manual Deployment
```bash
cd /home/lliasububakar/jenkins-project

# Build new backend image
cd backend
docker build -t voting-backend:latest .

# Deploy to app server
SSH_KEY="infra/terraform/jenkins-cicd-observability-ec2-27035621.pem"
APP_IP="54.78.54.132"

# Save and transfer image
docker save voting-backend:latest | gzip > /tmp/backend.tar.gz
scp -i "../$SSH_KEY" /tmp/backend.tar.gz ec2-user@$APP_IP:/tmp/

# On remote server
ssh -i "../$SSH_KEY" ec2-user@$APP_IP
docker load < /tmp/backend.tar.gz
docker stop backend && docker rm backend
docker run -d --name backend --network host \
  -e REDIS_URL=redis://localhost:6379 \
  --restart unless-stopped \
  voting-backend:latest
```

### Option 2: Use Script
```bash
cd /home/lliasububakar/jenkins-project
chmod +x scripts/redeploy_backend.sh
./scripts/redeploy_backend.sh
```

### Option 3: Trigger Jenkins Pipeline
```bash
# Push to git and let Jenkins rebuild/redeploy
git add backend/src/app.js
git commit -m "feat: add comprehensive business and operational metrics"
git push origin main
```

## Verify Enhanced Metrics

After redeployment, check the metrics endpoint:
```bash
curl http://54.78.54.132:3000/metrics | grep -E 'votes_|poll_|results_|redis_connection'
```

You should see:
```
# HELP votes_total Total number of votes cast
# TYPE votes_total counter
votes_total{option="Engineering"} 0
votes_total{option="Product"} 0
votes_total{option="Design"} 0

# HELP votes_current Current vote count per option
# TYPE votes_current gauge
votes_current{option="Engineering"} 0
votes_current{option="Product"} 0
votes_current{option="Design"} 0

# HELP votes_total_count Total number of all votes
# TYPE votes_total_count gauge
votes_total_count 0

# HELP redis_connection_status Redis connection status (1=connected, 0=disconnected)
# TYPE redis_connection_status gauge
redis_connection_status 1

# HELP poll_views_total Total number of times the poll was viewed
# TYPE poll_views_total counter
poll_views_total 0

# HELP results_views_total Total number of times results were viewed
# TYPE results_views_total counter
results_views_total 0

# HELP http_requests_in_progress Number of HTTP requests currently being processed
# TYPE http_requests_in_progress gauge
http_requests_in_progress{method="GET",route="/metrics"} 1
```

## Prometheus Queries for Dashboards

### Business Queries

**Current Winners:**
```promql
topk(1, votes_current)
```

**Vote Distribution Percentage:**
```promql
votes_current / votes_total_count * 100
```

**Votes in Last Hour:**
```promql
increase(votes_total[1h])
```

**Voting Velocity (votes/minute):**
```promql
rate(votes_total[1m]) * 60
```

### Operational Queries

**Backend Health Score (composite):**
```promql
(up{job="backend"} * redis_connection_status) == 1
```

**Average Active Requests:**
```promql
avg_over_time(sum(http_requests_in_progress)[5m:])
```

**Request Processing Rate:**
```promql
sum(rate(http_requests_total[1m]))
```

## Alert Rules You Can Add

```yaml
groups:
  - name: business_alerts
    rules:
      - alert: RedisDown
        expr: redis_connection_status == 0
        for: 1m
        annotations:
          summary: "Redis connection lost"
          
      - alert: HighConcurrentRequests
        expr: sum(http_requests_in_progress) > 50
        for: 2m
        annotations:
          summary: "High concurrent request load"
          
      - alert: LowVotingActivity
        expr: rate(votes_total[5m]) < 0.01
        for: 10m
        annotations:
          summary: "No votes in last 10 minutes"
```

## Recommended Dashboard Improvements

### 1. Add "Business KPIs" Row
- Total Votes (stat panel)
- Current Winner (stat panel with threshold)
- Vote Distribution (pie chart)
- Voting Rate over Time (time series)

### 2. Add "User Engagement" Row  
- Poll Views (time series)
- Results Views (time series)
- Conversion Rate: Votes/Views (gauge)

### 3. Enhance "Health" Row
- Add Redis Connection Status (gauge)
- Add Active Requests (gauge)
- Add Request Queue by Route (bar chart)

## Is This Enough?

### ✅ YES - You Now Have:

1. **HTTP Metrics** - Request rate, errors, latency
2. **Business Metrics** - Votes, engagement, conversion
3. **Health Metrics** - Redis status, active connections
4. **System Metrics** - CPU, memory, disk, network
5. **Redis Metrics** - Memory, clients, commands

### This is **Production-Grade** for a voting app!

### 💡 Optional Enhancements (If Needed):

- **User tracking:** Add `votes_by_ip` or `unique_voters`
- **Geographic data:** Track votes by region
- **Time-based:** Votes by hour/day patterns
- **A/B testing:** Track different poll versions
- **Performance:** Add database query time metrics

## Summary

**Current State:**
- ✅ Basic metrics working and visible in Grafana
- ✅ Dashboards showing request rate, error rate
- ⚠️ Latency showing 0 (will be fixed after redeploy)

**Enhanced State (After Redeploy):**
- ✅ All basic metrics
- ✅ Business/voting metrics  
- ✅ User engagement tracking
- ✅ Better histogram buckets for latency
- ✅ Redis health monitoring
- ✅ Active request tracking

**Next Steps:**
1. Redeploy backend using provided script or Jenkins
2. Verify new metrics in Prometheus
3. Optionally update dashboards with business panels
4. Set up alerts for critical metrics

Your metrics are **professional and comprehensive** for a voting application! 🎉
