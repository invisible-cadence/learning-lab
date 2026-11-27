# PostHog learning lab

Setup: PostHog Cloud (region: EU), HTML snippet, served locally with `npx serve`.

## Warm-up steps

### 1. Hello PostHog 
Set up basic HTML webpage with two buttons: a "hello" custom event button and a plain button to understand autocapture. Compared recorded events in console/PostHog activity.

### 2. People 
Added fake "Log in" (`posthog.identify('fake-user-1', {email, plan})`), "Log out" (`posthog.reset()`) and "Who am I?" buttons. Watched the `distinct_id` go from anonymous → `fake-user-1` → a new anonymous ID.
- `identify` links the old anonymous ID to the user (sent as `$anon_distinct_id`), so events from before login join the person. The person page shows both IDs, and "First seen" went back to my step 1 clicks (~15 hours prior).

### 3. Explore data 
Built a Trends insight on `video_progress`: Total count 4 vs Unique users 1, then broke it down by `percent`. Tried an SQL breakdown (picker → "All" dropdown → SQL): `concat(properties.$browser, ' - ', properties.$os)` gave "Chrome - Windows". In the SQL editor, counted events per name for the last 7 days (top: `rate_test`, `video_timeupdate`, `$web_vitals`). Looked at one event's Raw JSON: `timestamp` (when it happened) vs `$sent_at` (when the SDK sent it) vs `created_at` (when PostHog received it). 

### 4. Capture API 
Sent a `curl_test` event with `curl.exe` to `https://eu.i.posthog.com/i/v0/e/` (body in [curl-event.json](curl-event.json)), with a custom `timestamp` of 25 Nov 09:00 UTC. PostHog placed it on 25 Nov, and `created_at` showed when it actually arrived (27 Nov). It had none of the browser properties (`$browser`, `$os`, etc. come from the SDK), but GeoIP was still added on the server. 

## Experiment 1: PII deletion
**Question (summary):** How to delete PII that was sent as a person property (GDPR).

**What I tried:** Added a "Log in as pii-test-user-1" button calling `posthog.identify('pii-test-user-1', { email, phone })` with fake values. Logged out, logged in as that user and clicked "Say hello" button (21:10 on 26 Nov 2026).

**What I saw:** In PostHog UI, the person page Properties tab shows `email` and `phone` values. The `$identify` event's normal properties don't show them, but the "Person properties" passed into the `$identify` event do contain them.

**Deleting the property** Deleted `phone` from the person, using the bin icon on the Properties tab. It disappeared immediately from the person profile, but the old `$identify` event still had it under Person properties. I then logged out and back in as the same user, and the new `$identify` sent `phone` again.

**Deleting the person:** I clicked "Delete person" (21:37 on 26 Nov 2026), with events and recordings included. The person page then showed "Person not found" straight away. The events were still in Activity, still with `email` and `phone` in Person properties. 

**Deletion status checks:** The PostHog docs describe checking deletion status through the API. The PostHog AI chat also suggested the API endpoint `GET /api/projects/<project_id>/persons/deletion_status/`, but its example was a bash `curl` command for the US cloud, so it wouldn't work as-is in PowerShell or on my EU project. Steps I took:
1. Created a personal API key (`phx_`) in PostHog with read-only access to persons.
2. Saved the key and project ID in `posthog/.env`, and checked it's git-ignored with `git check-ignore -v posthog/.env`.
3. Ran [check-deletion.ps1](check-deletion.ps1), which reads `.env` and calls `https://eu.posthog.com/api/projects/<project_id>/persons/deletion_status/`.

Result on 26 Nov 2026:
```json
{
    "count":  1,
    "next":  null,
    "previous":  null,
    "results":  [
                    {
                        "person_uuid":  "61151221-df9b-5c6f-813d-13e37cc737cf",
                        "created_at":  "2026-11-26T21:37:10.472969Z",
                        "status":  "pending",
                        "delete_verified_at":  null
                    }
                ]
}
```
What this means: there is one deletion request, created at 21:37 when I clicked "Delete person". The person itself is already gone, but its events are still `pending`. `delete_verified_at` is empty, so they haven't been deleted yet. According to the docs: events are deleted asynchronously in scheduled batches, with a cutoff two days before each batch. 

Follow-up checks: (add the date, status, `delete_verified_at`, and whether the 21:10 events are still in Activity)

**Docs used:** https://posthog.com/docs/privacy/data-deletion, https://posthog.com/docs/product-analytics/person-properties

## Experiment 2: Client rate limiting
**Question (summary):** Client-side rate limit warning when tracking a video player. What's the limit, and can it be raised?

**What I tried:** Added a "Fire 500 events" button that calls `posthog.capture('rate_test', { n: i })` 500 times in a loop. Ran it with the default settings, then again with `rate_limiting: { events_per_second: 50, events_burst_limit: 600 }` in `posthog.init`.

**What I saw:** 
- Defaults: 101 of 500 were sent, and the Console showed 174 + 225 red "This capture call is ignored due to client rate limiting" lines (101 + 399 = 500). About 100 went at once (the burst), and 1 more after a token refilled during the loop.
- Raised limits: Local Storage showed the bucket full. All 500 were sent with no warnings. 

**Video simulation:** A fake player "plays" a 60-second video in 15 seconds, firing `timeupdate` 20 times a second (300 ticks). I tracked it three ways, with the default limits:
- Every `timeupdate`: 247 of 300 `video_timeupdate` arrived (expected ~250 = 100 burst + 10/s × 15s). Once the bucket was empty, every other event was dropped (the `position` property went from 0.2 steps to 0.4 steps), and a `$$client_ingestion_warning` was sent each time.
- Milestones (25/50/75/100%): 4 `video_progress`, no errors.
- Throttled (once per 5s of video): 12 `video_heartbeat`, no errors.

**Docs used:** https://posthog.com/docs/product-analytics/troubleshooting#why-do-i-see-this-capture-call-is-ignored-due-to-client-rate-limiting, https://posthog.com/docs/libraries/js/config, posthog-js source (rate-limiter.ts)

## Experiment 3: Weekday breakdown
**Question (summary):** Breaking down an insight by day of the week.

**What I tried:** Sent 104 fake `weekday_test` events with past timestamps over 4 weeks (30 Oct – 26 Nov 2026) in one request to the `/batch/` capture endpoint ([weekday-batch.json](weekday-batch.json)). Wednesday was the busiest day on purpose, and four events were near midnight UTC (Sun 23:30/23:45, Tue 00:30/00:45). Built a Trends insight on `weekday_test` (Last 30 days, Table view) with an SQL breakdown:
- `toDayOfWeek(timestamp) AS weekday` (a number)
- `dateName('weekday', timestamp) AS weekday` (a name)
- `concat(toString(toDayOfWeek(timestamp)), ' - ', dateName('weekday', timestamp)) AS weekday` (e.g. "3 - Wednesday", so it sorts Monday → Sunday)
- The same with `toTimeZone(timestamp, 'America/New_York')` to test time zones.

**What I saw:** 
- The totals matched what I sent: Mon 19, Tue 14, Wed 33, Thu 15, Fri 7, Sat 5, Sun 11.
- `toDayOfWeek` counts Monday = 1 to Sunday = 7 (Wednesday was 3). That stayed the same even though my project's "week starts on" setting is Sunday.
- `dateName('weekday', ...)` gives the full name, but names sort alphabetically, so I added the number in front.
- Project time zone is UTC. In New York time, the two Tuesday 00:30/00:45 UTC events moved to Monday evening (Mon 21, Tue 12), as I predicted. So the same event can land on a different weekday depending on the time zone.

**Docs used:** https://posthog.com/docs/product-analytics/trends/breakdowns, https://posthog.com/docs/sql/expressions, https://posthog.com/docs/api/capture