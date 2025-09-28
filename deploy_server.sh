#!/bin/bash
# Deployment script for Screw.nvim Collaboration Server using UV

set -e

echo "=== Screw.nvim Server Deployment ==="

# Configuration
SERVER_USER="YOUR_USERNAME"
SERVER_HOST="YOUR_SERVER_IP"
SERVER_DIR="/home/YOUR_USERNAME/screw-server"
DATABASE_URL="postgresql://screw_user:YOUR_SECURE_PASSWORD@localhost/screw_notes"

echo "Deploying to: $SERVER_USER@$SERVER_HOST:$SERVER_DIR"

# Copy files to server
echo "Copying server files..."
ssh $SERVER_USER@$SERVER_HOST "mkdir -p $SERVER_DIR"
scp screw_server.py requirements.txt $SERVER_USER@$SERVER_HOST:$SERVER_DIR/

# Install dependencies and start server
echo "Setting up server..."
ssh $SERVER_USER@$SERVER_HOST << EOF
cd $SERVER_DIR

# Install uv if not already installed
if ! command -v uv &> /dev/null; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="\$HOME/.cargo/bin:\$PATH"
fi

# Add uv to PATH for this session
export PATH="\$HOME/.cargo/bin:\$PATH"

# Create virtual environment and install dependencies using uv
echo "Creating virtual environment with uv..."
uv venv

# Install dependencies with uv (much faster than pip)
echo "Installing dependencies with uv..."
uv pip install -r requirements.txt

# Create systemd service
sudo tee /etc/systemd/system/screw-server.service > /dev/null << EOL
[Unit]
Description=Screw.nvim Collaboration Server
After=network.target

[Service]
Type=simple
User=$SERVER_USER
WorkingDirectory=$SERVER_DIR
Environment=PATH=$SERVER_DIR/.venv/bin:\$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin
Environment=DATABASE_URL=$DATABASE_URL
Environment=SCREW_HOST=0.0.0.0
Environment=SCREW_PORT=3000
ExecStart=$SERVER_DIR/.venv/bin/python screw_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and start service
sudo systemctl daemon-reload
sudo systemctl enable screw-server
sudo systemctl restart screw-server

echo "Server deployed and started!"
echo "Check status with: sudo systemctl status screw-server"
echo "View logs with: sudo journalctl -u screw-server -f"
EOF

echo "Deployment complete!"
echo ""
echo "Server should be accessible at: http://$SERVER_HOST:3000"
echo "Health check: curl http://$SERVER_HOST:3000/api/health"
echo ""
echo "Environment variables for screw.nvim:"
echo "  export SCREW_API_URL=http://$SERVER_HOST:3000/api"
echo "  export SCREW_USER_EMAIL=your_email@example.com"