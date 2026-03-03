# Project 6 - Dashboard Insights Report

**Project:** CI/CD Voting App with Observability  
**Date:** March 3, 2026

## 1. Purpose

This report summarizes operational insights from three Grafana dashboards:

- Backend Dashboard
- System Dashboard
- Redis Dashboard

The goal is to show what the data says about application health, infrastructure stability, and caching behavior, then highlight practical improvements for reliability.

## 2. Dashboard Evidence

### 2.1 Backend Dashboard

![Backend Dashboard](../screenshots/backend-dashboard.png)

**What this dashboard shows**

- Request volume and request trend over time
- Backend response latency behavior
- Error activity and spikes in failed requests
- API health at the service layer

**Insights from backend metrics**

- The service appears reachable and actively serving traffic.
- Latency patterns are generally stable, with short periods of higher response time under heavier request bursts.
- Error activity is not constant; it tends to appear in bursts, which usually points to temporary load, dependency delays, or specific failing routes.
- Tracking request rate together with latency and errors gives a reliable early signal for user-impacting incidents.

### 2.2 System Dashboard

![System Dashboard](../screenshots/system-dashboard.png)

**What this dashboard shows**

- CPU usage and load behavior
- Memory consumption and pressure
- Disk and network activity
- Host-level capacity indicators

**Insights from system metrics**

- Host resource utilization is sufficient for normal traffic in the current setup.
- CPU and memory usage are active but not saturated, indicating available headroom.
- Short utilization peaks are visible and align with periods where application metrics become less stable.
- System-level visibility helps confirm whether performance issues are application-related or resource-related.

### 2.3 Redis Dashboard

![Redis Dashboard](../screenshots/redis-dashboard.png)

**What this dashboard shows**

- Redis memory usage and keyspace behavior
- Command throughput and operation rate
- Cache hit/miss patterns
- Redis availability and runtime health

**Insights from Redis metrics**

- Redis is functioning as an active dependency in the request path.
- Memory usage appears controlled, suggesting no immediate memory-exhaustion risk.
- Cache behavior indicates useful offload from the backend, but misses still occur and should be monitored during load increases.
- If Redis throughput grows faster than cache efficiency, backend latency may rise; this makes Redis trend tracking important during releases.

## 3. Cross-Dashboard Summary

Viewing these dashboards together provides a complete troubleshooting flow:

1. Start with the backend dashboard to identify user-facing symptoms (latency or error increase).
2. Check the system dashboard to confirm whether host resource pressure is contributing.
3. Validate Redis dashboard behavior to see whether caching effectiveness changed at the same time.

This correlation approach improves root-cause speed and reduces guesswork during incidents.

## 4. Key Findings

- **Backend reliability is measurable and observable.** Request, latency, and error signals are available and useful for detecting degradation quickly.
- **Infrastructure is stable for current demand.** System metrics show normal utilization with temporary peaks rather than persistent saturation.
- **Redis contributes to performance stability.** Cache health appears good, and its telemetry helps explain backend changes during traffic shifts.

Overall, the monitoring stack is providing the expected operational visibility for day-to-day support and incident response.

## 5. Simple Improvement Plan

1. Set dashboard thresholds for key signals:
   - Error rate
   - p95 latency
   - CPU and memory saturation
2. Add alert routing for actionable notifications (email/Slack).
3. Review Redis hit/miss ratio weekly and tune cache TTL for high-traffic endpoints.
4. Capture dashboard screenshots after each release for change tracking.
5. Keep dashboard panels version-controlled with the project for repeatable environments.

## 6. Conclusion

The backend, system, and Redis dashboards together provide clear observability coverage across application, host, and cache layers.  
Current evidence indicates a stable platform with good monitoring foundations. With lightweight alerting and regular cache tuning, the system can improve response consistency and reduce production risk as traffic grows.
