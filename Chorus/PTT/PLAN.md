# Chorus PTT — plan and progress

Lead: Claude Code. Workers: GitHub Copilot CLI (main), agy (fallback).
Tasks live in `Chorus/PTT/tasks/`. Branch: `ptt`.

## Checklist
- [x] Fork ptt3199/Chorus, clone, `upstream` remote, `ptt` default branch — lead
- [x] Split app (bundle id, product name, store folders, no store adoption, Sparkle out, workflows) — lead
- [x] Contract API in `Chorus/PTT/Core/` (TODO bodies) — lead
- [x] 01 link rules + tests — Copilot (1st try; reviewed, Core builds)
- [x] 02 URL rewriting + tests — Copilot (1st try)
- [x] 03 Chrome profiles + tests — Copilot (1st try)
- [x] 04 resolver, log, service profiles + tests — Copilot (1st try)
- [x] Runtime layer (`Chorus/PTT/App/`: rule file store, link service, hooks, web view menu) — lead
- [x] Hooks into author files + `HOOKS.md` — lead
- [x] 05 Settings tab UI — Copilot (1st try; compile pending)
- [x] Edit Service profile picker — Copilot, in task 05
- [x] 06 scripts (install, update-from-upstream) + README section — Copilot (README rule example fixed by lead)
- [ ] Full build + tests (Debug), CI green — lead
- [ ] Install via `scripts/install-ptt.sh`, `REPORT.md` — lead

## Notes
- No Xcode on the machine at the start; Xcode install started (needs the user's password). Until then, builds and tests run on CI.
- `scripts/ptt-core-tests` is a SwiftPM package that symlinks Core and the PTT tests, so Core compiles without Xcode.
