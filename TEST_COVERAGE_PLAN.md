# Complete Test Coverage Plan for screw.nvim

## Overview

This document outlines a comprehensive test coverage plan for screw.nvim, focusing on areas that currently lack testing, particularly the recently developed collaboration features and critical storage backends.

## Current Test Status

### Existing Tests
- ✅ `spec/screw/init_spec.lua` - Basic API functions (minimal coverage)
- ✅ `spec/screw/notes/manager_spec.lua` - Core note management operations  
- ✅ `spec/screw/notes/ui_spec.lua` - UI deletion functionality (recent addition)
- ✅ `spec/screw/utils_spec.lua` - Utility functions validation
- ✅ `spec/screw/import_spec.lua` - Import module interface
- ✅ `spec/screw/import/sarif_spec.lua` - SARIF import parser
- ✅ `spec/screw/export/sarif_spec.lua` - SARIF export functionality
- ❌ `spec/screw/export_spec.lua` - Empty file (needs implementation)

### Major Coverage Gaps
1. **Collaboration Features** - Recently developed, no tests
2. **Storage Backends** - Critical functionality, minimal coverage
3. **Core Plugin Features** - Signs, jump navigation, configuration
4. **Export Formats** - Multiple formats missing tests
5. **Integration Features** - Events, commands, error handling

## Implementation Plan

## Phase 1: Collaboration Features (High Priority) 🔴

**CRITICAL**: Collaboration mode was recently developed but lacks tests entirely

### 1.1 Collaboration Core (`spec/screw/collaboration_spec.lua`)
- [x] Mode detection and switching between local/collaborative
- [x] Environment variable configuration handling  
- [x] Integration with storage backend selection
- [x] Setup and cleanup lifecycle
- [x] Error handling for missing environment variables
- [x] Integration with configuration system

### 1.2 Mode Detector (`spec/screw/collaboration/mode_detector_spec.lua`)
- [x] Automatic mode detection logic
- [x] Database availability checks
- [x] Local notes presence detection
- [x] User choice dialogs and fallback handling
- [x] Migration requirement detection
- [x] Force mode functionality

### 1.3 Real-time Sync (`spec/screw/collaboration/realtime_spec.lua`)
- [ ] PostgreSQL LISTEN/NOTIFY functionality
- [ ] Event handling for remote note changes
- [ ] Connection management and health checks
- [ ] Error recovery and reconnection logic
- [ ] Event callbacks for note/reply changes
- [ ] Status reporting and monitoring

### 1.4 Migration (`spec/screw/collaboration/migration_spec.lua`)  
- [ ] Data migration between storage backends
- [ ] Conflict resolution strategies
- [ ] Rollback mechanisms for failed migrations
- [ ] Data integrity validation
- [ ] Progress reporting and user feedback

## Phase 2: Storage Backend Coverage (Critical) 🔴

**CRITICAL**: Core data persistence needs comprehensive testing

### 2.1 JSON Storage (`spec/screw/notes/storage/json_spec.lua`)
- [x] File I/O operations and error handling
- [x] Note serialization/deserialization  
- [x] Atomic writes and data corruption prevention
- [x] Directory creation and permissions
- [x] Load/save operations with large note collections
- [x] Backup and recovery mechanisms

### 2.2 PostgreSQL Storage (`spec/screw/notes/storage/postgresql_spec.lua`)
- [x] Database connection management
- [x] SQL query execution and transactions
- [x] Real-time notification setup
- [x] Offline mode and connection recovery
- [x] Database schema validation
- [x] Connection pooling and cleanup

### 2.3 HTTP Storage (`spec/screw/notes/storage/http_spec.lua`)
- [ ] API request/response handling
- [ ] Authentication and authorization
- [ ] Network error handling and retries
- [ ] Data synchronization logic
- [ ] Rate limiting and throttling
- [ ] API endpoint validation

### 2.4 Storage Manager (`spec/screw/notes/storage_spec.lua`)
- [ ] Backend selection and switching
- [ ] Configuration-driven initialization
- [ ] Abstract interface compliance
- [ ] Error propagation and handling
- [ ] Backend health monitoring

## Phase 3: Core Plugin Features (Medium Priority) 🟡

### 3.1 Signs Management (`spec/screw/signs_spec.lua`)
- [x] Sign placement and removal
- [x] Priority handling for multiple notes per line
- [x] Buffer lifecycle integration
- [x] Visual state representation (vulnerable, safe, todo)
- [x] Sign definitions and highlight groups
- [x] Autocommand integration
- [x] Performance with many signs

### 3.2 Jump Navigation (`spec/screw/jump_spec.lua`)
- [x] Next/previous note navigation
- [x] Keyword filtering functionality
- [x] Wraparound behavior
- [x] Empty buffer handling
- [x] Cursor positioning and centering
- [x] Info message display

### 3.3 Configuration (`spec/screw/config_spec.lua`)
- [ ] Default configuration loading
- [ ] User override handling
- [ ] Validation and error reporting
- [ ] Dynamic reconfiguration
- [ ] Environment-based configuration
- [ ] Migration of configuration formats

### 3.4 Health Checks (`spec/screw/health_spec.lua`)
- [ ] Dependency availability checks
- [ ] Configuration validation
- [ ] Storage backend health
- [ ] Collaboration setup verification
- [ ] Environment variable validation
- [ ] Performance diagnostics

## Phase 4: Export/Import Coverage (Medium Priority) 🟡

### 4.1 Export Formats (`spec/screw/export/`)
- [ ] **Markdown Export** (`markdown_spec.lua`) - Template rendering, formatting
- [ ] **CSV Export** (`csv_spec.lua`) - Data structure flattening, escaping  
- [ ] **JSON Export** (`json_spec.lua`) - Schema validation, metadata
- [x] **Export Manager** (`export_spec.lua`) - Format selection, batch operations

### 4.2 Enhanced Import Coverage (`spec/screw/import/`)
- [ ] **SARIF Import Enhanced** - Complex SARIF files, edge cases, validation
- [ ] **Import Manager Enhanced** - Collision handling, validation, batch processing
- [ ] **Error Recovery** - Malformed input, partial failures, rollback

## Phase 5: Integration and Edge Cases (Lower Priority) 🟢

### 5.1 Extended UI Coverage (`spec/screw/notes/ui_spec.lua`)
- [ ] **Float Windows** - Creation, interaction, keyboard navigation
- [ ] **Note Creation** - Form validation, field handling
- [ ] **Note Viewing** - Filtering, sorting, pagination  
- [ ] **Reply System** - Threading, author attribution
- [ ] **Confirmation Dialogs** - User choices, cancellation
- [ ] **Error Display** - User-friendly error messages

### 5.2 Advanced Manager Features (`spec/screw/notes/manager_spec.lua`)
- [ ] **Bulk Operations** - Multi-note updates, batch deletion
- [ ] **Advanced Filtering** - Complex queries, date ranges
- [ ] **Statistics** - Aggregation functions, reporting
- [ ] **Validation** - Complex business rules, data integrity
- [ ] **Performance** - Large dataset operations

### 5.3 API Integration (`spec/screw/init_spec.lua`)
- [ ] **Complete API Coverage** - All public functions tested
- [ ] **Error Propagation** - Consistent error handling
- [ ] **Event Integration** - Autocommand triggers
- [ ] **Initialization** - Plugin setup and teardown
- [ ] **Command Integration** - User command functionality

## Implementation Strategy

### 1. Test Infrastructure Enhancement
- Extend mock systems for collaboration features
- Create database test utilities for PostgreSQL backend
- Add network mocking for HTTP backend testing
- Enhance vim API mocking for signs and UI features

### 2. Incremental Implementation
- Start with collaboration core, then storage backends  
- Focus on critical paths and error scenarios
- Ensure each test is independent and reproducible
- Add integration tests for complete workflows

### 3. Documentation Updates
- Update test documentation as coverage expands
- Document test utilities and mocking strategies
- Maintain test coverage metrics
- Create testing guidelines for contributors

### 4. Quality Assurance
- Ensure tests cover real user workflows
- Test both success and failure scenarios
- Validate error messages and user feedback
- Performance considerations for large datasets

## Priority Legend

- 🔴 **High Priority** - Critical functionality, recent features lacking tests
- 🟡 **Medium Priority** - Important features with partial or missing coverage
- 🟢 **Lower Priority** - Enhancement and edge case coverage

## Success Metrics

- [ ] All collaboration features have comprehensive test coverage
- [ ] All storage backends are fully tested with error scenarios
- [ ] Core plugin features (signs, jump, config) are well covered
- [ ] Export/import functionality handles edge cases properly
- [ ] Integration tests validate complete user workflows
- [ ] Test suite runs reliably in CI/CD environment

## Notes

- Focus on testing the actual behavior users experience
- Mock external dependencies (databases, network) appropriately
- Ensure tests are maintainable and well-documented
- Consider test performance for large test suites
- Plan for future feature additions and test extensibility