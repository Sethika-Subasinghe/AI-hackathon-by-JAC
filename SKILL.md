# skill.md: CareRoute agent and UI skills

For every coding agent on the team. Read with `plan.md`, `README.md` and `progress.md`.
**Priority 1: agentic behaviour** (built with Jac `by llm()`). **Priority 2: polished UI/UX** that makes the agent work visible.

## Decisions that refine plan.md
- An **Orchestrator agent** decides the next step per case (not a fixed pipeline).
- Critical dispatch uses a **10-second countdown with Cancel** (replaces "confirm before dispatch").
- **Re-planning:** if the chosen hospital declines or runs out of beds, agents re-match and re-dispatch automatically.
- Memory: per-case state, plus a saved **profile for clinic patients only**.
- **Surgery waiting lists (T33):** plain Jac functions and graph nodes, no model. Expected wait in weeks = patients waiting / operations per week; hospitals are ranked by wait plus 0.1 week per km. Patient side: `SurgeryPlanner`; hospital side: `SurgeryLists` in the dashboard.
- English only. Responsive on phone, tablet and PC. Medical theme (see Part B).

## Jac-first rules (competition requirement: at least 80% Jac)
- **At least 80% of the code must be Jac.** Backend, agents, data models, hospital data seeding and the frontend (`jac-client`) are all written in Jac.
- **Allowed non-Jac (stay well under 20%):** the small pypdf PDF extractor, minimal CSS and static assets, config files. Before writing any Python or JS, check whether Jac can do it. Jac supersets Python and can import Python libraries.
- Don't commit generated bundles, `node_modules`, large JSON dumps or vendored files. They distort the language share.
- Ask the Jaseci staff on-site how the 80% is measured (lines of code or GitHub language stats). Check the share at midday and at 4:00 PM (see `progress.md`).

## Jac tooling for the coding agents (use it, don't guess syntax)
Install everything with `pip install jaseci` (includes `jaclang`, `byllm`, `jac-client` and `jac-mcp`). Check with `jac --version`.

| Agent | Setup |
|---|---|
| **Codex** | Register the Jac MCP server: `codex mcp add jac -- jac mcp`. A project-local alternative is `.codex/config.toml` (see docs.jaseci.org/reference/mcp). |
| **Claude Code** | Register the Jac MCP server: `claude mcp add jac -- jac mcp`. Also load Jac skills: `jac guide --export .claude/skills`, and commit `.claude/skills/` so everyone gets the same guidance. The team's own Jac skill file, uploaded during the session, goes in `.claude/skills/` too. |

**Rules for every agent:**
1. Tell your agent at the start: "Use the jac MCP tools; validate and lint all Jac code before showing or committing it."
2. Use the MCP tools (validate, lint, format, run, explain compiler errors, search docs) instead of guessing syntax. If the model's context is tight, use `jac mcp --mode lite`. Check what is available with `jac mcp --inspect`.
3. Read the matching guide before each task: `jac-by-llm` for agents, `jac-walker-patterns` for graph and walkers, the `jac-cl-*` guides for the UI. If MCP is unavailable, use `jac guide` or docs.jaseci.org.
4. Never replace Jac code with Python or JS to get unblocked. Log it in `progress.md` as Blocked and ask a teammate or the Jaseci staff.

---

# Part A: Agentic skills

## A0. Conventions (apply to every agent)
**Purpose:** one consistent way to build LLM-backed agents in Jac.
**How:**
- Model setup (verify syntax at docs.jaseci.org/learn/jac-byllm/usage or with the Jac MCP): `pip install jaseci` (includes `byllm`), then
```jac
import from byllm.lib { Model }
glob llm = Model(model_name="gemini/gemini-2.0-flash");   # or a Groq model; key via env var (LiteLLM)
```
- **Typed outputs:** every agent returns an `obj`/`enum`, never free text, so the next step can use it.
```jac
enum Severity { CRITICAL, URGENT, STABLE }
obj TriageResult {
    has severity: Severity, unit: str, red_flags: list[str],
        confidence: float, needs_followup: bool, followup_question: str;
}
def triage(description: str, report_summary: str) -> TriageResult by llm();
```
- Add `sem` annotations on fields and tools so the model knows allowed values (e.g. `unit` is one of cardiac, trauma, icu, neuro, general). Verify the `sem` syntax in the docs.
- **Tools** are plain Jac functions with clear names and docstrings: `def agent(...) -> T by llm(tools=[tool_a, tool_b]);`
- Low `temperature` (0 to 0.3) for triage and matching. Keep prompts short and pass a compact state, not the whole history.
- Every agent step writes an `AgentEvent` (see A8) before and after it runs.

## A1. Orchestrator Agent
**Purpose:** the "brain" that chooses what happens next for each case.
**Use when:** a case is created, and after every agent step.
**Goal:** reach a safe, useful outcome (hospital chosen, and for critical cases dispatch done) in as few steps as needed.
**Tools / skills it can call:** Document, Triage, Matcher, Dispatch, Re-plan, ask follow-up.
**Decides:** read the PDF only if one exists; ask a follow-up if triage confidence is low; skip dispatch unless severity is critical; re-plan when a hospital declines.
**Autonomy:** runs all steps on its own; the only human gate is the Cancel button during the dispatch countdown.
**Implement:**
```jac
enum Step { ASK_FOLLOWUP, READ_DOCUMENT, TRIAGE, MATCH, DISPATCH, REPLAN, FINISH }
obj NextAction { has step: Step, reason: str; }
def decide_next(state: CaseState) -> NextAction by llm();
```
```
loop (max 8 steps):
    action = decide_next(compact(state))      # by llm()
    action = guard(action, state)             # deterministic rules can veto or override
    log_event(action)                         # shows in the UI timeline
    state  = run(action)                      # calls the matching agent skill
    if action.step == FINISH: break
```
`guard` rules: DISPATCH only if severity is CRITICAL and a hospital is matched; never TRIAGE twice without new input; stop at max steps and return the best result so far.

## A2. Triage Agent
**Purpose:** rate urgency and the care needed. Never diagnose.
**Use when:** after the description (and PDF summary) exist, or when a follow-up answer arrives.
**Tools:** none required (pure `by llm()` with a typed result). Optional: `red_flag_check`.
**Decides:** severity, required unit, red flags, confidence; asks one short follow-up if input is too vague (`needs_followup`).
**Errors / safety:**
- **Safety override in code:** a keyword and rule list (chest pain, unconscious, severe bleeding, stroke signs, breathing difficulty) can raise severity but the LLM can never lower it below the rule result.
- Invalid or failed output: retry once, then fall back to rule-based severity.
**Implement:** the `triage` function in A0 + `red_flag_override(result, text)`.

## A3. Document Agent
**Purpose:** turn an uploaded PDF into key medical facts for triage.
**Use when:** the patient attached a PDF.
**Tools:** `extract_pdf_text(path)` (Python, pypdf).
**Decides:** which facts matter (conditions, allergies, medicines, recent events); ignores the rest.
**Errors:** unreadable or scanned PDF → timeline shows "Couldn't read the report, continuing with your description" and the flow goes on.
**Implement:** `def summarise_report(text: str) -> ReportSummary by llm();` with a short, structured `ReportSummary`.

## A4. Hospital Matcher Agent
**Purpose:** pick the best hospital with free beds and explain why.
**Use when:** triage is done, or when re-planning.
**Tools:** `find_hospitals(unit, min_beds)`, `get_eta(hospital_id, origin)` (Geoapify), `score_hospital(...)` (deterministic: unit fit, free beds, ETA, sector).
**Decides:** which tools to call, how to weigh trade-offs (critical → speed and ICU/emergency capacity first; stable → also sector and load), and the one-line reason for each alternative.
**Autonomy:** fully automatic.
**Errors:** Geoapify fails → straight-line distance estimate, labelled "Estimated"; no hospital has beds → return the nearest with the shortest wait and say so.
**Implement:**
```jac
obj MatchResult { has best: HospitalPick, alternatives: list[HospitalPick], summary: str; }
def match_hospitals(triage: TriageResult, origin: Location) -> MatchResult
    by llm(tools=[find_hospitals, get_eta, score_hospital]);
```
Keep a deterministic ranking as the fallback so the demo never breaks.

## A5. Emergency Dispatch Agent (critical only)
**Purpose:** get help moving: ambulance, police route clearance, hospital pre-alert.
**Use when:** severity is CRITICAL and a hospital is matched.
**Tools:** `create_ambulance_request`, `create_police_request(route)`, `send_hospital_alert(case_summary, eta)` (all simulated and labelled "Simulated").
**Decides:** the priority level and the message content for each recipient (short, factual, no diagnosis).
**Autonomy:** starts a **10-second countdown**; auto-sends when it hits zero unless the patient taps Cancel.
**Errors:** each action is idempotent (never sent twice) and logged; if one fails, retry once, show the failure in the timeline and continue with the rest.
**Implement:** `def draft_dispatch_messages(case: CaseState) -> DispatchPlan by llm();` then plain Jac functions that create `Request` nodes for ambulance, police and hospital.

## A5b. Emergency SOS (T33)
**Purpose:** for someone who cannot type. One tap on the big red button (Patient tab) starts a critical case.
**Flow:** browser geolocation -> `start_sos(lat, lon)` creates a CRITICAL case (unit GENERAL, red flag "Emergency button pressed") -> `run_sos(case_id)` runs the Matcher without waiting for the model (parallel road lookups, template reasons) -> `start_dispatch(cs, SOS_CANCEL_SECONDS, False)` sends ambulance, police route clearance and hospital alert after a **3 s** Cancel window. The UI then polls the normal endpoints (`get_case`, `case_events`, `get_match`, `get_dispatch`).
**Safety:** the cancel window stays so an accidental tap can be stopped; set `SOS_CANCEL_SECONDS = 0.0` for instant sending. Location denied -> never guess a place, tell the user to allow location, type an address or call 1990. Everything is simulated and labelled.

## A6. Re-plan Agent
**Purpose:** recover when the plan breaks. This is the main agentic demo moment.
**Use when:** the hospital taps **Decline**, bed count drops to 0, or no response within the timeout (demo: about 20 s).
**Decides:** exclude that hospital, re-run the Matcher, re-dispatch to the next best, and tell the user why.
**Implement:** Orchestrator step `REPLAN` → Matcher (with `exclude=[id]`) → Dispatch again. The timeline shows "Hospital full → re-matching → new hospital alerted".
**Limits:** max 3 re-plans, then show the best remaining options and advise calling 1990.

## A7. Clinic Reminder Agent
**Purpose:** remind clinic patients and suggest when to arrive.
**Use when:** a clinic patient saves a clinic date, and when a reminder is due.
**Tools:** `get_hospital_load(hospital_id)`, `schedule_reminder`, `send_inapp_notice`, `send_email` (mock: writes to an in-app inbox).
**Decides:** best arrival time from hospital load, reminder timing (day before and morning of), and the email text (`by llm()`).
**Memory:** saved `ClinicPatient` profile (name, email, clinic, date, condition note).
**Demo:** add a **"Skip time"** button so reminders can be shown live.
**Implement:** `def compose_reminder(patient: ClinicPatient, tip: str) -> EmailDraft by llm();`

## A8. Agent Event Log (powers the visible timeline)
**Purpose:** make every agent action observable by the UI.
**Implement:** an `AgentEvent` node per step:
`case_id, agent, step, status (running | done | failed | waiting), title, detail (inputs, tools called, reason, confidence), timestamp`.
Write `running` before a step and `done` or `failed` after. The frontend polls events for the case about once a second (switch to streaming only if time allows).

## A9. Memory and context
- **Per-case:** a `CaseState` node holds input, PDF summary, triage, matches, decisions, events. All agents read and write it through the graph.
- **Clinic patients:** `ClinicPatient` profile node only. No profiles for emergency users.
- **Context hygiene:** pass `compact(state)` to the LLM (latest facts only).
- **Cache:** by hash of description + location, to save free-tier calls.

## A10. Reliability and guardrails
- Per-call timeout (about 15 s), retry once, then a deterministic fallback.
- A "Using backup logic" banner in the UI when a fallback was used.
- Canned results for the two demo scenarios as a last resort.
- Never output a diagnosis. Disclaimer always visible. Everything simulated is labelled.

---

# Part B: UI/UX skills

## B1. Design direction
**Style:** calm, trustworthy medical look for patients; a dark "ops" look for hospital and dispatch panels. Clean, spacious, fast. Show the agent work, not just the answer.

| Token | Value |
|---|---|
| Primary (teal) | `#0F766E`, light `#14B8A6` |
| Background / surface | `#F6FAFA` / `#FFFFFF` |
| Text / muted | `#0F172A` / `#64748B` |
| Critical / urgent / stable / info | `#DC2626` / `#F59E0B` / `#16A34A` / `#2563EB` |
| Ops dark bg / surface | `#0B1220` / `#111A2E` |

- **Type:** Inter (or Plus Jakarta Sans). 16px body, 24 to 32px headings, tabular numbers for ETAs and beds.
- **Shape:** 8px grid, 12 to 16px radius, soft shadows, one accent colour. Red is reserved for critical.
- Tap targets at least 44px. Contrast WCAG AA. Severity is never colour alone (icon + label).

## B2. Layout and responsiveness
- **Mobile (default):** one column, stepper "Describe → Locate → Result", sticky safety bar ("Not a diagnosis · Call 1990"), agent timeline in a collapsible bottom sheet showing the latest step.
- **Tablet and PC:** two columns: left = form and result cards; right = map and agent timeline.
- **Hospital dashboard:** desktop-first dark layout (side nav, bed cards, incoming alerts) that stacks cleanly on phones.
- Test at 360, 768 and 1280 px. No horizontal scroll.

## B3. Component kit (build once, reuse)
SafetyBanner · SeverityBadge · HospitalCard (name, public/private chip, ETA, beds by unit, "Best match", why-text) · AlternativesList · MapPanel (Geoapify tiles, markers, route line, moving ambulance marker) · **AgentTimeline** · CountdownBanner · BedStepper (+/- per unit) · AlertCard (Accept / Decline) · EmailPreview · Toast · Skeleton · EmptyState.

## B4. Making agent actions visible (key skill)
- Vertical **AgentTimeline**: icon per agent, plain-language title ("Checking 6 hospitals with cardiac beds"), status (spinner / check / warning / waiting), time.
- Steps animate in as events arrive. Hand-offs between agents are shown explicitly.
- Each step is **expandable**: inputs, tools called, reasoning, confidence. Raw JSON only behind a "Show raw" toggle.
- Re-planning is highlighted ("Hospital declined → re-matching"). Simulated actions carry a "Simulated" tag.
- Use `aria-live="polite"` so screen readers follow progress.

## B5. Key flows
- **Patient:** description box with example chips, location button + address field (Geoapify autocomplete), optional PDF drop zone → timeline runs → result card with map.
- **Critical:** a red banner takes over: "Critical case. Dispatching in 10…" with a ring countdown and a big Cancel button, then a live status of ambulance, police and hospital.
- **Hospital:** log in → bed steppers with colour thresholds (green, amber, red) → incoming alerts with ETA and Accept / Decline.
- **Clinic:** a short form → saved profile → reminder card + email preview.

## B6. Interaction and feedback states
Skeletons while loading · streamed timeline steps · success confirmation · inline validation · friendly errors with Retry · "Using backup logic" banner · disabled-while-working buttons · toasts for hospital updates · respects `prefers-reduced-motion`. Microcopy: calm, short, no jargon.

## B7. Demo polish
"Load demo scenario" buttons (chest pain, clinic patient) · "Reset demo data" · "Skip time" · clean empty states · app name and logo in the header · favicon.

---

# Part C: Build order and checks

| plan.md feature | Skills |
|---|---|
| 1-2 Data, hospital login, bed dashboard | A9 (nodes), B3 BedStepper, B5 hospital |
| 3-4 Patient form, Triage | A0, A2, B5 patient |
| 5-6 Matcher, map, alternatives | A4, B3 MapPanel/HospitalCard |
| 7 Critical flow | A1, A5, A6, B4, B5 critical |
| 8 Clinic reminders | A7, B5 clinic |
| 9 PDF | A3 |
| 10 Polish | A8, A10, B6, B7 |

Build **A8 + AgentTimeline early** (right after the Triage Agent): it makes every later agent visible for free.

**Judge checklist (from the hackathon PDF):**
- [ ] Agentic depth: Orchestrator decisions, tool calls, re-planning, follow-up questions are all visible in the timeline
- [ ] Jac/Jaseci use: `by llm()` with typed outputs and tools, graph nodes, walkers/persistence, 80%+ Jac, all code validated with the Jac MCP
- [ ] Technical execution: fallbacks, no crashes in the two demo scenarios
- [ ] Creativity and impact: re-plan moment, live countdown, map with moving ambulance
- [ ] Presentation: polished UI on phone and PC, demo video follows the two scenarios
