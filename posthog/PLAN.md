# Learning plan

## Goal
Get hands-on with PostHog and reproduce three
real customer questions. 

## Setup (done)
- Windows laptop, VS Code, PowerShell terminal, Git, Node v22.
- PostHog Cloud account created. Region: EU = https://eu.i.posthog.com; confirm in the project's snippet).
- No build tool: plain HTML with PostHog's HTML snippet, served with `npx serve`.

## Rules
- Fake data only. Project key (phc_) may be committed; personal API key (phx_) never: use a git-ignored .env.
- Ad blockers can hide events: check DevTools > Network if nothing arrives.
- After each experiment, fill in README.md: question, what I tried, what I saw, what I learned, docs links.

## Warm-up steps
- [x] 1. Hello PostHog: posthog/index.html with the HTML snippet + buttons calling posthog.capture(); see events in PostHog Activity. Learn: events, properties, autocapture, $pageview, debug mode, Network tab.
- [x] 2. People: fake "Log in" button calling posthog.identify('fake-user-1', { email: '...@example.com' }) and "Log out" calling posthog.reset(). Learn: distinct_id, anonymous vs identified, person profiles, person properties.
- [x] 3. Explore data: a Trends insight, the SQL editor, and one raw event's JSON.
- [x] 4. Send one event with curl to the capture API with a custom timestamp (check the current endpoint in the docs). Learn: SDKs are HTTP wrappers.

## Experiment 1: PII deletion (start early; deletion runs in the background and can take days)
Customer question (summary): how to delete PII that was sent as a person property (GDPR).
- [x] Identify a fake user with a fake email; capture a few events. Note the times.
- [x] Delete the property from the person. Check the person page AND old events: do they still contain it?
- [x] Queue deleting the person together with their events.
- [ ] Find where PostHog shows deletion status, and check back over the following days.

## Experiment 2: Client rate limiting
Customer question (summary): client-side rate limit warning when tracking a video player. What's the limit, and can it be raised?
- [x] Reproduce the warning by firing many events quickly (e.g. a "fire 500 events" button).
- [x] Find the defaults and the config option in PostHog's docs (and source, to confirm).
      Hint already found in posthog-js 1.455.1 source (lib/src/rate-limiter.js): option `rate_limiting`
      with `events_per_second` and `events_burst_limit`. Still find and link the DOCS page.
- [x] Change the limits and re-test.
- [x] Simulate a <video> firing timeupdate events; compare with milestone tracking (play, pause, 25/50/75/100%) and with throttling.

## Experiment 3: Weekday breakdown
Customer question (summary): breaking down an insight by day of the week.
- [x] Send events with past timestamps across the last 7 days (curl or a posthog-node script; check how old a timestamp can be).
- [x] Build a Trends insight broken down by a SQL expression for day of week.
- [x] Try a readable day name as well as a number.
- [x] Compare the project time zone with the UTC timestamps sent: can an event land on a different weekday?