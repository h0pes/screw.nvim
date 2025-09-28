# Screw.nvim Collaboration Server Setup

This document provides step-by-step instructions for setting up the Screw.nvim collaboration server using HTTP-based architecture.

## Server Requirements

### Software Dependencies

1. **Python 3.8+**
   ```bash
   # Ubuntu/Debian
   sudo apt update && sudo apt install python3 python3-pip
   
   # Arch Linux
   sudo pacman -S python python-pip
   ```

2. **UV (Ultra-fast Python package manager)**
   ```bash
   # Install uv (recommended method)
   curl -LsSf https://astral.sh/uv/install.sh | sh
   
   # Or via pip
   pip install uv
   
   # Or via homebrew (macOS)
   brew install uv
   ```

3. **PostgreSQL**
   ```bash
   # Ubuntu/Debian
   sudo apt install postgresql postgresql-contrib
   
   # Arch Linux
   sudo pacman -S postgresql
   sudo systemctl enable postgresql
   sudo systemctl start postgresql
   ```

4. **curl** (for testing)
   ```bash
   # Usually pre-installed, but if needed:
   # Ubuntu/Debian: sudo apt install curl
   # Arch Linux: sudo pacman -S curl
   ```

### Database Setup

1. **Configure PostgreSQL user and database:**
   ```bash
   sudo -u postgres psql
   ```

2. **In PostgreSQL shell:**
   ```sql
   CREATE USER screw_user WITH PASSWORD 'YOUR_SECURE_PASSWORD';
   CREATE DATABASE screw_notes OWNER screw_user;
   GRANT ALL PRIVILEGES ON DATABASE screw_notes TO screw_user;
   \q
   ```

3. **Test connection:**
   ```bash
   psql -h localhost -U screw_user -d screw_notes
   # Enter password: YOUR_SECURE_PASSWORD
   ```

## Server Deployment

### Automatic Deployment (Recommended)

1. **Make deployment script executable:**
   ```bash
   chmod +x deploy_server.sh
   ```

2. **Run deployment:**
   ```bash
   ./deploy_server.sh
   ```

### Manual Deployment

1. **Copy files to server:**
   ```bash
   scp screw_server.py requirements.txt YOUR_USERNAME@YOUR_SERVER_IP:/home/YOUR_USERNAME/screw-server/
   ```

2. **SSH to server and setup:**
   ```bash
   ssh YOUR_USERNAME@YOUR_SERVER_IP
   cd /home/YOUR_USERNAME/screw-server
   
   # Create virtual environment with uv
   uv venv
   
   # Install dependencies
   uv pip install -r requirements.txt
   ```

3. **Start server manually (for testing):**
   ```bash
   source .venv/bin/activate
   python screw_server.py
   ```

4. **Setup as systemd service:**
   ```bash
   sudo cp screw-server.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable screw-server
   sudo systemctl start screw-server
   ```

## Client Configuration

### Environment Variables

Set these environment variables on each client machine:

```bash
# For bash/zsh users (.bashrc or .zshrc)
export SCREW_API_URL=http://YOUR_SERVER_IP:3000/api
export SCREW_USER_EMAIL=your_email@example.com

# For fish shell users (config.fish)
set -gx SCREW_API_URL http://YOUR_SERVER_IP:3000/api
set -gx SCREW_USER_EMAIL your_email@example.com
```

### Neovim Plugin Configuration

Update your screw.nvim configuration:

```lua
-- ~/.config/MyNvim/lua/marco/plugins/screw.lua
return {
  dir = "/home/marco/Programming/Lua/screw.nvim",
  name = "screw.nvim",
  cmd = "Screw",
  opts = {
    collaboration = {
      enabled = true,           -- Enable collaboration mode
      sync_interval = 3000,     -- Sync every 3 seconds  
      connection_timeout = 15000, -- 15 second timeout
      max_retries = 3,          -- Connection retry attempts
    }
  }
}
```

## Testing the Setup

### 1. Test Server Health

```bash
curl http://YOUR_SERVER_IP:3000/api/health
# Expected: {"status":"ok","server":"screw-production","timestamp":"..."}
```

### 2. Test Database Connection

```bash
curl -X POST http://YOUR_SERVER_IP:3000/api/notes \
  -H "Content-Type: application/json" \
  -d '{
    "file_path": "test.lua",
    "line_number": 1,
    "author": "test_user",
    "comment": "Test note",
    "state": "todo",
    "project_name": "test_project",
    "user_id": "test@example.com"
  }'
```

### 3. Test Note Retrieval

```bash
curl http://YOUR_SERVER_IP:3000/api/notes/test_project
```

### 4. Test in Neovim

1. Open Neovim with the plugin configured
2. Open a code file
3. Create a note using `:Screw note`
4. Check that the note appears in the database

## Troubleshooting

### Common Issues

1. **Connection refused:**
   - Check if server is running: `sudo systemctl status screw-server`
   - Check firewall settings
   - Verify port 3000 is open

2. **Database connection failed:**
   - Verify PostgreSQL is running: `sudo systemctl status postgresql`
   - Test database connection manually
   - Check DATABASE_URL environment variable

3. **Permission denied:**
   - Check file permissions in server directory
   - Verify systemd service user/group settings

### Log Locations

- **Server logs:** `sudo journalctl -u screw-server -f`
- **PostgreSQL logs:** `sudo journalctl -u postgresql -f`
- **Neovim plugin logs:** Check `:messages` in Neovim

### Performance Tips

1. **UV Benefits:**
   - Up to 10-100x faster package installation
   - Better dependency resolution
   - Smaller virtual environments

2. **Database Optimization:**
   - Indexes are automatically created for common queries
   - Consider connection pooling for high-traffic scenarios

3. **Network Optimization:**
   - Use HTTP/2 if available
   - Consider setting up reverse proxy (nginx) for production

## Security Considerations

### Production Deployment

1. **Change default passwords:**
   ```sql
   ALTER USER screw_user WITH PASSWORD 'your_secure_password_here';
   ```

2. **Configure PostgreSQL authentication:**
   - Edit `/etc/postgresql/*/main/pg_hba.conf`
   - Use md5 or scram-sha-256 authentication

3. **Setup HTTPS:**
   - Use reverse proxy (nginx/caddy) with SSL certificates
   - Update SCREW_API_URL to use https://

4. **Firewall configuration:**
   ```bash
   # Allow only specific IPs or networks
   sudo ufw allow from 10.0.0.0/24 to any port 3000
   sudo ufw allow from your_trusted_ips to any port 3000
   ```

## Monitoring

### Health Checks

Add to your monitoring system:

```bash
# Health check endpoint
curl -f http://YOUR_SERVER_IP:3000/api/health || exit 1

# Database connectivity
curl -f http://YOUR_SERVER_IP:3000/api/stats/test_project || exit 1
```

### Metrics

The server provides basic metrics through the `/api/stats/{project}` endpoint. Consider integrating with:

- Prometheus + Grafana
- DataDog
- New Relic

## Backup Strategy

### Database Backup

```bash
# Daily backup script
pg_dump -h localhost -U screw_user screw_notes > backup_$(date +%Y%m%d).sql

# Restore from backup
psql -h localhost -U screw_user screw_notes < backup_20240726.sql
```

### Automated Backups

Add to crontab:

```bash
# Daily backup at 2 AM
0 2 * * * pg_dump -h localhost -U screw_user screw_notes > /home/YOUR_USERNAME/backups/screw_$(date +\%Y\%m\%d).sql
```

## API Documentation

Once the server is running, visit:
- Interactive API docs: http://YOUR_SERVER_IP:3000/docs
- OpenAPI schema: http://YOUR_SERVER_IP:3000/openapi.json

This provides complete API documentation with examples and testing interface.