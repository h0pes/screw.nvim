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
---@field source "native"|"sarif-import"? Source of the note (defaults to "native")
---@field import_metadata ScrewImportMetadata? Import-specific metadata (only for imported notes)

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

---@class ScrewImportMetadata
---@field tool_name string Tool that generated the findings (e.g., "Bandit", "Semgrep")
---@field sarif_file_path string Original SARIF file path
---@field import_timestamp string ISO 8601 timestamp when import occurred
---@field rule_id string Tool-specific rule ID (e.g., "B304", "rules.detect-sql-injection")
---@field confidence string? Confidence level from tool ("HIGH", "MEDIUM", "LOW")
---@field original_severity string? Original severity from tool
---@field original_level string? Original SARIF level ("error", "warning", "note", "none")

---@class ScrewImportOptions
---@field format "sarif" Import format (currently only SARIF supported)
---@field input_path string Input file path
---@field author string? Author name for imported notes (default: "sarif-import")
---@field collision_strategy "ask"|"skip"|"overwrite"|"merge"? How to handle collisions (default: "ask")
---@field file_filter string[]? Only import findings for specific files
---@field show_progress boolean? Show progress indicator for large imports (default: false)

---@class ScrewImportResult
---@field success boolean Whether import completed successfully
---@field total_findings integer Total findings in SARIF file
---@field imported_count integer Number of notes successfully imported
---@field skipped_count integer Number of findings skipped (duplicates, filtered, etc.)
---@field collision_count integer Number of collisions handled
---@field error_count integer Number of errors encountered
---@field tool_name string Name of the tool that generated the SARIF
---@field sarif_file_path string Path to the imported SARIF file
---@field errors string[]? List of error messages if any occurred

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
