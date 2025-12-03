// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2025 Dominik Müller
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

/// Unified application error types for consistent error handling & logging.
enum AppErrorType {
  storageRead,
  storageWrite,
  serialization,
  deserialization,
  notFound,
  validation,
  unknown,
}

/// Simple wrapper exception carrying a type and context message.
class AppError implements Exception {
  final AppErrorType type;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppError(this.type, this.message, {this.cause, this.stackTrace});

  @override
  String toString() =>
      'AppError(type: $type, message: $message, cause: $cause)';
}
