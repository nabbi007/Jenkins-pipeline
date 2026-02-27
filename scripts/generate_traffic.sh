#!/bin/bash
# Generate traffic to the voting app to populate metrics

APP_URL="${1:-http://54.78.54.132}"
DURATION="${2:-60}"  # seconds

echo "Generating traffic to $APP_URL for $DURATION seconds..."
echo "Press Ctrl+C to stop early"
echo ""

END_TIME=$(($(date +%s) + DURATION))
COUNT=0

while [ $(date +%s) -lt $END_TIME ]; do
  # Health check
  curl -s "$APP_URL:3000/api/health" > /dev/null
  
  # Get current poll
  curl -s "$APP_URL:3000/api/poll" > /dev/null
  
  # Cast some votes (options must match VOTING_OPTIONS in backend/src/app.js)
  CANDIDATE=$((RANDOM % 3))
  if [ $CANDIDATE -eq 0 ]; then
    CANDIDATE_NAME="Engineering"
  elif [ $CANDIDATE -eq 1 ]; then
    CANDIDATE_NAME="Product"
  else
    CANDIDATE_NAME="Design"
  fi
  
  curl -s -X POST "$APP_URL:3000/api/vote" \
    -H "Content-Type: application/json" \
    -d "{\"option\":\"$CANDIDATE_NAME\"}" > /dev/null
  
  # Get results
  curl -s "$APP_URL:3000/api/results" > /dev/null
  
  # Get metrics
  curl -s "$APP_URL:3000/metrics" > /dev/null
  
  COUNT=$((COUNT + 1))
  echo -ne "Requests sent: $COUNT\r"
  
  sleep 0.5
done

echo ""
echo "Traffic generation complete!"
echo "Total requests: $((COUNT * 5)) (health, poll, vote, results, metrics)"
echo ""
echo "Now go to Prometheus and run these queries:"
echo "  - rate(http_requests_total[1m])"
echo "  - http_requests_total"
echo "  - histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1m]))"
