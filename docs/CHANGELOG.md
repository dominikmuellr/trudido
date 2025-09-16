# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - Unreleased

### Added
- Dynamic Material You color extraction (Android 12+) with in-app toggle
- Themed monochrome adaptive icon (Android 13+)
- Theme mode selector (System / Light / Dark)
- Pure Black (AMOLED) dark theme option
- Floating Action Button position customization (Left / Center / Right)
- Option to hide greeting header
- Bulk edit / multi-select for tasks (initial: complete, un-complete, delete)
- Optional Compact Density Mode (tighter spacing)
- Optional High Contrast Mode (enhanced contrast accessibility)
- (Planned) Snooze duration customization presets
- (Planned) Improved notification reliability diagnostics panel
- (Planned) Optional daily summary notification
- (Planned) Category color customization

### Changed
- Bumped app version to 1.1.0 for upcoming feature release
- Theme building pipeline refactored to support dynamic colors, pure black, density & high contrast toggles

### Fixed
- Preference initialization race conditions via early ensurePrefs pattern
- (Planned) Edge case: notifications scheduled exactly at DST change boundary

### Technical / Internal
- Added new SharedPreferences keys: fab_position, hide_greeting, compact_density, high_contrast, use_dynamic_color, use_black_theme
- Introduced multi-select state management (Riverpod providers) and selection highlight animation
- Centralized theme parameterization (AppTheme.buildThemes) for future extensibility
- Introduced CHANGELOG.md to track versioned changes
 - (Priority 1) Added PreferencesService + PreferencesState (cached, typed wrapper over SharedPreferences)
 - (Priority 1) Added AppError/AppErrorType unified error handling model
 - (Priority 1) Added TaskRepository abstraction, generic app providers & error boundary widget
 - (Priority 1) Added guardAsync helper & base incompleteTasksProvider
 - (Priority 1) Unified legacy scattered preference notifiers into single PreferencesController
 - (Priority 1) Introduced TaskController (CRUD, notifications, reorder persistence, statistics)
 - (Priority 1) Replaced legacy todo_provider with tasksProvider + filter providers
 - (Priority 1) Extracted granular filter providers (search, category, priority, folder, sort, showCompleted)
 - (Priority 1) Added CategoryRepository & CategoryController (decoupled category CRUD)
 - (Priority 1) Implemented persistent manual reorder (TaskRepository.saveOrder)
 - (Priority 1) Extended TaskStatistics (category & priority distributions, streak calculation)
 - (Cleanup) Removed legacy statistics.dart & todo_provider.dart after full migration
 - (Cleanup) Updated StatsCard & QuickProgressCard to consume TaskStatistics directly (removed adapter layer)
 - (Testing) Added pure function tests for reorder & reminder times (computeReordered, computeReminderTimes)
 - (Testing) Introduced disableSideEffects flag in `TodoApp` for deterministic widget tests
 - (Testing) Stabilized widget tests by mocking path_provider & shared_preferences channels
 - (Testing) Replaced pumpAndSettle with bounded frame loop to avoid indefinite waits
 - (UI) Removed ambiguous loading heuristic in `HomeScreen` that masked legitimate empty state ('No todos yet') during tests
 - (Refactor) Added `rawTasksProvider` indirection to simplify provider overrides in tests
 - (Refactor) Eliminated remaining `use_build_context_synchronously` analyzer infos by reworking startup reliability flow & dialog context acquisition (navigation key re-fetch pattern)
 - (Refactor) Rebuilt `main.dart` after accidental overwrite with cleaner reliability gating & theme initialization
 - (Refactor) Converted permission & battery optimization dialogs to fetch fresh context post-await; added convenience auto wrappers
 - (Refactor) Ensured all navigator/snackBar interactions guarded by `mounted` and dynamic context retrieval to harden against lifecycle races
 - (Testing) Maintained green suite (21 tests) after async context refactors
 - (Feature) Phase 1 multi-day tasks: added `startDate` field, multi-day toggle in edit screen, today-active provider (spans included)

## [1.0.0] - 2025-08-29
- Initial feature-complete release
