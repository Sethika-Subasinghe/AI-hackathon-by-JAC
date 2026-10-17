# CareRoute

AI agents that find the nearest hospital with free beds, and clear the way in a critical emergency.

Built for the Jaseci Labs AI Hackathon 2026 (University of Moratuwa, 17 October 2026).

> **Not a medical diagnosis.** CareRoute helps with urgency and hospital choice only. In a real emergency call **1990** (Suwa Seriya ambulance service). All hospital data in this demo is fake.

## The problem
In an emergency, families don't know which hospital has free beds or the right unit, and hospitals get no warning before a patient arrives. Time is lost driving to a full hospital or waiting in traffic.

## Demo
- Demo video: _TODO: add link_
- Live app (Jac Hammer): _TODO: add link_
- The responsive CareRoute shell is ready with Patient, Hospital and Clinic workspaces; the workflow screens are being added task by task.

## What it does
A patient or family describes the condition (and can upload a medical PDF), shares their location, and a team of AI agents finds the best hospital with free beds nearby, public or private. If the case is critical, CareRoute also requests an ambulance, asks police to clear the route, and alerts the hospital so the team is ready on arrival. Clinic patients get reminders for their clinic date.

## Features
- **Triage:** rates urgency (critical / urgent / stable) and the care needed, such as cardiac, trauma or ICU
- **Best-hospital matching:** ranks hospitals by unit, free beds and travel time, with alternatives and the reason each ranked lower
- **Emergency SOS button:** one tap, no typing. The phone shares its location, the nearest hospital with a free bed (public or private) is picked, and an ambulance, police route clearance and a hospital alert go out after a 3-second cancel window (simulated in this demo)
- **Emergency dispatch (critical only):** ambulance request, police route clearance and a hospital pre-arrival alert, sent after a 10-second countdown the patient can cancel (simulated in this demo)
- **Hospital dashboard:** hospital staff log in to update bed availability and see incoming-patient alerts they can accept or decline
- **Clinic reminders:** in-app notice and email for clinic dates, with a suggested arrival time
- **Surgery waiting lists:** patients choose a planned surgery (cataract, hernia, knee replacement and more) and see the hospital with the shortest expected wait near them, then join its list; hospitals keep their waiting counts up to date
- **Medical PDF upload (optional):** key facts are extracted and passed to triage
- **Live agent timeline:** every agent step, tool call and decision is shown to the user as it happens
- **Automatic re-planning:** if a hospital declines or is full, the agents pick the next best hospital and re-dispatch

## Agents
| Agent | Job |
|---|---|
| Orchestrator | Decides the next step for each case, asks follow-up questions and calls the other agents |
| Triage | Reads the description and report, returns severity, required unit and red flags |
| Hospital Matcher | Queries hospitals and Geoapify routes, picks the best match and alternatives |
| Emergency Dispatch | Creates ambulance, police and hospital alerts for critical cases |
| Clinic Reminder | Schedules reminders and suggests arrival times |
| Document | Extracts and summarises key facts from the uploaded PDF |
| Re-plan | If a hospital declines or is full, re-matches and re-dispatches to the next best |

## Tech stack
- **Jac / Jaseci** (80%+ of the code): backend, agents (`by llm()`) and frontend (`jac-client`)
- **LLM:** free-tier API (Gemini or Groq)
- **Geoapify:** geocoding, routing and maps
- **Email:** mock email in the app, real email as a stretch
- **Hosting:** Jac Hammer sandbox

## Setup
**Requirements:** Python 3.13, Jaseci (`jaseci`), a free LLM API key, and a Geoapify API key.

```bash
git clone <repo-url>
cd careroute
pip install jaseci             # includes jaclang, byllm, jac-client and jac-mcp
cp .env.example .env           # then add your keys
```

`.env` (names are placeholders):
```
LLM_API_KEY=your-key
GEOAPIFY_API_KEY=your-key
```

## Usage
```bash
jac start main.jac
```

Open `http://localhost:8000`. Use the Patient, Hospital and Clinic tabs to switch between the current workspace placeholders. The medical safety banner remains visible throughout the app.

0. **Emergency (no typing):** on the Patient tab tap the big red **Emergency: get help now** button and allow location access. CareRoute finds the nearest hospital with a free bed, asks for an ambulance and police route clearance, and shows the live status. You have 3 seconds to cancel if you tapped by mistake. If location is blocked it tells you to allow it, type an address, or call 1990.
1. **Patient:** open the app, describe the condition, share your location (optional PDF), and view the recommended hospital and alternatives. For a critical case, a 10-second countdown starts and you can tap Cancel to stop the dispatch.
2. **Hospital staff:** log in with a demo account _(TODO: add credentials)_, update bed availability, and accept or decline incoming-patient alerts.
3. **Clinic patient:** enter the clinic, date and condition to get a reminder.

## Project structure
```
careroute/
├── main.jac                 # full-stack entry point
├── frontend.cl.jac          # Jac client shell and workspace views
├── frontend.impl.jac        # client interaction implementation
├── components/              # reusable Jac client components
├── assets/theme.css         # design tokens and responsive presentation
├── models.jac               # shared graph model and types
├── hospitals.jac            # hospital services
├── sos.jac                  # one-tap emergency SOS flow
├── agent_log.jac            # agent event helpers
├── data/                    # fake Sri Lanka hospital dataset
├── plan.md                  # project plan
├── progress.md              # shared task board
└── skill.md                 # Jac and UI/UX conventions
```

## Next steps
- Replace simulated ambulance and police integration with real services (for example 1990 Suwa Seriya and traffic police)
- Live bed data from real hospital systems instead of manual updates
- Real email and SMS reminders
- Sinhala and Tamil language support
- Clinical review of the triage logic before any real-world use

## Team
Sethika (Codex), Akeesha (Codex) and Dimuth (Claude Code)
