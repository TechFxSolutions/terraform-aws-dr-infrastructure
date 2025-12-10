#!/bin/bash
# User Data Script for Web Tier Instances

set -e

# Update system
yum update -y

# Install Nginx
yum install -y nginx

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create simple health check endpoint
mkdir -p /usr/share/nginx/html
cat > /usr/share/nginx/html/health <<'EOF'
OK
EOF

# Create index page
cat > /usr/share/nginx/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>DR Infrastructure - ${environment}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 50px; }
        .container { max-width: 800px; margin: 0 auto; }
        .status { color: green; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>AWS Disaster Recovery Infrastructure</h1>
        <p>Environment: <span class="status">${environment}</span></p>
        <p>Region: <span class="status">${region}</span></p>
        <p>Status: <span class="status">OPERATIONAL</span></p>
        <p>Tier: Web</p>
    </div>
</body>
</html>
EOF

# Configure Nginx
cat > /etc/nginx/conf.d/app.conf <<'EOF'
server {
    listen 80;
    server_name _;

    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }

    # Proxy to application tier (if needed)
    # location /api {
    #     proxy_pass http://app-backend:8080;
    #     proxy_set_header Host $host;
    #     proxy_set_header X-Real-IP $remote_addr;
    # }
}
EOF

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'EOF'
{
  "metrics": {
    "namespace": "CustomApp/WebTier",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {"name": "cpu_usage_idle", "rename": "CPU_IDLE", "unit": "Percent"},
          {"name": "cpu_usage_iowait", "rename": "CPU_IOWAIT", "unit": "Percent"}
        ],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          {"name": "used_percent", "rename": "DISK_USED", "unit": "Percent"}
        ],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": [
          {"name": "mem_used_percent", "rename": "MEM_USED", "unit": "Percent"}
        ],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/aws/ec2/web/nginx-access",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/aws/ec2/web/nginx-error",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

echo "Web tier initialization complete"
