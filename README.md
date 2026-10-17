# CareRoute

AI agents that find the nearest hospital with free beds, and clear the way in a critical emergency.

Built for the Jaseci Labs AI Hackathon 2026 (University of Moratuwa, 17 October 2026).

> **Not a medical diagnosis.** CareRoute helps with urgency and hospital choice only. In a real emergency call **1990** (Suwa Seriya ambulance service). All hospital data in this demo is fake.

## The problem
In an emergency, families don't know which hospital has free beds or the right unit, and hospitals get no warning before a patient arrives. Time is lost driving to a full hospital or waiting in traffic.

## Demo
- Demo video: _TODO: add link_
- Live app (Jac Hammer): _TODO: add link_
- Screenshots: _TODO: add after the UI is built_

## What it does
A patient or family describes the condition (and can upload a medical PDF), shares their location, and a team of AI agents finds the best hospital with free beds nearby, public or private. If the case is critical, CareRoute also requests an ambulance, asks police to clear the route, and alerts the hospital so the team is ready on arrival. Clinic patients get reminders for their clinic date.

## Features
- **Triage:** rates urgency (critical / urgent / stable) and the care needed, such as cardiac, trauma or ICU
- **Best-hospital matching:** ranks hospitals by unit, free beds and travel time, with alternatives and the reason each ranked lower
- **Emergency dispatch (critical only):** ambulance request, police route clearance and a hospital pre-arrival alert, sent after the patient confirms (simulated in this demo)
- **Hospital dashboard:** hospital staff log in to update bed availability and see incoming-patient alerts
- **Clinic reminders:** in-app notice and email for clinic dates, with a suggested arrival time
- **Medical PDF upload (optional):** key facts are extracted and passed to triage

## Agents
| Agent | Job |
|---|---|
| Triage | Reads the description and report, returns severity, required unit and red flags |
| Hospital Matcher | Queries hospitals and Geoapify routes, picks the best match and alternatives |
| Emergency Dispatch | Creates ambulance, police and hospital alerts for critical cases |
| Clinic Reminder | Schedules reminders and suggests arrival times |
| Document | Extracts and summarises key facts from the uploaded PDF |

## Tech stack
- **Jac / Jaseci** (80%+ of the code): backend, agents and frontend
- **LLM:** free-tier API (Gemini or Groq)
- **Geoapify:** geocoding, routing and maps
- **Email:** mock email in the app, real email as a stretch
- **Hosting:** Jac Hammer sandbox

## Setup
> _TODO: confirm every command below once the project runs._

**Requirements:** Python 3.x, Jac (`jaclang`), a free LLM API key, a Geoapify API key.

```bash
git clone <repo-url>
cd careroute
pip install jaclang            # TODO: confirm package and extra dependencies
cp .env.example .env           # then add your keys
```

`.env` (names are placeholders):
```
LLM_API_KEY=your-key
GEOAPIFY_API_KEY=your-key
```

## Usage
> _TODO: confirm the run command and the demo login._

```bash
jac start main.jac             # TODO: confirm entry file and command
```

1. **Patient:** open the app, describe the condition, share your location (optional PDF), and view the recommended hospital and alternatives. For a critical case, confirm to send the dispatch.
2. **Hospital staff:** log in with a demo account _(TODO: add credentials)_, update bed availability, and watch incoming-patient alerts.
3. **Clinic patient:** enter the clinic, date and condition to get a reminder.

## Project structure
> _TODO: update to match the real layout._

```
careroute/
├── plan.md          # project plan
├── progress.md      # shared task board for the team and their agents
├── README.md
├── backend/         # Jac nodes, walkers and agents
├── frontend/        # Jac client UI
├── data/            # fake Sri Lanka hospital dataset
└── .env.example
```

## Next steps
- Replace simulated ambulance and police integration with real services (for example 1990 Suwa Seriya and traffic police)
- Live bed data from real hospital systems instead of manual updates
- Real email and SMS reminders
- Sinhala and Tamil language support
- Clinical review of the triage logic before any real-world use

## Team
Sethika, Akeesha and Dimuth
