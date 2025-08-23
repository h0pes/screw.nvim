-- Complete PostgreSQL setup script for screw.nvim collaboration
-- This script creates the database, tables, indexes, functions, and user permissions
-- 
-- Usage:
--   Run this script as PostgreSQL superuser:
--   sudo -u postgres psql -f setup_postgresql.sql
--
-- This script will:
-- 1. Drop and recreate the screw_notes database (clean slate)
-- 2. Create all required tables, indexes, and functions
-- 3. Create the screw_user role with proper permissions
-- 4. Verify the setup

\echo '=== screw.nvim PostgreSQL Complete Setup ==='
\echo 'This script will create the screw_notes database and user from scratch'
\echo ''

-- Terminate any existing connections and recreate database
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'screw_notes' AND pid != pg_backend_pid();
DROP DATABASE IF EXISTS screw_notes;
CREATE DATABASE screw_notes;

-- Connect to the new database
\c screw_notes

-- Set search path explicitly
SET search_path TO public;

\echo 'Setting up database schema and extensions...'

-- Enable required extensions  
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

\echo 'Creating tables...'

-- Projects table for multi-project support
CREATE TABLE public.projects (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    path VARCHAR(500) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(name, path)
);

-- Main notes table with all required fields
CREATE TABLE public.notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id INTEGER REFERENCES public.projects(id) ON DELETE CASCADE,
    file_path VARCHAR(1000) NOT NULL,
    line_number INTEGER NOT NULL,
    author VARCHAR(255) NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE,
    comment TEXT NOT NULL,
    description TEXT,
    cwe VARCHAR(20),
    state VARCHAR(20) NOT NULL CHECK (state IN ('vulnerable', 'not_vulnerable', 'todo')),
    severity VARCHAR(10) CHECK (severity IN ('high', 'medium', 'low', 'info')),
    source VARCHAR(50) DEFAULT 'native',
    import_metadata JSONB,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Severity is required for vulnerable state
    CHECK ((state = 'vulnerable' AND severity IS NOT NULL) OR state != 'vulnerable'),
    -- Line number must be positive
    CHECK (line_number > 0)
);

-- Replies table for threaded discussions
CREATE TABLE public.replies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id UUID REFERENCES public.notes(id) ON DELETE CASCADE,
    author VARCHAR(255) NOT NULL,
    user_id VARCHAR(255),
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    comment TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

\echo 'Creating indexes...'

-- Performance indexes for projects
CREATE INDEX IF NOT EXISTS idx_projects_name ON public.projects(name);
CREATE INDEX IF NOT EXISTS idx_projects_path ON public.projects(path);
CREATE INDEX IF NOT EXISTS idx_projects_created_at ON public.projects(created_at DESC);

-- Performance indexes for notes
CREATE INDEX IF NOT EXISTS idx_notes_project_file ON public.notes(project_id, file_path);
CREATE INDEX IF NOT EXISTS idx_notes_project_file_line ON public.notes(project_id, file_path, line_number);
CREATE INDEX IF NOT EXISTS idx_notes_author ON public.notes(author);
CREATE INDEX IF NOT EXISTS idx_notes_state ON public.notes(state);
CREATE INDEX IF NOT EXISTS idx_notes_created_at ON public.notes(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON public.notes(updated_at DESC) WHERE updated_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notes_cwe ON public.notes(cwe) WHERE cwe IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notes_severity ON public.notes(severity) WHERE severity IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notes_source ON public.notes(source);
CREATE INDEX IF NOT EXISTS idx_notes_timestamp ON public.notes(timestamp DESC);

-- Indexes for replies
CREATE INDEX IF NOT EXISTS idx_replies_parent ON public.replies(parent_id);
CREATE INDEX IF NOT EXISTS idx_replies_created_at ON public.replies(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_replies_author ON public.replies(author);
CREATE INDEX IF NOT EXISTS idx_replies_timestamp ON public.replies(timestamp DESC);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_notes_project_state_author ON public.notes(project_id, state, author);
CREATE INDEX IF NOT EXISTS idx_notes_file_line_state ON public.notes(file_path, line_number, state);
CREATE INDEX IF NOT EXISTS idx_notes_state_severity ON public.notes(state, severity) WHERE severity IS NOT NULL;

\echo 'Creating functions...'

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to notify about note changes for real-time sync
CREATE OR REPLACE FUNCTION notify_note_change()
RETURNS TRIGGER AS $$
DECLARE
    notification JSON;
    project_name TEXT;
BEGIN
    -- Get project name for the notification
    SELECT name INTO project_name FROM public.projects WHERE id = COALESCE(NEW.project_id, OLD.project_id);
    
    -- Build notification payload
    IF TG_OP = 'DELETE' THEN
        notification = json_build_object(
            'action', 'delete',
            'note_id', OLD.id,
            'project_id', OLD.project_id,
            'project_name', project_name,
            'file_path', OLD.file_path,
            'line_number', OLD.line_number,
            'author', OLD.author
        );
    ELSE
        notification = json_build_object(
            'action', CASE WHEN TG_OP = 'INSERT' THEN 'create' ELSE 'update' END,
            'note_id', NEW.id,
            'project_id', NEW.project_id,
            'project_name', project_name,
            'file_path', NEW.file_path,
            'line_number', NEW.line_number,
            'author', NEW.author,
            'version', NEW.version
        );
    END IF;
    
    -- Send notification
    PERFORM pg_notify('screw_notes_changes', notification::text);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Function to notify about reply changes
CREATE OR REPLACE FUNCTION notify_reply_change()
RETURNS TRIGGER AS $$
DECLARE
    notification JSON;
    note_project_id INTEGER;
    project_name TEXT;
BEGIN
    -- Get project info from parent note
    SELECT n.project_id, p.name 
    INTO note_project_id, project_name
    FROM public.notes n 
    JOIN public.projects p ON n.project_id = p.id
    WHERE n.id = COALESCE(NEW.parent_id, OLD.parent_id);
    
    -- Build notification payload
    IF TG_OP = 'DELETE' THEN
        notification = json_build_object(
            'action', 'reply_delete',
            'reply_id', OLD.id,
            'parent_id', OLD.parent_id,
            'project_id', note_project_id,
            'project_name', project_name,
            'author', OLD.author
        );
    ELSE
        notification = json_build_object(
            'action', CASE WHEN TG_OP = 'INSERT' THEN 'reply_create' ELSE 'reply_update' END,
            'reply_id', NEW.id,
            'parent_id', NEW.parent_id,
            'project_id', note_project_id,
            'project_name', project_name,
            'author', NEW.author
        );
    END IF;
    
    -- Send notification
    PERFORM pg_notify('screw_replies_changes', notification::text);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Helper function to get or create a project
CREATE OR REPLACE FUNCTION get_or_create_project(project_name TEXT, project_path TEXT)
RETURNS INTEGER AS $$
DECLARE
    project_id INTEGER;
BEGIN
    -- Try to find existing project
    SELECT id INTO project_id 
    FROM public.projects 
    WHERE name = project_name AND path = project_path;
    
    -- Create if not found
    IF project_id IS NULL THEN
        INSERT INTO public.projects (name, path) 
        VALUES (project_name, project_path)
        RETURNING id INTO project_id;
    END IF;
    
    RETURN project_id;
END;
$$ LANGUAGE plpgsql;

-- Helper function to clean up orphaned data
CREATE OR REPLACE FUNCTION cleanup_orphaned_data()
RETURNS INTEGER AS $$
DECLARE
    deleted_replies INTEGER := 0;
    deleted_projects INTEGER := 0;
BEGIN
    -- Clean up replies without parent notes
    DELETE FROM public.replies WHERE parent_id NOT IN (SELECT id FROM public.notes);
    GET DIAGNOSTICS deleted_replies = ROW_COUNT;
    
    -- Clean up projects without notes
    DELETE FROM public.projects WHERE id NOT IN (SELECT DISTINCT project_id FROM public.notes WHERE project_id IS NOT NULL);
    GET DIAGNOSTICS deleted_projects = ROW_COUNT;
    
    RETURN deleted_replies + deleted_projects;
END;
$$ LANGUAGE plpgsql;

\echo 'Creating triggers...'

-- Create triggers
DROP TRIGGER IF EXISTS update_projects_updated_at ON public.projects;
CREATE TRIGGER update_projects_updated_at 
    BEFORE UPDATE ON public.projects 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS notify_note_changes ON public.notes;
CREATE TRIGGER notify_note_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.notes
    FOR EACH ROW EXECUTE FUNCTION notify_note_change();

DROP TRIGGER IF EXISTS notify_reply_changes ON public.replies;
CREATE TRIGGER notify_reply_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.replies
    FOR EACH ROW EXECUTE FUNCTION notify_reply_change();

\echo 'Creating views...'

-- Create view for easy note querying with project info
DROP VIEW IF EXISTS notes_with_project;
CREATE VIEW notes_with_project AS
SELECT 
    n.*,
    p.name as project_name,
    p.path as project_path,
    (
        SELECT json_agg(
            json_build_object(
                'id', r.id,
                'parent_id', r.parent_id,
                'author', r.author,
                'timestamp', r.timestamp,
                'comment', r.comment,
                'created_at', r.created_at
            ) ORDER BY r.created_at
        )
        FROM public.replies r 
        WHERE r.parent_id = n.id
    ) as replies
FROM public.notes n
JOIN public.projects p ON n.project_id = p.id;

-- View for project statistics
DROP VIEW IF EXISTS project_stats;
CREATE VIEW project_stats AS
SELECT 
    p.id,
    p.name,
    p.path,
    COUNT(n.id) as total_notes,
    COUNT(CASE WHEN n.state = 'vulnerable' THEN 1 END) as vulnerable_notes,
    COUNT(CASE WHEN n.state = 'not_vulnerable' THEN 1 END) as safe_notes,
    COUNT(CASE WHEN n.state = 'todo' THEN 1 END) as todo_notes,
    COUNT(DISTINCT n.author) as contributors,
    COUNT(r.id) as total_replies,
    p.created_at,
    p.updated_at,
    MAX(n.created_at) as last_note_at
FROM public.projects p
LEFT JOIN public.notes n ON p.id = n.project_id
LEFT JOIN public.replies r ON n.id = r.parent_id
GROUP BY p.id, p.name, p.path, p.created_at, p.updated_at;

\echo 'Creating user and setting permissions...'

-- Create the screw_user role
DROP ROLE IF EXISTS screw_user;
CREATE ROLE screw_user WITH LOGIN PASSWORD 'test_collaboration_2024';

-- Grant all necessary permissions
GRANT CONNECT ON DATABASE screw_notes TO screw_user;
GRANT USAGE ON SCHEMA public TO screw_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO screw_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO screw_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO screw_user;

-- Grant permissions on future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO screw_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO screw_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO screw_user;

\echo 'Verifying setup...'

-- Show installed extensions
\echo 'Extensions:'
\dx

-- Verify tables and show structure
\echo 'Tables:'
\dt public.*

-- Show indexes
\echo 'Indexes:'
\di public.*

-- Show row counts
\echo 'Row counts:'
SELECT 'projects' as table_name, COUNT(*) as row_count FROM public.projects
UNION ALL
SELECT 'notes' as table_name, COUNT(*) as row_count FROM public.notes  
UNION ALL
SELECT 'replies' as table_name, COUNT(*) as row_count FROM public.replies;

-- Show constraints
\echo 'Constraints:'
SELECT 
    conname as constraint_name,
    contype as type,
    conrelid::regclass as table_name
FROM pg_constraint 
WHERE conrelid IN (
    SELECT oid FROM pg_class WHERE relname IN ('notes', 'replies', 'projects')
        AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
) 
ORDER BY conrelid, conname;

-- Test the get_or_create_project function
\echo 'Testing project creation:'
SELECT get_or_create_project('test_project', '/tmp/test') as test_project_id;

-- Test basic note creation
\echo 'Testing note creation:'
INSERT INTO public.notes (
    project_id, file_path, line_number, author, timestamp, comment, state
) VALUES (
    1, 'test.lua', 1, 'test_user', CURRENT_TIMESTAMP, 'Test note', 'todo'
) RETURNING id, comment;

-- Test reply creation
\echo 'Testing reply creation:'
INSERT INTO public.replies (
    parent_id, author, timestamp, comment
) SELECT 
    id, 'test_user2', CURRENT_TIMESTAMP, 'Test reply'
FROM public.notes 
WHERE comment = 'Test note'
LIMIT 1
RETURNING id, comment;

-- Show final table structures
\echo 'Final table structures:'
\d public.projects
\d public.notes
\d public.replies

-- Test connection as screw_user
\echo 'Testing screw_user connection...'
SET ROLE screw_user;
SELECT 'Connection as screw_user successful' as status;
SELECT COUNT(*) as note_count FROM public.notes;
RESET ROLE;

\echo ''
\echo '=== screw.nvim PostgreSQL Setup Completed Successfully! ==='
\echo ''
\echo 'Database: screw_notes'
\echo 'User: screw_user (password: test_collaboration_2024)'
\echo 'Tables: projects, notes, replies'
\echo 'Views: notes_with_project, project_stats'
\echo 'Functions: notify_note_change, notify_reply_change, get_or_create_project, cleanup_orphaned_data'
\echo 'Triggers: update_projects_updated_at, notify_note_changes, notify_reply_changes'
\echo 'Extensions: uuid-ossp, btree_gin, pgcrypto'
\echo ''
\echo 'Environment variables to set:'
\echo 'export SCREW_DB_URL="postgresql://screw_user:test_collaboration_2024@localhost:5432/screw_notes"'
\echo 'export SCREW_API_URL="http://10.0.160.11:3000/api"'
\echo 'export SCREW_USER_EMAIL="your-email@company.com"'
\echo ''
\echo 'Test connection:'
\echo 'psql postgresql://screw_user:test_collaboration_2024@localhost:5432/screw_notes -c "SELECT COUNT(*) FROM projects;"'
\echo ''
\echo 'Ready for screw.nvim collaboration!'