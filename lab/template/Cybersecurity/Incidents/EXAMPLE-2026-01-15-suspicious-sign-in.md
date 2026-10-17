# EXAMPLE - 2026-01-15 - Suspicious sign-in from an unfamiliar country

> Fictitious example to show the format. Every name, address and value is invented
> (contoso.example, documentation IP ranges). Delete this file when you have real records.

| Field | Value |
| :-- | :-- |
| Status | closed |
| Severity | medium |
| Owner | analyst@contoso.example |
| Opened / closed (UTC) | 2026-01-15 08:12 / 2026-01-15 10:40 |
| Verdict | benign (confidence: high) |

## Summary

An "unfamiliar sign-in properties" alert fired for `user01@contoso.example` from
`203.0.113.45`. The user was travelling and signed in from a hotel network with MFA.

## Facts

1. Alert raised 08:05 UTC by the identity protection policy (source: alert record).
2. Sign-in at 08:03 UTC from 203.0.113.45, MFA satisfied with the registered app
   (source: sign-in log, exported to `evidence/2026-01-15-signin.csv`).
3. No other sign-ins from that address in the tenant in the last 30 days (query
   `Cybersecurity/Queries/EXAMPLE-failed-sign-ins.kql`, adapted).
4. The user's manager confirmed the trip by phone at 09:50 UTC.

## Indicators

| Type | Value | Seen where |
| :-- | :-- | :-- |
| IP | 203.0.113.45 | sign-in log |

## Hypotheses

- H1 legitimate travel: supported by facts 2 and 4.
- H2 token theft: not supported (MFA performed interactively, no new device or app consent).

## Missing evidence

- Hotel network ownership was not verified.

## Timeline (UTC)

| Time | Event |
| :-- | :-- |
| 08:03 | Sign-in from 203.0.113.45 |
| 08:05 | Alert raised |
| 08:12 | Record opened |
| 09:50 | Manager confirms travel |
| 10:40 | Closed as benign |

## Actions

| Action | Proposed / executed | Rollback |
| :-- | :-- | :-- |
| None required | - | - |

## Verdict

Benign, confidence high. It would change if a second sign-in appeared from a different
country within the travel window, or if MFA had been satisfied by SMS on a new number.

## Lessons learned

- Added a note to the identity runbook: check the travel calendar before escalating
  unfamiliar-location alerts with interactive MFA.
