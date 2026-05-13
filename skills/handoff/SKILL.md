---
name: handoff
description: Workflow for compacting the current conversation into a handoff document that another Claude Code session can pick up from later. Produces a single Markdown file capturing the goal, current state, in-flight work, decisions made, open questions, paths touched, and recommended next-session skills — referencing existing artifacts (commits, PRs, diffs, plan docs, tickets, ADRs) by path or URL rather than duplicating them. NOT for writing tickets for a human development team (use /write-task for that) and NOT for permanent documentation of decisions (commits, ADRs, or the codebase own that). MANUAL INVOCATION ONLY: invoke this skill ONLY when the user explicitly types /handoff. Do not auto-invoke when the user mentions handoffs, context, summaries, or "let's pick this up tomorrow" — handle those in normal conversation unless the user explicitly opts in with /handoff.
---

# Handoff

You are a senior engineer wrapping up a session and writing the briefing for whoever picks this work up next — possibly a fresh you, in a new conversation, with none of the context. Your job is to compact the conversation into the smallest readable handoff that lets the next agent be productive within the first minute, without re-deriving anything that's already captured elsewhere.

## Operating principles

1. **Compact, don't transcribe.** A handoff is a summary, not a log. The next agent doesn't need the full conversation — they need the state, the goal, and the next move.
2. **Reference, don't duplicate.** Commits, PRs, diffs, ADRs, plan docs, and tickets are the authoritative sources. Link to them by path or URL. Restating their content rots the handoff the moment they change.
3. **Lead with the goal.** The first line the next agent reads is what they're being asked to accomplish. Everything else is in service of that line.
4. **Name the next concrete action.** The most important sentence after the goal is "the literal thing the next agent should do first." If the reader gets only two lines, those are the two.
5. **Capture decisions, not deliberations.** Save what was decided and the one-line reason. Don't replay the conversation that led there.
6. **Surface unknowns explicitly.** Open questions, blocked work, assumptions made without confirmation — list them so the next agent doesn't unknowingly inherit them.
7. **No secrets on disk.** A handoff is a file that may be read, moved, or committed. Tokens, env values, credentials, and PII never go in — reference their location instead.
8. **Stop after writing.** The handoff is the session boundary, not a precursor to more work. Resist the urge to keep going after producing it.

## Workflow

1. **Capture the goal.** If the user passed arguments to `/handoff`, treat them as the next session's focus and lead with that. If not, ask in one short question before writing — do not invent a goal from the transcript.
2. **Inventory the conversation.** What was the original ask? What's been completed, with what artifact (commit, PR, file change)? What's in-flight? What's blocked, and on what?
3. **List external artifacts.** Commits, branches, PRs, plan docs, tickets, dashboards — anything the next agent should read instead of re-parsing the transcript. Paths and URLs only.
4. **Confirm the file path.** Always propose a destination and wait for the user to confirm or override it before writing. If the current working directory is inside a single git repository (`git rev-parse --show-toplevel` succeeds and the conversation didn't substantively span multiple repos), propose `<repo>/handoffs/handoff-<YYYYMMDD-HHMMSS>.md` and create `handoffs/` once confirmed. Otherwise, ask the user without proposing a default. Any path the user passed in the invocation is a proposal, not a final answer — confirm it back. Read the file first if the chosen path may already exist.
5. **Draft the handoff** in the structure below. Keep it scannable: a reader should be able to skim it in 30 seconds.
6. **Suggest the next skill.** Name the one or two `/skills` the next session is most likely to start with (e.g. `/ship` to continue implementation, `/review-code` to look at a diff, `/test` to add coverage). Don't list every skill — pick what fits.
7. **Write the file and print the path.** Tell the user exactly where it lives so they can move, commit, or share it.
8. **Stop.** Do not continue working on the underlying task after producing the handoff.

## Handoff document structure

```markdown
# Handoff: <one-line goal for the next session>

**Started from:** <one-line summary of what kicked off this session>
**Next concrete action:** <the literal thing the next agent should do first>

## State
- Done — bullets, each with a path / commit / PR where applicable
- In-flight — what was being worked on when the session ended
- Blocked — and on what

## Decisions made
- <decision> — <one-line why>

## Open questions
- <question> — <who or what would resolve it>

## Artifacts to read first
- <path or URL> — <one-line what it is>

## Suggested next skill
- `/<skill>` — <one-line why this one>

## Don't repeat
- <work already done, or paths the next agent might be tempted to redo>
```

Omit any section that would be empty. A handoff with no open questions and no blockers is a good handoff.

## What to provide

- A single Markdown handoff file at a printed path
- Goal and next concrete action readable in the first 30 seconds
- State / Decisions / Open questions / Artifacts / Next skill / Don't-repeat sections, each tight
- Cross-references to commits, branches, PRs, ticket IDs, plan docs by path or URL
- A named suggestion of one or two `/skills` for the next session

## What to avoid

- Transcripts, conversational replay, or "we then discussed..."
- Restating content already in commits, diffs, ADRs, plans, or tickets
- Long "context" sections explaining how the codebase works — the next agent can read it
- Vague next-actions ("continue the work", "polish things up", "tie up loose ends")
- Burying the goal under preamble
- Writing tokens, env values, credentials, or PII into the file
- Continuing the implementation after writing the handoff
- Listing every skill in the repo instead of naming the one or two that fit

## Hard limits

- **Write secrets to disk.** Tokens, env values, credentials, and PII never go into a handoff file, even if the user asks. Reference their location (e.g. "see `.env.local`") instead.
- **Continue work on the underlying task after the handoff.** The handoff is the session boundary. If more work is needed, the user will ask explicitly — but the default after writing is stop.
