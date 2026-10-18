# Validation scope

Focused checks cover adapters, scoped streams, retries, comment cursors, danmaku formats, responsive layouts and notifications.

Recent regression coverage:
- API 28 notification reconstruction retains the progress panel without a large artwork column.
- API 36 receives duration, position, buffer, seek actions and a separate session activity; buffering pauses time extrapolation.
- Notification seeking dispatches internal transport broadcasts rather than opening an activity.
- Comment cursors advance and overlapping comments are deduplicated. Restricted previews do not advertise unsupported paging.
- Phone landscape is separate from desktop; stacked cover effects fit small thumbnails.
- About pages fit portrait and landscape; fullscreen enters and restores window mode.

Robolectric does not reproduce vendor SystemUI or a real MediaSession binder service. API 36 checks capture actual platform calls; they do not prove that all devices render identically.

Device validation should include notifications in expanded and collapsed states, buffering, seeking, pause/resume, process recreation and gestures. Public endpoint tests do not guarantee future availability, premium quality or regional access. Never put personal credentials in fixtures.
