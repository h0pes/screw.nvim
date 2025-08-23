#!/usr/bin/env python3
"""
Screw.nvim Collaboration Server
A production FastAPI server for screw.nvim HTTP-based collaboration
"""

import os
import json
import uuid
import logging
from datetime import datetime
from typing import List, Optional, Dict, Any
import psycopg
from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Configure logging with timestamps
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# Configuration from environment
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://screw_user:test_collaboration_2024@localhost/screw_notes")
HOST = os.getenv("SCREW_HOST", "0.0.0.0")
PORT = int(os.getenv("SCREW_PORT", "3000"))

# Pydantic models
class ScrewNote(BaseModel):
    id: Optional[str] = None
    file_path: str
    line_number: int
    author: str
    timestamp: Optional[str] = None
    comment: str
    description: Optional[str] = None
    cwe: Optional[str] = None
    state: str = "todo"  # vulnerable, not_vulnerable, todo
    severity: Optional[str] = None  # high, medium, low, info
    source: str = "native"  # native, sarif-import
    import_metadata: Optional[Dict[str, Any]] = None  # SARIF import metadata
    project_name: str
    user_id: str
    replies: Optional[List[Dict[str, Any]]] = []

class ScrewReply(BaseModel):
    id: Optional[str] = None
    parent_id: str
    author: str
    timestamp: Optional[str] = None
    comment: str
    user_id: str

class NotesResponse(BaseModel):
    notes: List[Dict[str, Any]]

class StatsResponse(BaseModel):
    total_notes: int
    project_name: str

# FastAPI app
app = FastAPI(title="Screw.nvim Collaboration Server", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = datetime.now()
    client_ip = request.client.host if request.client else "unknown"
    
    # Log request
    logger.info(f"→ {request.method} {request.url.path} from {client_ip}")
    
    # Process request
    response = await call_next(request)
    
    # Calculate duration
    duration = (datetime.now() - start_time).total_seconds()
    
    # Log response
    logger.info(f"← {response.status_code} for {request.method} {request.url.path} ({duration:.3f}s)")
    
    return response

# Database connection
def get_db_connection():
    """Get database connection"""
    try:
        conn = psycopg.connect(DATABASE_URL, autocommit=True)
        return conn
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection failed: {str(e)}")

def init_database():
    """Initialize database - verify connection and add missing columns"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        # Test connection
        cur.execute("SELECT COUNT(*) FROM projects LIMIT 1")
        cur.execute("SELECT COUNT(*) FROM notes LIMIT 1")
        logger.info("✓ Database connection verified, main tables exist")
        
        # Check if replies table exists
        try:
            cur.execute("SELECT COUNT(*) FROM replies LIMIT 1")
            logger.info("✓ Replies table exists")
        except Exception as e:
            logger.warning(f"⚠ Replies table issue: {e}")
            logger.warning("Note: You may need to create the replies table manually if it doesn't exist")
        
        # Add missing columns if they don't exist
        missing_columns = [
            ("description", "TEXT"),
            ("cwe", "VARCHAR(20)"),
            ("severity", "VARCHAR(10)"),
            ("updated_at", "TIMESTAMP DEFAULT CURRENT_TIMESTAMP"),
            ("source", "VARCHAR(20) DEFAULT 'native'")
        ]
        
        for column_name, column_type in missing_columns:
            try:
                cur.execute(f"ALTER TABLE notes ADD COLUMN {column_name} {column_type}")
                logger.info(f"✓ Added missing column: {column_name}")
            except Exception as e:
                if "already exists" in str(e).lower():
                    logger.info(f"✓ Column {column_name} already exists")
                else:
                    logger.warning(f"⚠ Could not add column {column_name}: {e}")
            
    except Exception as e:
        logger.error(f"Database verification error: {e}")
        # Continue anyway - might be temporary
        
    finally:
        cur.close()
        conn.close()

# Initialize database on startup
init_database()

@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "ok", "server": "screw-production", "timestamp": datetime.now().isoformat()}

@app.get("/api/notes/{project_name}", response_model=NotesResponse)
async def get_project_notes(project_name: str):
    """Get all notes for a project"""
    logger.info(f"Getting notes for project: {project_name}")
    conn = get_db_connection()
    cur = conn.cursor(row_factory=psycopg.rows.dict_row)
    
    try:
        # Get notes with their replies
        cur.execute("""
            SELECT n.*, p.name as project_name,
                   COALESCE(
                       json_agg(
                           json_build_object(
                               'id', r.id,
                               'parent_id', r.parent_id,
                               'author', r.author,
                               'timestamp', r.timestamp,
                               'comment', r.comment
                           )
                       ) FILTER (WHERE r.id IS NOT NULL), 
                       '[]'::json
                   ) as replies
            FROM notes n
            JOIN projects p ON n.project_id = p.id
            LEFT JOIN replies r ON n.id = r.parent_id
            WHERE p.name = %s
            GROUP BY n.id, p.name
            ORDER BY n.timestamp DESC
        """, (project_name,))
        
        notes = cur.fetchall()
        
        # Convert to dict and format timestamps
        result_notes = []
        for note in notes:
            note_dict = dict(note)
            # Convert UUID to string
            note_dict['id'] = str(note_dict['id'])
            # Convert timestamps to ISO strings
            if note_dict.get('timestamp'):
                note_dict['timestamp'] = note_dict['timestamp'].isoformat()
            if note_dict.get('updated_at'):
                note_dict['updated_at'] = note_dict['updated_at'].isoformat()
            result_notes.append(note_dict)
        
        logger.info(f"Found {len(result_notes)} notes for project {project_name}")
        for note in result_notes:
            logger.info(f"  Note {note['id'][:8]}... at {note['file_path']}:{note['line_number']}")
            
        return NotesResponse(notes=result_notes)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

@app.get("/api/notes/{project_name}/file", response_model=NotesResponse)
async def get_file_notes(project_name: str, path: str = Query(...)):
    """Get notes for a specific file"""
    conn = get_db_connection()
    cur = conn.cursor(row_factory=psycopg.rows.dict_row)
    
    try:
        cur.execute("""
            SELECT n.*, 
                   COALESCE(
                       json_agg(
                           json_build_object(
                               'id', r.id,
                               'parent_id', r.parent_id,
                               'author', r.author,
                               'user_id', r.user_id,
                               'timestamp', r.timestamp,
                               'comment', r.comment
                           )
                       ) FILTER (WHERE r.id IS NOT NULL), 
                       '[]'::json
                   ) as replies
            FROM notes n
            LEFT JOIN replies r ON n.id = r.parent_id
            WHERE n.project_name = %s AND n.file_path = %s
            GROUP BY n.id
            ORDER BY n.line_number
        """, (project_name, path))
        
        notes = cur.fetchall()
        result_notes = [dict(note) for note in notes]
        
        return NotesResponse(notes=result_notes)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

@app.get("/api/notes/{project_name}/line", response_model=NotesResponse)
async def get_line_notes(project_name: str, path: str = Query(...), line: int = Query(...)):
    """Get notes for a specific line"""
    conn = get_db_connection()
    cur = conn.cursor(row_factory=psycopg.rows.dict_row)
    
    try:
        cur.execute("""
            SELECT n.*, 
                   COALESCE(
                       json_agg(
                           json_build_object(
                               'id', r.id,
                               'parent_id', r.parent_id,
                               'author', r.author,
                               'user_id', r.user_id,
                               'timestamp', r.timestamp,
                               'comment', r.comment
                           )
                       ) FILTER (WHERE r.id IS NOT NULL), 
                       '[]'::json
                   ) as replies
            FROM notes n
            LEFT JOIN replies r ON n.id = r.parent_id
            WHERE n.project_name = %s AND n.file_path = %s AND n.line_number = %s
            GROUP BY n.id
            ORDER BY n.created_at
        """, (project_name, path, line))
        
        notes = cur.fetchall()
        result_notes = [dict(note) for note in notes]
        
        return NotesResponse(notes=result_notes)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

@app.get("/api/notes/note/{note_id}")
async def get_note_by_id(note_id: str):
    """Get a specific note by ID"""
    conn = get_db_connection()
    cur = conn.cursor(row_factory=psycopg.rows.dict_row)
    
    try:
        cur.execute("""
            SELECT n.*, 
                   COALESCE(
                       json_agg(
                           json_build_object(
                               'id', r.id,
                               'parent_id', r.parent_id,
                               'author', r.author,
                               'timestamp', r.timestamp,
                               'comment', r.comment
                           )
                       ) FILTER (WHERE r.id IS NOT NULL), 
                       '[]'::json
                   ) as replies
            FROM notes n
            LEFT JOIN replies r ON n.id = r.parent_id
            WHERE n.id = %s
            GROUP BY n.id
        """, (note_id,))
        
        note = cur.fetchone()
        if not note:
            raise HTTPException(status_code=404, detail="Note not found")
            
        # Convert timestamps to ISO strings
        note_dict = dict(note)
        if note_dict.get('timestamp'):
            note_dict['timestamp'] = note_dict['timestamp'].isoformat()
        if note_dict.get('updated_at'):
            note_dict['updated_at'] = note_dict['updated_at'].isoformat()
        if note_dict.get('created_at'):
            note_dict['created_at'] = note_dict['created_at'].isoformat()
            
        return {"note": note_dict}
        
    except Exception as e:
        logger.error(f"ERROR in get_note_by_id({note_id}): {str(e)}")
        if "Note not found" in str(e):
            raise e
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

@app.post("/api/notes")
async def create_note(note: ScrewNote):
    """Create a new note"""
    logger.info(f"Creating note for project {note.project_name} at {note.file_path}:{note.line_number}")
    logger.info(f"Note content: {note.comment[:50]}{'...' if len(note.comment) > 50 else ''}")
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        # Get or create project
        cur.execute(
            "SELECT id FROM projects WHERE name = %s AND path = %s",
            (note.project_name, "/")  # Use "/" as default path
        )
        project_row = cur.fetchone()
        
        if not project_row:
            # Create project with name and default path
            cur.execute(
                "INSERT INTO projects (name, path) VALUES (%s, %s) RETURNING id",
                (note.project_name, "/")
            )
            project_id = cur.fetchone()[0]
        else:
            project_id = project_row[0]
        
        # Insert note (id will be auto-generated as UUID)
        logger.info(f"Inserting note for project_id={project_id}, file={note.file_path}, line={note.line_number}")
        cur.execute("""
            INSERT INTO notes (
                project_id, file_path, line_number, author, 
                timestamp, comment, description, cwe, state, severity, source, import_metadata, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id
        """, (
            project_id, note.file_path, note.line_number,
            note.author, datetime.now(), note.comment, note.description,
            note.cwe, note.state, note.severity, 
            note.source, json.dumps(note.import_metadata) if note.import_metadata else None, datetime.now()
        ))
        
        created_note_id = cur.fetchone()[0]
        note.id = str(created_note_id)
        logger.info(f"✓ Note created with ID: {created_note_id}")
        
        return {"note": note.dict()}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

@app.put("/api/notes/{note_id}")
async def update_note(note_id: str, note: ScrewNote):
    """Update an existing note"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        cur.execute("""
            UPDATE notes SET
                file_path = %s, line_number = %s, author = %s,
                comment = %s, description = %s, cwe = %s, state = %s, severity = %s, source = %s,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
        """, (
            note.file_path, note.line_number, note.author,
            note.comment, note.description, note.cwe, note.state, note.severity, note.source, note_id
        ))
        
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Note not found")
            
        # Return updated note
        note.id = note_id
        return {"note": note.dict()}
        
    except Exception as e:
        if "Note not found" in str(e):
            raise e
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

@app.delete("/api/notes/{note_id}")
async def delete_note(note_id: str):
    """Delete a note"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        cur.execute("DELETE FROM notes WHERE id = %s", (note_id,))
        
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Note not found")
            
        return {"success": True}
        
    except Exception as e:
        if "Note not found" in str(e):
            raise e
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

@app.delete("/api/notes/{project_name}")
async def clear_project_notes(project_name: str):
    """Clear all notes for a project"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        cur.execute("DELETE FROM notes WHERE project_name = %s", (project_name,))
        return {"success": True, "deleted_count": cur.rowcount}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

@app.post("/api/notes/{parent_id}/replies")
async def create_reply(parent_id: str, reply: ScrewReply):
    """Add a reply to a note"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        # Check if parent note exists
        cur.execute("SELECT id FROM notes WHERE id = %s", (parent_id,))
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="Parent note not found")
            
        # Generate reply ID if not provided
        if not reply.id:
            reply.id = str(uuid.uuid4())
            
        # Set timestamp if not provided
        if not reply.timestamp:
            reply.timestamp = datetime.now().isoformat()
            
        # Insert reply
        cur.execute("""
            INSERT INTO replies (id, parent_id, author, user_id, timestamp, comment)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (reply.id, parent_id, reply.author, reply.user_id, reply.timestamp, reply.comment))
        
        return {"reply": reply.dict()}
        
    except Exception as e:
        if "Parent note not found" in str(e):
            raise e
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

@app.put("/api/notes/{project_name}/replace")
async def replace_all_notes(project_name: str, data: Dict[str, List[Dict[str, Any]]]):
    """Replace all notes for a project"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        # Clear existing notes
        cur.execute("DELETE FROM notes WHERE project_name = %s", (project_name,))
        
        # Ensure project exists
        cur.execute(
            "INSERT INTO projects (name) VALUES (%s) ON CONFLICT (name) DO NOTHING",
            (project_name,)
        )
        
        # Insert new notes
        notes = data.get("notes", [])
        for note_data in notes:
            cur.execute("""
                INSERT INTO notes (
                    id, project_name, file_path, line_number, author, user_id,
                    timestamp, comment, description, cwe, state
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                note_data.get("id", str(uuid.uuid4())),
                project_name,
                note_data["file_path"],
                note_data["line_number"],
                note_data["author"],
                note_data.get("user_id", note_data["author"]),
                note_data.get("timestamp", datetime.now().isoformat()),
                note_data["comment"],
                note_data.get("description"),
                note_data.get("cwe"),
                note_data.get("state", "todo")
            ))
            
        return {"success": True, "count": len(notes)}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

@app.get("/api/stats/{project_name}", response_model=StatsResponse)
async def get_project_stats(project_name: str):
    """Get statistics for a project"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    try:
        cur.execute("SELECT COUNT(*) FROM notes WHERE project_name = %s", (project_name,))
        total_notes = cur.fetchone()[0]
        
        return StatsResponse(total_notes=total_notes, project_name=project_name)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

if __name__ == "__main__":
    import uvicorn
    logger.info(f"Starting Screw.nvim Collaboration Server on {HOST}:{PORT}")
    logger.info(f"Database: {DATABASE_URL}")
    uvicorn.run(app, host=HOST, port=PORT)