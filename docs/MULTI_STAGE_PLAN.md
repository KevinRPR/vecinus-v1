# Multi-Stage Plan (Web + Mobile)

## Stage 0 - Baseline and measurement (Week 1)
- Goal: define the premium quality bar and measure real usage from day 1.
- Deliverables:
  - Quality bar and journey map (already in docs).
  - Event schema for the 3 journeys.
  - Basic dashboard: success rate, time to value, errors.
  - QA matrix for web + mobile devices/browsers.
- Exit criteria:
  - Events firing for all 3 journeys.
  - Crash reporting enabled for mobile.
  - Release gate checklist defined.

## Stage 1 - Premium UX polish (Weeks 2-4)
- Goal: make the app feel premium in every screen and action.
- Deliverables:
  - Unified design system (type scale, spacing, icon family).
  - Copy cleanup and no mojibake.
  - Motion polish (page transitions, list stagger, feedback).
  - Accessibility baseline (44dp targets, labels for icon-only).
  - Skeletons and empty states in critical lists.
- Exit criteria:
  - Consistent visuals across all core screens.
  - A11y checks pass for core flows.

## Stage 2 - Reliability and performance (Weeks 4-6)
- Goal: speed, stability, and graceful recovery across network issues.
- Deliverables:
  - Cache with TTL for critical data.
  - Timeouts + retry strategy + clear error states.
  - List virtualization for large datasets.
  - Reduce heavy blur/shadows on low-end devices.
- Exit criteria:
  - p95 API <= 1.5s and no infinite spinners.
  - Smooth scroll on mid-range devices.

## Stage 3 - Trust and secure sessions (Weeks 6-8)
- Goal: frictionless but secure access and report flows.
- Deliverables:
  - Refresh token flow end-to-end.
  - Secure storage for sessions.
  - Unlock flow with biometrics/PIN with fallback.
  - Idempotent report payment submissions.
- Exit criteria:
  - No forced re-login for valid sessions.
  - Duplicate report payment submissions prevented.

## Stage 4 - Delight and expansion (Weeks 8-10)
- Goal: premium touches that increase trust and engagement.
- Deliverables:
  - Push notifications (announcements, reminders).
  - Digest or summary view for novedades.
  - Downloadable receipts and history improvements.
  - Web parity for core flows.
- Exit criteria:
  - Users can complete all 3 journeys on both web and mobile.
  - Engagement uplift from notifications.

## Notes
- Stages can overlap, but keep one clear owner per stage.
- If timelines are tight, prioritize Stage 0 + Stage 1 + Stage 2.
