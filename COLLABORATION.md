# HTTP-based Collaboration Guide for screw.nvim

This comprehensive guide covers setting up and using screw.nvim's HTTP-based collaboration features for multi-user security code review workflows.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Server Setup](#server-setup)
- [Client Configuration](#client-configuration)
- [Environment Configuration](#environment-configuration)
- [Real-time Synchronization](#real-time-synchronization)
- [Offline Mode & Error Handling](#offline-mode--error-handling)
- [User Commands](#user-commands)  
- [API Reference](#api-reference)
- [Security Considerations](#security-considerations)
- [Performance & Optimization](#performance--optimization)
- [Troubleshooting](#troubleshooting)
- [Team Workflows](#team-workflows)

## Overview

The HTTP-based collaboration feature transforms screw.nvim from a single-user tool into a powerful multi-user platform for collaborative security code reviews. Multiple analysts can work simultaneously on the same codebase, sharing notes, findings, and discussions in real-time through a centralized HTTP API server.

### Key Benefits

- **Zero Dependencies**: No need for LuaJIT-compatible PostgreSQL drivers in clients
- **Simple Deployment**: Single Python server with standard dependencies
- **Network Friendly**: Works across different networks and environments  
- **Easy Scaling**: Standard HTTP load balancing and caching strategies apply
- **Technology Agnostic**: Any HTTP client can interact with the API

### Use Cases

- **Team Security Reviews**: Multiple analysts reviewing the same codebase
- **Knowledge Sharing**: Collaborative discussions about vulnerabilities
- **Audit Workflows**: Distributed review with centralized reporting
- **Training & Mentoring**: Senior analysts guiding junior team members
- **Compliance Reviews**: Multi-reviewer validation for critical systems

## Architecture

### System Components

```
┌─────────────────┐    HTTP/JSON     ┌──────────────────┐    PostgreSQL    ┌─────────────────┐
│   screw.nvim    │◄────────────────►│  FastAPI Server │◄─────────────────►│   PostgreSQL    │
│   (Client 1)    │                  │   (Python 3.8+) │                   │    Database     │
└─────────────────┘                  │                  │                   └─────────────────┘
┌─────────────────┐    REST API      │  - Notes CRUD    │
│   screw.nvim    │◄────────────────►│  - Reply system  │
│   (Client 2)    │                  │  - Real-time     │
└─────────────────┘                  │    sync          │
┌─────────────────┐                  │  - Project mgmt  │
│   screw.nvim    │◄────────────────►│                  │
│   (Client N)    │                  └──────────────────┘
└─────────────────┘
```

### Data Flow

1. **Client Operations**: Users create/edit notes in Neovim
2. **HTTP Requests**: Client sends JSON requests to FastAPI server  
3. **Database Operations**: Server performs CRUD operations on PostgreSQL
4. **Response Handling**: Server returns JSON responses to clients
5. **Cache Synchronization**: Clients update local caches with server responses

### Storage Architecture

**Client Side (HTTP Backend):**
- Local cache for performance and offline support
- HTTP client using system `curl` command
- Automatic retry logic with exponential backoff
- Path normalization for cross-platform compatibility

**Server Side (FastAPI):**
- RESTful API endpoints for all operations
- PostgreSQL database with optimized schema
- Request validation using Pydantic models
- Comprehensive logging and error handling

**Database Schema:**
- **projects**: Project metadata and organization
- **notes**: Security notes with full metadata (CWE, severity, etc.)
- **replies**: Threaded discussion system
- **Indexes**: Optimized for common query patterns

## Prerequisites

### Server Requirements

**Software Dependencies:**
- Python 3.8+
- PostgreSQL 12+
- UV (Ultra-fast Python package manager) - recommended

**Hardware Requirements:**
- 2GB RAM minimum (4GB recommended)
- 10GB disk space for database
- Network connectivity for HTTP API

### Client Requirements

**Software Dependencies:**
- Neovim 0.9.0+
- `curl` command (usually pre-installed)
- Internet connectivity to collaboration server

**No Additional Dependencies:**
- No PostgreSQL drivers needed on clients
- No Lua database libraries required
- Works on any platform with curl

## Server Setup

### Automatic Setup

Use the provided setup script for automatic deployment:

```bash
# Run the complete setup script
sudo -u postgres psql -f scripts/setup_postgresql.sql

# Deploy server using the deployment script  
./deploy_server.sh
```

### Manual Setup

**1. PostgreSQL Database Setup:**

```bash
# Install PostgreSQL
sudo apt update && sudo apt install postgresql postgresql-contrib

# Create database and user
sudo -u postgres psql
```

```sql
CREATE DATABASE screw_notes;
CREATE USER screw_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE screw_notes TO screw_user;
\q
```

**2. Run Database Schema Setup:**

```bash
sudo -u postgres psql -f scripts/setup_postgresql.sql
```

**3. Python Server Setup:**

```bash
# Install UV package manager
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create project directory
mkdir /opt/screw-server
cd /opt/screw-server

# Copy server files
cp screw_server.py requirements.txt /opt/screw-server/

# Install dependencies with UV
uv venv
uv pip install -r requirements.txt
```

**4. Environment Configuration:**

```bash
export DATABASE_URL="postgresql://screw_user:password@localhost:5432/screw_notes"  
export SCREW_HOST="0.0.0.0"
export SCREW_PORT="3000"
```

**5. Start Server:**

```bash
# For testing
source .venv/bin/activate
python screw_server.py

# For production (systemd service)
sudo cp screw-server.service /etc/systemd/system/
sudo systemctl enable screw-server
sudo systemctl start screw-server
```

### Server Configuration

**Environment Variables:**

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `DATABASE_URL` | PostgreSQL connection string | Required | `postgresql://user:pass@host:5432/db` |
| `SCREW_HOST` | Server bind address | `127.0.0.1` | `0.0.0.0` |  
| `SCREW_PORT` | Server port | `3000` | `8080` |
| `SCREW_DEBUG` | Enable debug logging | `false` | `true` |

**FastAPI Configuration:**

The server automatically configures:
- JSON request/response handling
- Request validation with Pydantic
- Error handling and logging
- CORS headers for cross-origin requests
- Health check endpoints

## Client Configuration

### Environment Variables

Each client machine needs these environment variables:

```bash
# Required: API server URL
export SCREW_API_URL="http://your-server:3000/api"

# Required: User identification  
export SCREW_USER_EMAIL="analyst@company.com"
# OR
export SCREW_USER_ID="john.doe"
```

### Shell Configuration

**Bash/Zsh (~/.bashrc or ~/.zshrc):**
```bash
export SCREW_API_URL="http://your-server-ip:3000/api"
export SCREW_USER_EMAIL="your.name@company.com"
```

**Fish Shell (~/.config/fish/config.fish):**
```fish
set -gx SCREW_API_URL http://your-server-ip:3000/api
set -gx SCREW_USER_EMAIL your.name@company.com
```

### Neovim Plugin Configuration

Update your screw.nvim configuration to enable collaboration:

```lua
require('screw').setup({
  storage = {
    backend = "http",  -- Use HTTP backend
  },
  collaboration = {
    enabled = true,           -- Enable collaboration mode
    connection_timeout = 10000, -- 10 second timeout
    max_retries = 3,          -- Connection retry attempts
  }
})
```

### Verification

Test your configuration:

```vim
" Check environment variables
:lua print("API URL:", os.getenv('SCREW_API_URL'))
:lua print("User ID:", os.getenv('SCREW_USER_EMAIL'))

" Test connection  
:checkhealth screw

" Test note creation
:Screw note add
```

## Environment Configuration

### Project-specific Configuration

Create a `.env` file in your project root:

```bash
# .env file for project-specific settings
SCREW_API_URL=http://your-collaboration-server:3000/api
SCREW_USER_EMAIL=analyst@yourcompany.com
```

Load environment variables:
```bash
# Load .env file
set -a; source .env; set +a

# Start Neovim
nvim
```

### Team Environment Setup

**For Development Teams:**
```bash
# Central configuration script
cat > team-setup.sh << 'EOF'
#!/bin/bash
export SCREW_API_URL="http://dev-server:3000/api"
export SCREW_USER_EMAIL="$USER@company.com"
echo "Screw.nvim collaboration configured for $SCREW_USER_EMAIL"
EOF

chmod +x team-setup.sh
source team-setup.sh
```

**For Docker Environments:**
```dockerfile
FROM neovim-base:latest
ENV SCREW_API_URL=http://collab-server:3000/api
ENV SCREW_USER_EMAIL=analyst@company.com
```

### Environment Validation

```bash
# Test environment setup
curl -s "$SCREW_API_URL/health" | jq .

# Test authentication
curl -X POST "$SCREW_API_URL/notes" \
  -H "Content-Type: application/json" \
  -d '{"file_path": "test.txt", "line_number": 1, "author": "test", "comment": "test", "state": "todo", "project_name": "test", "user_id": "test@example.com"}'
```

## Real-time Synchronization  

### How It Works

The HTTP collaboration system provides near real-time synchronization through:

1. **Immediate Updates**: Every note operation immediately syncs to server
2. **Cache Refresh**: After operations, clients refresh local caches  
3. **Visual Feedback**: Sign column updates reflect remote changes
4. **User Notifications**: Inform users of remote changes

### Synchronization Flow

```
User creates note → HTTP POST → Server saves → Database insert
                                      ↓
Other clients → Periodic refresh → HTTP GET → Updated cache → Sign refresh
```

### Configuration

```lua
require('screw').setup({
  collaboration = {
    sync_interval = 5000,      -- Refresh interval in milliseconds  
    connection_timeout = 10000, -- Request timeout
    max_retries = 3,           -- Retry attempts for failed requests
  }
})
```

### Manual Synchronization

```vim
" Force immediate sync
:Screw sync

" Check collaboration status  
:Screw status

" Show detailed connection info
:lua require('screw').show_collaboration_info()
```

## Offline Mode & Error Handling

### Automatic Offline Mode

The HTTP backend automatically handles connectivity issues:

**Triggers for Offline Mode:**
- Server unavailable (connection refused)
- Network connectivity issues  
- Request timeouts
- HTTP error responses (500, etc.)

**Offline Behavior:**
- All operations continue to work locally
- Changes stored in local cache
- User notified of offline status
- Automatic reconnection attempts

### Recovery Process

1. **Detection**: Failed HTTP request triggers offline mode
2. **Notification**: User informed via status messages  
3. **Local Storage**: Operations cached locally
4. **Retry Logic**: Exponential backoff reconnection attempts
5. **Sync**: When reconnected, local changes sync to server
6. **Resolution**: Conflicts resolved using timestamp precedence

### Offline Commands

```vim
" Check offline status
:lua local status = require('screw').get_collaboration_status()
:lua print("Connected:", status.connected)

" Force reconnection  
:Screw reconnect

" View local cache status
:lua local storage = require('screw.notes.storage')
:lua print(vim.inspect(storage.get_storage_stats()))
```

### Error Recovery

**Network Errors:**
- Automatic retry with exponential backoff
- Fallback to local storage for all operations
- Visual indicators in status displays

**Server Errors:**  
- HTTP 5xx errors trigger offline mode
- Request validation errors shown to user
- Malformed data errors logged and skipped

**Client Errors:**
- HTTP 4xx errors show user-friendly messages
- Invalid authentication handled gracefully  
- Request timeout recovery with retries

## User Commands

### Core Collaboration Commands

**Connection Management:**
```vim
:Screw status                     " Show collaboration status
:Screw reconnect                  " Force server reconnection  
:Screw sync                       " Force manual synchronization
```

**Note Operations:**
```vim
:Screw note add                   " Create new note (syncs to server)
:Screw note edit                  " Edit note (syncs to server)  
:Screw note delete                " Delete note (syncs to server)
:Screw note reply                 " Add reply (syncs to server)
:Screw note view                  " View notes (refreshes from server)
```

**Project Management:**
```vim
:Screw export markdown            " Export notes to Markdown
:Screw export sarif               " Export to SARIF format
:Screw import semgrep             " Import from Semgrep output
:Screw import bandit              " Import from Bandit output
```

### Administrative Commands

**Health Checks:**
```vim
:checkhealth screw                " Run comprehensive health check
:Screw debug                      " Show debug information
```

**Cache Management:**
```vim
:lua require('screw.notes.storage').get_backend():load_notes()  " Refresh cache
:lua require('screw.notes.storage').get_storage_stats()         " Show cache stats
```

## API Reference

### REST API Endpoints

The FastAPI server provides these endpoints:

**Health Check:**
```
GET /api/health
Response: {"status": "ok", "server": "screw-production", "timestamp": "..."}
```

**Notes Management:**
```
GET    /api/notes/{project_name}           # Get all notes for project
POST   /api/notes                          # Create new note
PUT    /api/notes/{note_id}                # Update existing note  
DELETE /api/notes/{note_id}                # Delete note
GET    /api/notes/note/{note_id}           # Get specific note
```

**Replies Management:**
```
POST   /api/notes/{note_id}/replies        # Add reply to note
GET    /api/notes/{note_id}/replies        # Get replies for note
```

**Project Management:**
```
GET    /api/stats/{project_name}           # Get project statistics
DELETE /api/notes/{project_name}           # Clear all project notes
```

### Client API (Lua)

**Storage Backend:**
```lua
local storage = require('screw.notes.storage')
local backend = storage.get_backend()

-- Connection management
local success, error = backend:connect()
backend:disconnect()
local connected = backend:is_connected()

-- Note operations
local notes = backend:get_all_notes()
local success = backend:save_note(note)
local success = backend:delete_note(note_id)

-- Reply operations  
local success = backend:add_reply(parent_id, reply)
```

**HTTP-specific Methods:**
```lua
local http_backend = require('screw.notes.storage.http')

-- Force reconnection
local success = http_backend:force_reconnect()

-- Get storage statistics
local stats = http_backend:get_storage_stats()
-- Returns: {backend_type, connected, api_url, user_id, total_notes, ...}
```

### Request/Response Format

**Note Creation Request:**
```json
{
  "file_path": "src/main.c",
  "line_number": 42,
  "author": "analyst@company.com", 
  "comment": "Potential buffer overflow",
  "description": "User input not validated",
  "cwe": "CWE-120",
  "state": "vulnerable",
  "severity": "high",
  "project_name": "my-project",
  "user_id": "analyst@company.com"
}
```

**Note Creation Response:**
```json
{
  "note": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "file_path": "src/main.c",
    "line_number": 42,
    "author": "analyst@company.com",
    "timestamp": "2024-01-15T10:30:00Z",
    "comment": "Potential buffer overflow",
    "description": "User input not validated", 
    "cwe": "CWE-120",
    "state": "vulnerable",
    "severity": "high",
    "created_at": "2024-01-15T10:30:00Z"
  }
}
```

## Security Considerations

### Network Security

**HTTPS Deployment:**
```nginx
server {
    listen 443 ssl;
    server_name screw-collab.company.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location /api/ {
        proxy_pass http://localhost:3000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Firewall Configuration:**
```bash
# Allow only specific network ranges to access collaboration server
sudo ufw allow from 10.0.0.0/24 to any port 3000
sudo ufw allow from 192.168.0.0/24 to any port 3000
```

### Authentication & Authorization

**User Identity:**
- Environment-based user identification
- No passwords stored in configuration  
- User email/ID tracking for audit trails

**API Security:**
- Input validation using Pydantic models
- SQL injection prevention through parameterized queries
- Request size limits and rate limiting (configurable)

**Database Security:**
```sql
-- Create restricted user for application
CREATE ROLE screw_app WITH LOGIN PASSWORD 'secure_random_password';
GRANT CONNECT ON DATABASE screw_notes TO screw_app;
GRANT USAGE ON SCHEMA public TO screw_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO screw_app;
```

### Data Privacy

**Local Control:**
- All data remains on your infrastructure
- No external services or telemetry
- Complete control over data retention
- Configurable backup strategies

**Access Logging:**
```python
# Server automatically logs all API requests
# Configure logging level in screw_server.py
logging.basicConfig(level=logging.INFO)
```

### Best Practices

**Environment Security:**
```bash
# Restrict access to environment files
chmod 600 ~/.bashrc
chmod 600 .env

# Use environment management tools
export SCREW_API_URL="$(vault kv get -field=api_url secret/screw)"
```

**Database Hardening:**
```sql
-- Revoke public access
REVOKE ALL ON DATABASE screw_notes FROM PUBLIC;

-- Network restrictions in pg_hba.conf
host screw_notes screw_user 10.0.0.0/8 md5
```

## Performance & Optimization

### Server Performance

**Database Optimization:**
```sql
-- The setup script automatically creates these indexes
CREATE INDEX idx_notes_project_file ON notes(project_id, file_path);
CREATE INDEX idx_notes_project_file_line ON notes(project_id, file_path, line_number);
CREATE INDEX idx_replies_parent ON replies(parent_id);

-- Monitor performance
EXPLAIN ANALYZE SELECT * FROM notes WHERE project_id = 1;
```

**Connection Optimization:**
```python
# Configure database connection pooling
# In screw_server.py, psycopg automatically handles connection pooling
```

### Client Performance

**Cache Management:**
- Local cache reduces API calls
- Intelligent cache invalidation
- Memory-efficient storage

**Request Optimization:**
```lua
-- Configure timeouts for responsiveness
require('screw').setup({
  collaboration = {
    connection_timeout = 5000,    -- 5 second timeout
    max_retries = 3,              -- Quick failure detection  
  }
})
```

### Network Optimization

**Payload Efficiency:**
- Minimal JSON payloads
- Efficient serialization
- Compressed responses (HTTP gzip)

**Caching Strategies:**
```nginx
# Nginx reverse proxy with caching
location /api/notes/ {
    proxy_cache notes_cache;
    proxy_cache_valid 200 1m;
    proxy_pass http://localhost:3000;
}
```

## Troubleshooting

### Common Issues

**Connection Problems:**

*Issue:* "Failed to connect to collaboration server"
```bash
# Test server connectivity
curl -s http://your-server:3000/api/health

# Check server status
sudo systemctl status screw-server
sudo journalctl -u screw-server -f
```

*Issue:* "Request timeout"
```lua
-- Increase timeout
require('screw').setup({
  collaboration = {
    connection_timeout = 15000,  -- 15 seconds
  }
})
```

**Environment Issues:**

*Issue:* "SCREW_API_URL environment variable not set"
```bash
# Verify environment
echo $SCREW_API_URL
echo $SCREW_USER_EMAIL

# Test in Neovim
:lua print(os.getenv('SCREW_API_URL'))
```

*Issue:* "Invalid API response"
```bash
# Test API manually
curl -X GET "$SCREW_API_URL/health" -v
```

**Server Issues:**

*Issue:* "Database connection failed"
```bash
# Test database connectivity  
psql "$DATABASE_URL" -c "SELECT 1"

# Check PostgreSQL status
sudo systemctl status postgresql
```

*Issue:* "Server won't start"
```bash
# Check server logs
sudo journalctl -u screw-server -f

# Test manual startup
cd /opt/screw-server
source .venv/bin/activate
python screw_server.py
```

### Diagnostic Commands

**Health Check:**
```vim
:checkhealth screw
```

**Connection Status:**
```vim
:Screw status
:lua local status = require('screw').get_collaboration_status()
:lua print(vim.inspect(status))
```

**API Testing:**
```bash
# Test all endpoints
curl -s "$SCREW_API_URL/health"
curl -s "$SCREW_API_URL/notes/test-project"  
curl -X POST "$SCREW_API_URL/notes" -H "Content-Type: application/json" -d '{"file_path":"test.txt","line_number":1,"author":"test","comment":"test","state":"todo","project_name":"test","user_id":"test@example.com"}'
```

### Performance Debugging

**Slow Requests:**
```bash
# Monitor server response times
curl -w "@curl-format.txt" -s -o /dev/null "$SCREW_API_URL/health"

# curl-format.txt:
#     time_namelookup:  %{time_namelookup}\n
#        time_connect:  %{time_connect}\n
#     time_appconnect:  %{time_appconnect}\n
#    time_pretransfer:  %{time_pretransfer}\n
#       time_redirect:  %{time_redirect}\n
#  time_starttransfer:  %{time_starttransfer}\n
#                     ----------\n
#          time_total:  %{time_total}\n
```

**Memory Issues:**
```lua
-- Check cache memory usage
local stats = require('screw.notes.storage').get_storage_stats()
print("Cached notes:", stats.notes_count)
print("Memory usage:", collectgarbage("count"), "KB")
```

## Team Workflows

### Setup Workflow for Teams

**1. Infrastructure Setup (Admin):**

```bash
# Deploy server infrastructure
git clone https://github.com/your-org/screw-server-config
cd screw-server-config

# Run automated deployment
./deploy-production.sh

# Verify deployment
curl -s http://your-server:3000/api/health
```

**2. Team Member Setup:**

```bash
# Each team member configures environment
echo 'export SCREW_API_URL="http://your-server:3000/api"' >> ~/.bashrc
echo 'export SCREW_USER_EMAIL="'$USER'@company.com"' >> ~/.bashrc
source ~/.bashrc

# Test configuration
nvim
:checkhealth screw
```

**3. Project Initialization:**

```bash
# First team member in project
cd /path/to/security-review-project
nvim
:Screw note add  # Plugin auto-detects and enables collaboration
```

### Collaborative Review Process

**Phase 1: Initial Triage (Lead Analyst)**
```vim
# Review code and create initial findings
:Screw note add
# State: todo
# Comment: "Review for input validation issues"

:Screw note add  
# State: vulnerable
# Severity: high
# CWE: CWE-89
# Comment: "SQL injection in login function"
```

**Phase 2: Team Review (Multiple Analysts)**
```vim
# Team members join and contribute
:Screw note view project      # See all findings
:Screw note reply             # Discuss findings
:Screw note add               # Add new discoveries
```

**Phase 3: Validation & Documentation**
```vim  
# Validate and finalize findings
:Screw note edit              # Update severity/descriptions
:Screw export sarif report.sarif    # Generate final report
```

### Best Practices for Teams

**Workflow Coordination:**
- Establish CWE classification standards
- Define severity criteria consistently
- Use descriptive note comments
- Regular team sync meetings

**Quality Assurance:**
- Peer review of high-severity findings
- Consistent false positive validation
- Documentation review processes
- Regular security knowledge sharing

**Tool Integration:**
```bash
# Integrate with CI/CD pipelines
./security-review.sh
nvim src/
# ... security review process
:Screw export sarif security-findings.sarif

# Upload results to security dashboard
curl -X POST https://security-dashboard/api/upload \
  -F "report=@security-findings.sarif"
```

---

## Summary

The HTTP-based collaboration system provides a robust, scalable solution for team-based security code reviews. With zero client dependencies, simple deployment, and comprehensive offline support, teams can seamlessly collaborate while maintaining the familiar screw.nvim experience.

The architecture eliminates the complexity of direct database connections while providing enterprise-grade features including real-time synchronization, comprehensive API access, and flexible deployment options.

For additional support or advanced configuration scenarios, refer to the plugin's health check system (:checkhealth screw), server logs, and the troubleshooting sections above.