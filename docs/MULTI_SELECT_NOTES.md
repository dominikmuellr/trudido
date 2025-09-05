# Multi-Select / Bulk Edit Feature (Design Notes)

Status: In progress (MVP implemented)

## Scope (MVP)
Allow selecting multiple tasks to:
- Mark complete / incomplete
- Delete
- (Future) Change priority / category / folder

## UX
- Long-press (or checkbox long press) enters selection mode.
- Tapping items toggles selection.
- AppBar changes to show count + bulk action icons.
- Back / X exits selection mode.
- Maintains current filters/sorting.

## State
- `multiSelectModeProvider` (bool)
- `selectedTodoIdsProvider` (Set<String>)

## Future Extensions
- Bulk reschedule (shift due date)
- Bulk add/remove reminder offsets
- Bulk move to folder / category

## Open Questions
- Should manual reorder be disabled while in selection mode? (Current: yes, implicit via different list builder path.)
- Add haptic feedback on first selection? (Not yet.)

## Cleanup Checklist Before Release
- Add undo SnackBars for bulk delete
- Add tests for selection edge cases
- Add analytics/logging (optional)
