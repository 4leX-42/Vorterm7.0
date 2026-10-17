# EXAMPLE - 0001 - Certificate-based app-only authentication for unattended automation

> Example decision record. Adapt or delete it.

| Field | Value |
| :-- | :-- |
| Status | accepted |
| Date | 2026-01-05 |
| Deciders | ops-team@contoso.example |

## Context

Scheduled scripts need to read Microsoft 365 and Azure data without a person signing in.
Client secrets expire silently, are easy to copy into scripts and often end up in
repositories.

## Decision

Unattended automation uses an app registration with **certificate** credentials:

- The certificate lives in the machine or user certificate store, never in the LAB folder.
- The app gets only the application permissions each job needs, documented in its script
  header.
- Interactive admin work keeps using personal accounts with just-in-time elevation.

## Consequences

- Certificate renewal is a yearly task with its own runbook.
- Scripts reference the certificate by thumbprint from `config/lab.json` (git-ignored).
- Losing the machine store means re-issuing the certificate; no secret to rotate in code.
