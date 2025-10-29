#!/bin/bash
yum update -y
yum install -y python3 python3-pip git

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Clone application code (replace with your actual repo)
cd /home/ec2-user
git clone https://github.com/your-username/todo-app.git
cd todo-app

# Create environment file
cat > .env << EOF
DATABASE_URL=mysql://admin:changeme123!@${db_endpoint}/${db_name}
FLASK_ENV=production
SECRET_KEY=$(openssl rand -hex 32)
EOF

# Create Docker Compose file
cat > docker-compose.yml << EOF
version: '3.8'
services:
  web:
    build: .
    ports:
      - "80:5000"
    environment:
      - DATABASE_URL=mysql://admin:changeme123!@${db_endpoint}/${db_name}
      - FLASK_ENV=production
      - SECRET_KEY=\${SECRET_KEY}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

# Create Dockerfile
cat > Dockerfile << EOF
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
EOF

# Create requirements.txt
cat > requirements.txt << EOF
Flask==2.3.3
Flask-SQLAlchemy==3.0.5
PyMySQL==1.1.0
gunicorn==21.2.0
python-dotenv==1.0.0
EOF

# Create simple Flask app
cat > app.py << EOF
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        'message': 'Hello from 3-Tier App!',
        'status': 'running',
        'database': '${db_endpoint}'
    })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# Build and start the application
docker-compose up -d

# Setup log rotation
cat > /etc/logrotate.d/docker-compose << EOF
/home/ec2-user/todo-app/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 ec2-user ec2-user
}
EOF