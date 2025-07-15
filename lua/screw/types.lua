--- Type definitions for screw.nvim - Security Code Review Plugin
---
--- This file contains all the type definitions used throughout the plugin
--- for security note management, configuration, and collaboration features.
---

---@class ScrewNote
---@field id string Unique identifier for the note
---@field file_path string Relative path to the file from project root
---@field line_number integer Line number in the file (1-based)
---@field author string Author of the note
---@field timestamp string ISO 8601 timestamp when note was created (e.g., "2024-01-01T12:00:00Z")
---@field updated_at string? ISO 8601 timestamp when note was last updated
---@field comment string Main comment text
---@field description string? Optional detailed description
---@field cwe string? CWE identifier (e.g., "CWE-79", "CWE-89")
---@field state "vulnerable"|"not_vulnerable"|"todo" Vulnerability assessment state
---@field severity "high"|"medium"|"low"|"info"? Severity level (mandatory if state is "vulnerable", optional otherwise)
---@field replies ScrewReply[]? Array of reply messages

---@class ScrewReply
---@field id string Unique identifier for the reply
---@field parent_id string ID of the parent note
---@field author string Author of the reply
---@field timestamp string ISO 8601 timestamp
---@field comment string Reply comment text

-- Configuration types are now defined in screw.config.meta
-- This maintains backward compatibility while using the new system

---@class ScrewNoteFilter
---@field author string? Filter by author
---@field state "vulnerable"|"not_vulnerable"|"todo"? Filter by state
---@field severity "high"|"medium"|"low"|"info"? Filter by severity
---@field cwe string? Filter by CWE
---@field file_path string? Filter by file path pattern

---@class ScrewExportOptions
---@field format "markdown"|"json"|"csv"|"sarif" Export format
---@field output_path string? Output file path
---@field filter ScrewNoteFilter? Filter criteria
---@field include_replies boolean? Include reply threads (default: true)

---@class ScrewImportOptions
---@field tool "semgrep"|"bandit"|"gosec"|"sonarqube" SAST tool type
---@field input_path string Input file path
---@field author string? Author name for imported notes
---@field auto_classify boolean? Auto-classify vulnerability state (default: true)

---@class StorageBackend
---@field setup fun(): nil Initialize the storage backend
---@field load_notes fun(): nil Load notes from storage
---@field save_notes fun(): boolean Save notes to storage
---@field get_all_notes fun(): ScrewNote[] Get all notes
---@field get_note fun(id: string): ScrewNote? Get note by ID
---@field save_note fun(note: ScrewNote): boolean Save a single note
---@field delete_note fun(id: string): boolean Delete a note
---@field get_notes_for_file fun(file_path: string): ScrewNote[] Get notes for specific file
---@field get_notes_for_line fun(file_path: string, line_number: number): ScrewNote[] Get notes for specific line
---@field clear_notes fun(): nil Clear all notes (for testing)
---@field force_save fun(): boolean Force save notes
---@field get_storage_stats fun(): table Get storage statistics
