# DevOps

Pipelines, Git conventions and container work that support the rest of the LAB.

| Folder | Contents |
| :-- | :-- |
| `Pipelines/` | CI/CD definitions (GitHub Actions, Azure DevOps) and their README: what runs, on which trigger, with which identity. |

Infrastructure as code for Azure lives in `Azure/IaC/`. Containers and other topics can
get their own folder when there is real content for them.

## Git conventions

- Small commits with a clear subject (`feat:`, `fix:`, `docs:`, `chore:`).
- Never commit secrets, exports or evidence; `.gitignore` covers the usual paths, but read
  `git status` before every commit.
- Pipelines authenticate with workload identity federation or managed identities, never
  with secrets stored in the repository.
