# Trudido

A feature-rich todo application with .md-notes feature built with Flutter.

## Features

- ✅ **Task Management**: Create, edit, delete, and mark tasks as complete
- 🎯 **Priority System**: Organize tasks by High, Medium, and Low priority
- 📂 **Categories**: Group tasks into customizable categories
- 📅 **Due Dates**: Set and track task deadlines
- 🔍 **Search & Filter**: Find tasks quickly with search and filtering options
- 📊 **Statistics**: Track your productivity with detailed statistics
- 🌙 **Dark Mode**: Support for light, dark, and system themes
- 💾 **Local Storage**: All data is stored locally using Hive database
- 📱 **Responsive Design**: Works on mobile, tablet, and desktop


## Architecture

This app follows clean architecture principles with:

- **Models**: Data classes for Todo, Category, and Statistics
- **Services**: Business logic including storage, theme management, and state providers
- **Widgets**: Reusable UI components
- **Screens**: Main application screens

### State Management

Uses **Riverpod** for reactive state management and dependency injection.

### Data Persistence

- **Hive**: For structured data (todos, categories)
- **SharedPreferences**: For simple settings and preferences

### Reminder Reliability (Android)

Time‑critical reminders and snoozes rely on several Android platform capabilities:

| Capability | Why Needed | How Granted |
|------------|------------|-------------|
| Exact alarms (Android 12+) | Ensures reminders fire at the precise minute even in Doze / idle | User toggles in system settings (no runtime dialog) |
| Ignore battery optimizations (Doze whitelist) | Prevents OS from delaying or canceling scheduled alarms | User approves system prompt / allowlist screen |
| Post notifications (Android 13+) | Display reminder notifications | Runtime permission prompt |

Implementation highlights:
* `SystemSettingsService` (MethodChannel `app.perms`) bridges native checks & intents.
* `AlarmSettingsWatcher` re-checks states when the app resumes.
* `UnifiedSettingsPage` exposes a consolidated UI (Settings > Reminder Reliability or Home menu > Reminder Reliability).
* Dialog helpers in `system_permission_dialogs.dart` provide rationale before opening system screens.

Best practices followed:
* Just‑in‑time education (only prompt if not already granted).
* Graceful fallback for devices lacking specific intents (falls back to app details / generic settings).
* Fail‑open defaults for non-Android platforms to keep cross‑platform UX smooth.

Testing tips:
1. Disable exact alarms in system settings (Android 12+), reopen app, verify dialog & status updates.
2. Re-enable battery optimization, then use Unified Settings page to request exemption.
3. On Android 13+, revoke the notifications permission and re-trigger the request flow.
4. Schedule a reminder both before and after granting exact alarms to compare timing accuracy.

## About This Project

This project is entirely developed and maintained by me, dominikmuellr.

While GitHub may list other contributors due to forks or code reuse, all original work and commits are mine.

# trudido
