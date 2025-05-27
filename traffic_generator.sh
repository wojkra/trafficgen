#!/bin/bash

# SAFE – strony typu news, tech, search
SAFE_URLS=(
  "https://www.google.com"
  "https://www.wikipedia.org"
  "https://www.ubuntu.com"
  "https://www.bbc.com"
  "https://www.stackoverflow.com"
)

# BLOCKED – social media, adult, streaming (do testu Web Filtera)
BLOCKED_URLS=(
  "https://www.facebook.com"
  "https://www.instagram.com"
  "https://www.netflix.com"
  "https://www.reddit.com"
  "https://www.tiktok.com"
  "https://www.pornhub.com"
)

# EICAR – test AV / SSL inspection
EICAR_URLS=(
  "http://www.eicar.org/download/eicar.com"
  "http://www.eicar.org/download/eicar.com.txt"
)

# DNS domains – test DNS filtering
DNS_DOMAINS=(
  "malware.testdomain.local"
  "facebook.com"
  "cnn.com"
  "doubleclick.net"
  "tiktok.com"
)

# Port testy – do symulacji usług TCP
TARGET_IP="192.168.1.100"  # <- ustaw swój IP serwera w labie
SERVICES=(
  "SSH:22"
  "FTP:21"
  "HTTP:80"
  "HTTPS:443"
  "DNS:53"
)

# Logowanie czasu rozpoczęcia
echo "=== Traffic Generator started at $(date) ==="

while true; do
  echo ""
  echo ">>> Visiting SAFE URLs..."
  for url in "${SAFE_URLS[@]}"; do
    echo "Visiting $url"
    curl --silent --insecure --output /dev/null "$url"
    sleep 2
  done

  echo ">>> Visiting BLOCKED URLs (simulate filtered categories)..."
  for url in "${BLOCKED_URLS[@]}"; do
    echo "Trying $url"
    curl --silent --insecure --output /dev/null "$url"
    sleep 2
  done

  echo ">>> Downloading EICAR files (simulate malware detection)..."
  for url in "${EICAR_URLS[@]}"; do
    curl --silent --output /dev/null "$url"
    echo "Downloaded (or attempted): $url"
    sleep 2
  done

  echo ">>> Performing DNS queries..."
  for domain in "${DNS_DOMAINS[@]}"; do
    dig "$domain" +short
    sleep 1
  done

  echo ">>> Testing services on $TARGET_IP"
  for service in "${SERVICES[@]}"; do
    name=$(echo $service | cut -d':' -f1)
    port=$(echo $service | cut -d':' -f2)
    nc -zv -w 2 $TARGET_IP $port 2>&1 | grep -v "Connection refused"
    sleep 1
  done

  echo ">>> Round finished at $(date)"
  echo "Sleeping 60 seconds..."
  sleep 60
done
