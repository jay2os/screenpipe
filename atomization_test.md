# Atomization Test Data

Generated: 2026-06-15
Source: Local screenpipe database (`~/.screenpipe/db.sqlite`)
Filter: Non-Bluetooth audio only

---

## Data Summary

| Metric | Count |
|--------|-------|
| Total atoms | 30 |
| Yesterday (2026-06-14) atoms | 12 |
| Today (2026-06-15) atoms | 8 |
| Frame/OCR atoms | 20 |
| Audio transcription atoms | 10 |

### Content Sources

- **Chromium browser**: Gmail, GitHub, YouTube, Ollama, Microsoft Foundry, Reddit, Google Search
- **dystil-app**: Screenpipe desktop UI
- **System**: Waybar, desktop environment
- **Audio**: Non-Bluetooth microphone and speaker output

---

## Segment Atomization Prompt (v1)

This is the prompt used to extract structured information from a segment of atoms.

```
Return only a single JSON object matching this exact schema. Do not echo the input fields `apps`, `windows`, `urls`, or `atoms`. Do not add markdown fences, commentary, or extra keys. If a value is unknown, use `null` for `project_or_topic` and `[]` for arrays.

Required output schema:
{
  "segment_id": "string",
  "time_range": {
    "start": "RFC3339 timestamp",
    "end": "RFC3339 timestamp"
  },
  "activity": "string",
  "project_or_topic": "string or null",
  "tools_used": ["string"],
  "accomplishments": ["string"],
  "blockers": [
    {
      "type": "software|process|person|other",
      "summary": "string",
      "confidence": 0.0,
      "evidence_atom_ids": ["atom_id"]
    }
  ],
  "inefficiencies": [
    {
      "type": "context_switch|rework|waiting|other",
      "summary": "string",
      "confidence": 0.0,
      "evidence_atom_ids": ["atom_id"]
    }
  ],
  "people_mentions": [
    {
      "display_name": "string",
      "context": "string",
      "confidence": 0.0,
      "evidence_atom_ids": ["atom_id"]
    }
  ],
  "unfinished_work": ["string"],
  "evidence_atom_ids": ["atom_id"]
}

Rules:
- Base every claim only on the provided atoms.
- Every blocker, inefficiency, and people mention must cite `evidence_atom_ids` from the provided atoms.
- `segment_id` and `time_range` must match the input exactly.
- `evidence_atom_ids` should be the union of atom IDs directly supporting the segment summary.
- If the content is noisy, repetitive, entertainment, or not clearly work-related, say so in `activity` and leave unsupported sections empty.
```

---

## Daily Reducer Prompt (v1)

This is the prompt used to aggregate segment reports into a daily summary.

```
Return only a single JSON object matching this exact schema. Do not add markdown fences, commentary, or extra keys.

Required output schema:
{
  "summary": "string",
  "what_the_user_did": ["string"],
  "accomplishments": ["string"],
  "unfinished_work": ["string"],
  "software_blockers": [
    {
      "type": "software",
      "summary": "string",
      "confidence": 0.0,
      "evidence_atom_ids": ["atom_id"]
    }
  ],
  "person_process_blockers": [
    {
      "type": "person|process",
      "summary": "string",
      "confidence": 0.0,
      "evidence_atom_ids": ["atom_id"]
    }
  ],
  "inefficiencies": [
    {
      "type": "context_switch|rework|waiting|other",
      "summary": "string",
      "confidence": 0.0,
      "evidence_atom_ids": ["atom_id"]
    }
  ],
  "automation_opportunities": ["string"],
  "people_mentioned": [
    {
      "display_name": "string",
      "context": "string",
      "confidence": 0.0,
      "evidence_atom_ids": ["atom_id"]
    }
  ],
  "timeline": [
    {
      "segment_id": "string",
      "start_time": "RFC3339 timestamp",
      "end_time": "RFC3339 timestamp",
      "activity": "string",
      "evidence_atom_ids": ["atom_id"]
    }
  ],
  "evidence_refs": ["atom_id"]
}

Rules:
- Base every claim only on the provided `segments` and `evidence`.
- Do not invent people, blockers, tasks, or durations.
- Unsupported claims must be omitted.
- Every blocker, inefficiency, people mention, and timeline entry must cite evidence atom IDs.
- Prefer concise, factual summaries over speculation.
```

---

## Test Data: Yesterday (2026-06-14)

### Segment 1: Email & GitHub Notifications (17:12 - 17:37 UTC)

Input JSON for segment prompt:

```json
{
  "segment_id": "seg_test_yesterday_001",
  "time_range": {
    "start": "2026-06-14T17:12:28Z",
    "end": "2026-06-14T17:37:19Z"
  },
  "apps": [
    "Chromium"
  ],
  "windows": [
    "Inbox (2) - jayvardhan@2os.ai - Second Order Systems Mail",
    "[jay2os/screenpipe] Run failed: Release Dystil - 2os/distil",
    "Second Order Systems Mail"
  ],
  "urls": [],
  "atoms": [
    {
      "atom_id": "atom_0001",
      "timestamp": "2026-06-14T17:37:08.120693085+00:00",
      "app_name": "Chromium",
      "window_name": "Inbox (2) - jayvardhan@2os.ai - Second Order Systems Mail - Chromium - Work",
      "browser_url": null,
      "text": "Sunday 23 * \u00a9 E [ : hashing disabled \u2122M Udit Agarwal <udit@2 23 mail.google.com = M Gmail Q search mail = Oma (@ 2 V4 Compose Cu @ o Ll = \u00a9 @ = \u00a9 \u00ae\u00bb Mail ck to Inbox Udit Agarwal <[EMAIL]> messaged you on Google Cl = Inbox 2 were away Inbox x = Starred Ia Snoozed Udit Agarwal (via Google Chat) Drafts Categories Udit Agarwal < > messaged you on were awa Purchases y [w] w o B> Sent D D a] More Udit Ag On bolle y Self Distillation - post training technique Labels ar Udit Agarwal your design look good Udit Agarwal Jayvardhan Patil go ahead with this Udit Agarwal | am hopping between meetings Udit Agarwal will be in touch on chat Udit Agarwal lets get the app ready today Jayvardhan Patil Yes & Jayvardhan Patil macOS (arm build of Dystil) Udit Agarwal thanks checking W Udit Agarwal \u00ab Reply ~ For..."
    },
    {
      "atom_id": "atom_0002",
      "timestamp": "2026-06-14T17:37:12.224388987+00:00",
      "app_name": "Chromium",
      "window_name": "[jay2os/screenpipe] Run failed: Release Dystil - 2os/distil (a0454c3) - jayvardhan@2os.ai - Second Order Systems Mail - Chromium - Work",
      "browser_url": null,
      "text": "Sunday 23:07 bash: hash: hashing disabled ~1[] Mail Chat 1 [jay2os/screenpipe] R 23 mail.google.com M Gmail V4 Compose Inbox Starred Snoozed Drafts Categories Purchases [w] w o B> Sent D D a] More Labels Q Search mail =r = O Away v \u00ae \u00a3 \u00a9 &@& mm D \u00bb [jay2os/screenpipe] Run failed: Release Dystil - 2os/distil External Inbox x \u00ae jay2os at [a 2 ci ~ [jay2os/screenpipe] Release Dystil work Release Dystil: Some jobs were not succ Status Job F Release Dystil / build (macos-15, x86_64-apple- [x] darwin, --target x86_64-apple-darwin --features metal redact-onnx-c Failed in 2 minutes and 5 seconds Release Dystil / build (macos-15, aarch64-apple- Qo darwin, --target aarch64-apple-darwin features metal, parakeet-ml Failed in 2 minutes and 3 seconds Release Dystil / build (windows-2022, x86_64-pc- x) w..."
    },
    {
      "atom_id": "atom_0003",
      "timestamp": "2026-06-14T17:38:47.814361488+00:00",
      "app_name": "Chromium",
      "window_name": "fix: align release workflow with production environment and OIDC publish \u00b7 juspay/hyper-sdk-capacitor@6ec6249 - Chromium - Personal",
      "browser_url": null,
      "text": "Sunday 23 0 $F 9 Oe a v | @ fix: align release worki. x () Add Lint check in Githu x | + \u20ac > x = (v) juspay / hyper-sdk-capacitor <> Code (O Issues 1 11 Pullrequests 3 ( Actions ff Projects $+ Models ( Security and quality [+ Insights View recovery codes | x Commit 6ec6249 \u00bb mitted 2 43 Browse files hours ago) fix: align release workflow with production environment and 0IDC publish 13 1 parent 2290d2 commit 6ec6249 (L) flow run y 2 files changed Q Filter files 0 Qs within code 8 \u00a9 BO Giri v .github/orkFlows/build.yml (5 3 woos (GB) DO) +o\u00bb build.yml ps ee B\u00ae releaseyml 2 2 - : Set up Node.js 2 + actions/setup-nodegva notations = : 2 = : 18 % + co a 2 + \"https://registry.npnjs.org\" 2 2 2 - name: Install dependencies ~ .github/workflows/release.yml [0 3 LEER & REET 1 Releases - pullrequest +..."
    },
    {
      "atom_id": "atom_0010",
      "timestamp": "2026-06-14T17:12:35.842204032+00:00",
      "app_name": "dystil-app",
      "window_name": "Dystil",
      "browser_url": null,
      "text": "Minimize\nRestore\nClose\nDystil\n0 e 2 Sunday 22:42 v MM Inbox (3) - jayvardh: x \u00ae New Tab x \u00a2] @\u00ae Search Google or type a URL arch Google or type a URL y) M =n 0 i y) \u00bb M GitHub Inbox (3) Microsoft Azure screenpipe/scr.. Second Order ~~ jay2os/screenpi.. Microsoft Foun... Inbox"
    },
    {
      "atom_id": "atom_0011",
      "timestamp": "2026-06-14T17:12:38.353443248+00:00",
      "app_name": "dystil-app",
      "window_name": "Dystil",
      "browser_url": null,
      "text": "Minimize\nRestore\nClose\nDystil\n0 e 2 Sunday 22:42 v MM Inbox (3) - jayvardh: x \u00ae New Tab x \u00a2] @\u00ae Search Google or type a URL arch Google or type a URL y) M =n 0 i y) \u00bb M GitHub Inbox (3) Microsoft Azure screenpipe/scr.. Second Order ~~ jay2os/screenpi.. Microsoft Foun... Inbox"
    },
    {
      "atom_id": "atom_0012",
      "timestamp": "2026-06-14T17:12:42.154762862+00:00",
      "app_name": "dystil-app",
      "window_name": "Dystil",
      "browser_url": null,
      "text": "Minimize\nRestore\nClose\nDystil\nSunday 22:42 \u00a9 < % $v OO @ Dystil = a xX nitor 1093: frame_id=4577, dur=5211ms Window-specific shortcuts unregistered Tesseract Command: /usr/bin/tesseract SLPS tesseract9DDkiK.png stdout -1 eng --dpi 600 --ps m1 --oem 1 -c tessedit_create_tsv=1 shortcut-sync: register_if_visible ex ecute (reason=home_focus) google calendar publisher: frente calendar events publisher: starte ut efresh failed for phe cale ndar(instance=None): no stored token for google-calenda act Command: eee ect (YES FERCLOGRTEk png stdout -1 eng --dpi 660 --ps m1 --oem 1 -c tessedit_create_tsv=1 ts shortcut-sync: unregister execute (re ason=home_blur_no_screenpipe_focus) Window-specific shortcuts unregistered rtcut-sync: register_if_visible ex ecute (reason=home_focus) shortcut-sync: unregis..."
    }
  ]
}
```

---

### Segment 2: Research & Learning (20:54 - 20:56 UTC)

Input JSON for segment prompt:

```json
{
  "segment_id": "seg_test_yesterday_002",
  "time_range": {
    "start": "2026-06-14T20:54:56Z",
    "end": "2026-06-14T20:56:31Z"
  },
  "apps": [
    "Chromium"
  ],
  "windows": [
    "Ollama - Chromium - Work",
    "granite4.1 - Chromium - Work",
    "lfm2.5-thinking - Chromium - Work"
  ],
  "urls": [],
  "atoms": [
    {
      "atom_id": "atom_0007",
      "timestamp": "2026-06-14T20:54:56.868469079+00:00",
      "app_name": "Chromium",
      "window_name": "Ollama - Chromium - Work",
      "browser_url": null,
      "text": "ou 013 4 5 RECENTS Screen Activity & Acc... Analyze Today's Scre... Daily Screen & Audio ... Review last hour's work hi Suggest 3 automation... Analyze workflow &s... WM Day Recap Review last hour's work Hi \u00a9 History 4 A Settings Dystil Title: Activity Summary (Today) 1 mep_call B\u00ae mcp_call arguments: {\"date\":\"2023-12-01\" } server_id: <get server id from mcp_list_tools> tool: analyze_recording_summary Monday 02:24 & < % mcp_( mcep_list_tools>\"} Since the \u201cmep_call* was unsuccessful, | will retry using a different method. I'll begin by searching eu today. However, since you's y < calendar ding th audio transcripts. pty p pe's REST API. If that fails, I'll fall b let me verify q \"SCREENPIPE LOCAL API KEY\". token First, I'll search for any calendar events associated with your account. $mcp_ap..."
    }
  ]
}
```

---

## Test Data: Today (2026-06-15)

### Segment 3: Morning Email & Logs (09:57 UTC)

Input JSON for segment prompt:

```json
{
  "segment_id": "seg_test_today_001",
  "time_range": {
    "start": "2026-06-15T09:57:06Z",
    "end": "2026-06-15T09:57:24Z"
  },
  "apps": [
    "Chromium"
  ],
  "windows": [
    "macOS app without certificate - Personal",
    "Udit Agarwal - jayvardhan@2os.ai - Second Order Systems Mail"
  ],
  "urls": [],
  "atoms": [
    {
      "atom_id": "atom_0013",
      "timestamp": "2026-06-15T05:58:49.985923830+00:00",
      "app_name": "Chromium",
      "window_name": "Udit Agarwal - jayvardhan@2os.ai - Second Order Systems Mail - Chromium - Work",
      "browser_url": null,
      "text": "1 \u00ae 3 4 Monday 11:28 & < 3% \u00ae 0 8 Dystil = a Xx event-driven capture for monitor 35 (device: monitor_35) hd recorder: high-fp s capture not supported on this platform (monitor 35) VisionMa nager started with 2/2 monitor(s) VisionManager started s uccessfully event-drive n capture started for monitor 35 (device: monitor_35) Starting monitor watcher (polling every 5 seconds) Monitor watcher started idle captur e phase for monitor 33: next idle in 15000ms across 2 monitor(s) idle captur e phase for monitor 35: next idle in 30080ms across 2 monitor(s) Starting UI event ca pture Server listening on 127.0 .0.1:3030 UI recording session started: 12cchf34-7 4462-8547 UI event recording star ted successfully meeting watcher started (v2 UI scanning) Capture session started successfully Server + capt..."
    },
    {
      "atom_id": "atom_0014",
      "timestamp": "2026-06-15T05:59:22.692694117+00:00",
      "app_name": "Chromium",
      "window_name": "macOS app without certificate - Personal",
      "browser_url": null,
      "text": "012 \u00ae 45 Monday 11:29 & v \u00ae YouTube x 0 Intro | Al coding agent x + x \u20ac 5 CC 2% opencodeai/docs wr 9 \u00ae a OpERCOde om Search CtrlK - Intro On this page Intro Config Get started with OpenCode. Install Providers Configure Network Initialize Enterprise OpenCode is an open source AI coding agent. It's available as a Usage ho Troubleshooting terminal-based interface, desktop app, or IDE extension. Ask questions Windows Add features OODLES eee 5 lings - Undo changes Go Share N TUL Customize . cLT 1'11 search for the homepage button in the codebase. . ge | hose. sbutton |Home. sbutton' Web Lat for IDE 1 found several \"Home\" links. Let we look at the most likely candidates - the 404 pages and the Zen header component which have \u201cHome links: Share GitHub ye GitLab 1 Configure v Build Claude Opus 4.5..."
    },
    {
      "atom_id": "atom_0015",
      "timestamp": "2026-06-15T05:58:55.728564040+00:00",
      "app_name": "Chromium",
      "window_name": "Intro | AI coding agent built for the terminal - Chromium - Personal",
      "browser_url": null,
      "text": "Monday 11:28 && \u201c8 | opencode.ai/docs +4 | | = \u00a9 Look | A OpEncode 0 \u00ae search Ctrlk | | Q Add \u00a2 | k 0 | On this page hg Intro Intro a ow | ERREIE Get started with OpenCode. pine [ Providers Install B ( | Configure y | Network Initialize * 3 Enterprise OpenCode is an open source AI coding agent. It's available as a Usage lel inal- . The fi Troubleshooting terminal-based interface, desktop app, or IDE extension. Ask questions Windows Add features - ox (CS de Ee ae 5 Usage hg Undo changes N So an | 39,413 20% ($0.29) - Go Share = . - Pro TUT Customize F . Your cL i N \u00ab Grop \u201chomepage hose. sbutton| Howe. sbut ton\" Is * Crep \"Homepage\u2019 - Web ey , \u00abWy IDE 2 Glob \u201ceufa.toxs (180 matches) tin : Zen pe teen every rer EE at the most likely candidates - the 404 pages and the > | Share * head Pecan c..."
    },
    {
      "atom_id": "atom_0016",
      "timestamp": "2026-06-15T05:59:11.989129988+00:00",
      "app_name": "Chromium",
      "window_name": "Windows VM - Omarchy",
      "browser_url": null,
      "text": "Monday 11:29 & x \u20182% opencode.ai/docs * A OpERCOde Oo Search CtrlK | | - Intro I On this page ntro 2 Ov i Config Get started with OpenCode. exview Providers Install Configure Network Initialize = Enterprise OpenCode is an open source AI coding agent. It's available as a Usage | Troubleshooting terminal-based interface, desktop app, or IDE extension. Ask questions Windows Add features - CL foe che 8 Usage - Undo changes \u00bb 39,413 20% ($6.29) | Go Share Ho TUT Customize - rn - * Grep \"Homepage - Web IDE 3 Glob \u201cenfa.toxs (100 matches) Zen i oon several \"Home\" links. Let me look at the most likely candidates - the 404 pages and the \u00bb T component which have \u201cHome\" links: Share r=] Pecans coals rc cpt de tax lead packages/enterprise/src/routes/[ ... 404). ts: GitHub - v y: \u2014 = 0 = gyi trace ul D..."
    }
  ]
}
```

---

### Segment 4: Audio Transcriptions (Non-Bluetooth)

Input JSON for segment prompt:

```json
{
  "segment_id": "seg_test_audio_001",
  "time_range": {
    "start": "2026-06-13T17:23:14Z",
    "end": "2026-06-15T14:55:08Z"
  },
  "apps": [
    "audio"
  ],
  "windows": [
    "alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source",
    "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink"
  ],
  "urls": [],
  "atoms": [
    {
      "atom_id": "atom_0021",
      "timestamp": "2026-06-13T06:44:17+00:00",
      "app_name": "audio",
      "window_name": "alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source",
      "browser_url": null,
      "text": " \u00a1Vos sin generar el d\u00eda de ese d\u00eda!"
    },
    {
      "atom_id": "atom_0022",
      "timestamp": "2026-06-13T06:44:17+00:00",
      "app_name": "audio",
      "window_name": "alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source",
      "browser_url": null,
      "text": " ."
    },
    {
      "atom_id": "atom_0023",
      "timestamp": "2026-06-13T06:44:17+00:00",
      "app_name": "audio",
      "window_name": "alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source",
      "browser_url": null,
      "text": " Thank you."
    },
    {
      "atom_id": "atom_0024",
      "timestamp": "2026-06-13T06:44:17+00:00",
      "app_name": "audio",
      "window_name": "alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source",
      "browser_url": null,
      "text": " Okay, what I'm going to do is..."
    },
    {
      "atom_id": "atom_0025",
      "timestamp": "2026-06-13T06:45:31+00:00",
      "app_name": "audio",
      "window_name": "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink",
      "browser_url": null,
      "text": "This is all our rules. Let's go. We're going to need a set of rules. Let's just do that. I'm going to put that one on the right. I need a set of rules. I need to have that. This is our story."
    },
    {
      "atom_id": "atom_0026",
      "timestamp": "2026-06-13T07:32:04+00:00",
      "app_name": "audio",
      "window_name": "alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source",
      "browser_url": null,
      "text": "y a la cara como su vida."
    },
    {
      "atom_id": "atom_0027",
      "timestamp": "2026-06-13T07:39:28+00:00",
      "app_name": "audio",
      "window_name": "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink",
      "browser_url": null,
      "text": " I just did."
    },
    {
      "atom_id": "atom_0028",
      "timestamp": "2026-06-13T07:39:28+00:00",
      "app_name": "audio",
      "window_name": "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink",
      "browser_url": null,
      "text": " Thank you."
    }
  ]
}
```

---

## How to Test

1. **Copy** one of the segment JSON blocks above
2. **Combine** it with the segment prompt
3. **Send** to an AI model (e.g., GPT-4, Claude, Qwen, Llama)
4. **Verify** the output matches the expected schema

### Example Python Code

```python
import json

# Load the segment prompt
segment_prompt = open('cloud/crates/work-insights-report/prompts/segment_v1.txt').read()

# Your segment data (copy from above)
user_prompt = json.dumps({
    "segment_id": "seg_test_yesterday_001",
    "time_range": {"start": "2026-06-14T17:12:28Z", "end": "2026-06-14T17:37:19Z"},
    "apps": ["Chromium"],
    "windows": ["Inbox (2) - ...", "[jay2os/screenpipe] Run failed: ..."],
    "urls": [],
    "atoms": [
        # ... paste atoms here
    ]
})

# Send to your AI model
response = ai_client.chat(
    model="your-model",
    messages=[
        {"role": "system", "content": segment_prompt},
        {"role": "user", "content": user_prompt}
    ],
    response_format={"type": "json_object"}
)

# Parse and validate
result = json.loads(response.choices[0].message.content)
print(json.dumps(result, indent=2))
```

### Expected Output Schema

```json
{
  "segment_id": "string",
  "time_range": {
    "start": "RFC3339 timestamp",
    "end": "RFC3339 timestamp"
  },
  "activity": "string describing what the user did",
  "project_or_topic": "string or null",
  "tools_used": [
    "list of tools/apps"
  ],
  "accomplishments": [
    "what was achieved"
  ],
  "blockers": [
    {
      "type": "software|process|person|other",
      "summary": "description",
      "confidence": 0.0,
      "evidence_atom_ids": [
        "atom_id"
      ]
    }
  ],
  "inefficiencies": [
    {
      "type": "context_switch|rework|waiting|other",
      "summary": "description",
      "confidence": 0.0,
      "evidence_atom_ids": [
        "atom_id"
      ]
    }
  ],
  "people_mentions": [
    {
      "display_name": "name",
      "context": "why mentioned",
      "confidence": 0.0,
      "evidence_atom_ids": [
        "atom_id"
      ]
    }
  ],
  "unfinished_work": [
    "list of incomplete tasks"
  ],
  "evidence_atom_ids": [
    "atom_id"
  ]
}
```

---

## Raw Atom Data (All 30 Atoms)

### atom_0001 (frame_ocr)
- **Timestamp**: 2026-06-14T17:37:08.120693085+00:00
- **App**: Chromium
- **Window**: Inbox (2) - jayvardhan@2os.ai - Second Order Systems Mail - Chromium - Work
- **Text**:
```
Sunday 23 * © E [ : hashing disabled ™M Udit Agarwal <udit@2 23 mail.google.com = M Gmail Q search mail = Oma (@ 2 V4 Compose Cu @ o Ll = © @ = © ®» Mail ck to Inbox Udit Agarwal <[EMAIL]> messaged you on Google Cl = Inbox 2 were away Inbox x = Starred Ia Snoozed Udit Agarwal (via Google Chat) Drafts Categories Udit Agarwal < > messaged you on were awa Purchases y [w] w o B> Sent D D a] More Udit Ag On bolle y Self Distillation - post training technique Labels ar Udit Agarwal your design look good Udit Agarwal Jayvardhan Patil go ahead with this Udit Agarwal | am hopping between meetings Udit Agarwal will be in touch on chat Udit Agarwal lets get the app ready today Jayvardhan Patil Yes & Jayvardhan Patil macOS (arm build of Dystil) Udit Agarwal thanks checking W Udit Agarwal « Reply ~ Forward ®@ [7 Share in chat
```

### atom_0002 (frame_ocr)
- **Timestamp**: 2026-06-14T17:37:12.224388987+00:00
- **App**: Chromium
- **Window**: [jay2os/screenpipe] Run failed: Release Dystil - 2os/distil (a0454c3) - jayvardhan@2os.ai - Second Order Systems Mail - Chromium - Work
- **Text**:
```
Sunday 23:07 bash: hash: hashing disabled ~1[] Mail Chat 1 [jay2os/screenpipe] R 23 mail.google.com M Gmail V4 Compose Inbox Starred Snoozed Drafts Categories Purchases [w] w o B> Sent D D a] More Labels Q Search mail =r = O Away v ® £ © &@& mm D » [jay2os/screenpipe] Run failed: Release Dystil - 2os/distil External Inbox x ® jay2os at [a 2 ci ~ [jay2os/screenpipe] Release Dystil work Release Dystil: Some jobs were not succ Status Job F Release Dystil / build (macos-15, x86_64-apple- [x] darwin, --target x86_64-apple-darwin --features metal redact-onnx-c Failed in 2 minutes and 5 seconds Release Dystil / build (macos-15, aarch64-apple- Qo darwin, --target aarch64-apple-darwin features metal, parakeet-ml Failed in 2 minutes and 3 seconds Release Dystil / build (windows-2022, x86_64-pc- x) windows-msvc, --target x86_64-pc-windows-msvc - -features official- Eailed and 4 s onds Release Dystil / release Skipped Manage yol tHub A 3 « Reply < Reply to all ~ Forward [3 Share in chat
```

### atom_0003 (frame_ocr)
- **Timestamp**: 2026-06-14T17:38:47.814361488+00:00
- **App**: Chromium
- **Window**: fix: align release workflow with production environment and OIDC publish · juspay/hyper-sdk-capacitor@6ec6249 - Chromium - Personal
- **Text**:
```
Sunday 23 0 $F 9 Oe a v | @ fix: align release worki. x () Add Lint check in Githu x | + € > x = (v) juspay / hyper-sdk-capacitor <> Code (O Issues 1 11 Pullrequests 3 ( Actions ff Projects $+ Models ( Security and quality [+ Insights View recovery codes | x Commit 6ec6249 » mitted 2 43 Browse files hours ago) fix: align release workflow with production environment and 0IDC publish 13 1 parent 2290d2 commit 6ec6249 (L) flow run y 2 files changed Q Filter files 0 Qs within code 8 © BO Giri v .github/orkFlows/build.yml (5 3 woos (GB) DO) +o» build.yml ps ee B® releaseyml 2 2 - : Set up Node.js 2 + actions/setup-nodegva notations = : 2 = : 18 % + co a 2 + "https://registry.npnjs.org" 2 2 2 - name: Install dependencies ~ .github/workflows/release.yml [0 3 LEER & REET 1 Releases - pullrequest + push: - main ¥ - - closed 1 - + github. event.pull_request.merged true & tcontains(github.event.pull request. title, ‘[skip cil’) 9 + tl © + github.ref == 'refs/heads/main’ && n+ et [skip ci]') && 2 ...
```

### atom_0004 (frame_ocr)
- **Timestamp**: 2026-06-14T17:53:29.513204386+00:00
- **App**: Chromium
- **Window**: (403) You Are Using AI Wrong - YouTube - Audio playing - Chromium - Personal
- **Text**:
```
©) fix: align release worki x | €) Add Lint check in Githu x | ® (403) YouTube » (403) You Are Usir 5 youtube.com / — w 3D + * YouTube Sn . — Application software Learning ©) woven 1 gsc a slr &- \ Jake Frood - Need Your Lovin" (a0454c3) Nightblu © Code © muss 23 01 Pullrequests M2 6 Agents © Acions [0 Projects © Security and quality =< ED # man - stack / make-pdf / SKILLmd (© Q cowfie hours ago) dr : £2) gamytan and claude +1 ALREADY HIVINGA TEM Preview Code lame. flow run name | make-pdt AW r— version 100 ——— Punish You. essful You Are Using Al Wrong 5) Kyle Gio Web Dev Simplified ~~. fy 19K | GA p> share 4 Ask J Download notations 0s Lo views 2 fz iers ago mT #WDS #WebDevsimplified M cour de m Fables End - 11 Things You Eres as Claude aine ‘° Main Channel: ~» / @webdevsimplific ...more 0s 149 Comments Sart by Add a comment e @zormo161 2 days ago 12 7" @ ® we going full circle Neon City Spark &os @ Reply Sui-Topi ® = @ridass.7137 2 only does it burn tokens it literally burns forests ...
```

### atom_0005 (frame_ocr)
- **Timestamp**: 2026-06-14T18:23:45.992507063+00:00
- **App**: Chromium
- **Window**: Microsoft Foundry Service: Request for Quota Increase - Chromium - Work
- **Text**:
```
01 ®3 45 4, Settings = a B Q © DVYSTIL RECENTS Greeting h hello 25m hello 19h Review last hour's work 22h hi 22h Suggest 3 automation... 1d Analyze workflow &ss... 1d MW Day Recap 1d Review last hour's work 1d Hi 1d © History Greeting + Sunday 23:53 © - —— ran 1 command, read 1 file ran 1 command Activity summary Th Ii + I both ran 1 command = Message will be queued... ar DEEPSEEK-V4-FLASH SQL to get a better picture across analyzing... < © %¥ 9 0 & NM E Ton [Ey br compatible-url.ts, pi.rs, ai-presets. + I've already verified the frontend helper and the c compile now so it doesn’t keep burning time in the lace. + The 404 is from the request path, not the model loc Your RL So if you entered: // il-global-resource.openai.azure.com/ope the app could end up calling a doubled path insteac normalizing OpenAI-compatible URLs before the app & Changed here: = EL tible-url. 5:13 tsx:124 - src- Ry rs: 1101 I also added a regression test for the Pi config pe - src-tauri/src/pi.rs:3561 One more thi...
```

### atom_0006 (frame_ocr)
- **Timestamp**: 2026-06-14T18:27:54.564106202+00:00
- **App**: Chromium
- **Window**: Microsoft Foundry Models quotas and limits - Microsoft Foundry | Microsoft Learn - Chromium - Work
- **Text**:
```
Sunday 23:57 © 1. A Microsoft © x @ MicrosoftF- x @ Microsoft F* x gE Understanc x @ azuredirec x + x v () fix: align release worki x | €) . € > xX S| i us/azure/foundry/foundry- quotas-limits NY a — N = YouTube v MM [jay2os/sc x ® New Tab x & ® : € > C 2% youtube.com/watch?v=
```

### atom_0007 (frame_ocr)
- **Timestamp**: 2026-06-14T20:54:56.868469079+00:00
- **App**: Chromium
- **Window**: Ollama - Chromium - Work
- **Text**:
```
ou 013 4 5 RECENTS Screen Activity & Acc... Analyze Today's Scre... Daily Screen & Audio ... Review last hour's work hi Suggest 3 automation... Analyze workflow &s... WM Day Recap Review last hour's work Hi © History 4 A Settings Dystil Title: Activity Summary (Today) 1 mep_call B® mcp_call arguments: {"date":"2023-12-01" } server_id: <get server id from mcp_list_tools> tool: analyze_recording_summary Monday 02:24 & < % mcp_( mcep_list_tools>"} Since the “mep_call* was unsuccessful, | will retry using a different method. I'll begin by searching eu today. However, since you's y < calendar ding th audio transcripts. pty p pe's REST API. If that fails, I'll fall b let me verify q "SCREENPIPE LOCAL API KEY". token First, I'll search for any calendar events associated with your account. $mcp_api_ # (©) copy, rded and parsed from the Screenpipe U's calendar functionality IS th ded dd q lot's Ed Ed Ask Dystil anything... dL QWEN3.5:9B LRAT “hello\n\n**thinking process:** \n ... (long section)...
```

### atom_0008 (frame_ocr)
- **Timestamp**: 2026-06-14T21:00:24.765674742+00:00
- **App**: Chromium
- **Window**: PSA: Having issues with Qwen3.5 overthinking? Give it a tool, and it can help dramatically. : r/LocalLLaMA - Chromium - Personal
- **Text**:
```
x ® New 25 ollama.com @® Olama x | @ minic Xx @ gemm: x @ Olama x @ Ifm2 ollama run ibm/granite4.1:8b To run other quantizations (e.g., q8_e ): ollama run ibm/granite4.1:8b-q8_0 Supported Languages Supported Languages: English, German, Spanish, French, Japanese, Portuguese, Arabic, Czech, Italian, Korean, Dutch, and Chinese. Users may finetune Granite 4.1 models for languages beyond these languages. Intended Use This model is designed to handle general instruction-following tasks and can be integrated into Al assistants across various domains, including business applications. The model is designed to respond to general instructions and can be used to build Al assistants for multiple domains, including business applications. Capabilities Summarization Text classification Text extraction Question-answering Retrieval Augmented Generation (RAG) Code related tasks Function-calling tasks Multilingual dialog use cases x ® granite 1% ¢ 0 fix: x = (40 | = (40 om = reddit.com I@ de
```

### atom_0009 (frame_ocr)
- **Timestamp**: 2026-06-14T12:54:51.489930377+00:00
- **App**: dystil-app
- **Window**: Dystil
- **Text**:
```
Minimize
Restore
Close
Dystil
< 3 ¢ 4 & i Could not connect to localhost: Connection refused Could not connect to localhost: Connection refused
```

### atom_0010 (frame_ocr)
- **Timestamp**: 2026-06-14T17:12:35.842204032+00:00
- **App**: dystil-app
- **Window**: Dystil
- **Text**:
```
Minimize
Restore
Close
Dystil
0 e 2 Sunday 22:42 v MM Inbox (3) - jayvardh: x ® New Tab x ¢] @® Search Google or type a URL arch Google or type a URL y) M =n 0 i y) » M GitHub Inbox (3) Microsoft Azure screenpipe/scr.. Second Order ~~ jay2os/screenpi.. Microsoft Foun... Inbox
```

### atom_0011 (frame_ocr)
- **Timestamp**: 2026-06-14T17:12:38.353443248+00:00
- **App**: dystil-app
- **Window**: Dystil
- **Text**:
```
Minimize
Restore
Close
Dystil
0 e 2 Sunday 22:42 v MM Inbox (3) - jayvardh: x ® New Tab x ¢] @® Search Google or type a URL arch Google or type a URL y) M =n 0 i y) » M GitHub Inbox (3) Microsoft Azure screenpipe/scr.. Second Order ~~ jay2os/screenpi.. Microsoft Foun... Inbox
```

### atom_0012 (frame_ocr)
- **Timestamp**: 2026-06-14T17:12:42.154762862+00:00
- **App**: dystil-app
- **Window**: Dystil
- **Text**:
```
Minimize
Restore
Close
Dystil
Sunday 22:42 © < % $v OO @ Dystil = a xX nitor 1093: frame_id=4577, dur=5211ms Window-specific shortcuts unregistered Tesseract Command: /usr/bin/tesseract SLPS tesseract9DDkiK.png stdout -1 eng --dpi 600 --ps m1 --oem 1 -c tessedit_create_tsv=1 shortcut-sync: register_if_visible ex ecute (reason=home_focus) google calendar publisher: frente calendar events publisher: starte ut efresh failed for phe cale ndar(instance=None): no stored token for google-calenda act Command: eee ect (YES FERCLOGRTEk png stdout -1 eng --dpi 660 --ps m1 --oem 1 -c tessedit_create_tsv=1 ts shortcut-sync: unregister execute (re ason=home_blur_no_screenpipe_focus) Window-specific shortcuts unregistered rtcut-sync: register_if_visible ex ecute (reason=home_focus) shortcut-sync: unregister execute (re ason=home_blur_no_screenpipe_focus) Window-specific shortcuts unregistered Tesseract Command: /usr/bin/tesseract SITS tesseract3s4adf.png stdout -1 eng --dpi 600 --ps m1 --oem 1 -c tes...
```

### atom_0013 (frame_ocr)
- **Timestamp**: 2026-06-15T05:58:49.985923830+00:00
- **App**: Chromium
- **Window**: Udit Agarwal - jayvardhan@2os.ai - Second Order Systems Mail - Chromium - Work
- **Text**:
```
1 ® 3 4 Monday 11:28 & < 3% ® 0 8 Dystil = a Xx event-driven capture for monitor 35 (device: monitor_35) hd recorder: high-fp s capture not supported on this platform (monitor 35) VisionMa nager started with 2/2 monitor(s) VisionManager started s uccessfully event-drive n capture started for monitor 35 (device: monitor_35) Starting monitor watcher (polling every 5 seconds) Monitor watcher started idle captur e phase for monitor 33: next idle in 15000ms across 2 monitor(s) idle captur e phase for monitor 35: next idle in 30080ms across 2 monitor(s) Starting UI event ca pture Server listening on 127.0 .0.1:3030 UI recording session started: 12cchf34-7 4462-8547 UI event recording star ted successfully meeting watcher started (v2 UI scanning) Capture session started successfully Server + capture started successfully on dedicated runtime speaker iden tification: started (user_name=<not set>) snapshot com paction worker started (min_age=680s, poll=300s) meeting v2: det ection loop started (...
```

### atom_0014 (frame_ocr)
- **Timestamp**: 2026-06-15T05:59:22.692694117+00:00
- **App**: Chromium
- **Window**: macOS app without certificate - Personal
- **Text**:
```
012 ® 45 Monday 11:29 & v ® YouTube x 0 Intro | Al coding agent x + x € 5 CC 2% opencodeai/docs wr 9 ® a OpERCOde om Search CtrlK - Intro On this page Intro Config Get started with OpenCode. Install Providers Configure Network Initialize Enterprise OpenCode is an open source AI coding agent. It's available as a Usage ho Troubleshooting terminal-based interface, desktop app, or IDE extension. Ask questions Windows Add features OODLES eee 5 lings - Undo changes Go Share N TUL Customize . cLT 1'11 search for the homepage button in the codebase. . ge | hose. sbutton |Home. sbutton' Web Lat for IDE 1 found several "Home" links. Let we look at the most likely candidates - the 404 pages and the Zen header component which have “Home links: Share GitHub ye GitLab 1 Configure v Build Claude Opus 4.5 OpenCode Zen d esc inteszust ctrlet variants tab agents ctrlep commands Tools Rules Agents 1_42_91_608_4D_3E.1 (output) (unknown Tesseract Command: /usr/bin/tesserac sv 2026-06-15T05:58:53.610548Z IN...
```

### atom_0015 (frame_ocr)
- **Timestamp**: 2026-06-15T05:58:55.728564040+00:00
- **App**: Chromium
- **Window**: Intro | AI coding agent built for the terminal - Chromium - Personal
- **Text**:
```
Monday 11:28 && “8 | opencode.ai/docs +4 | | = © Look | A OpEncode 0 ® search Ctrlk | | Q Add ¢ | k 0 | On this page hg Intro Intro a ow | ERREIE Get started with OpenCode. pine [ Providers Install B ( | Configure y | Network Initialize * 3 Enterprise OpenCode is an open source AI coding agent. It's available as a Usage lel inal- . The fi Troubleshooting terminal-based interface, desktop app, or IDE extension. Ask questions Windows Add features - ox (CS de Ee ae 5 Usage hg Undo changes N So an | 39,413 20% ($0.29) - Go Share = . - Pro TUT Customize F . Your cL i N « Grop “homepage hose. sbutton| Howe. sbut ton" Is * Crep "Homepage’ - Web ey , «Wy IDE 2 Glob “eufa.toxs (180 matches) tin : Zen pe teen every rer EE at the most likely candidates - the 404 pages and the > | Share * head Pecan coal a rcpt de tox or: * Read packages/entezprise/src/routes/[...404).ts | GitHub -v 1 ¥ ve v == Ss IY wy | nager | cur | 2026-06-15T05:58:50.796459Z INFO screenpipe_audio::audio_manager::manager: audi...
```

### atom_0016 (frame_ocr)
- **Timestamp**: 2026-06-15T05:59:11.989129988+00:00
- **App**: Chromium
- **Window**: Windows VM - Omarchy
- **Text**:
```
Monday 11:29 & x ‘2% opencode.ai/docs * A OpERCOde Oo Search CtrlK | | - Intro I On this page ntro 2 Ov i Config Get started with OpenCode. exview Providers Install Configure Network Initialize = Enterprise OpenCode is an open source AI coding agent. It's available as a Usage | Troubleshooting terminal-based interface, desktop app, or IDE extension. Ask questions Windows Add features - CL foe che 8 Usage - Undo changes » 39,413 20% ($6.29) | Go Share Ho TUT Customize - rn - * Grep "Homepage - Web IDE 3 Glob “enfa.toxs (100 matches) Zen i oon several "Home" links. Let me look at the most likely candidates - the 404 pages and the » T component which have “Home" links: Share r=] Pecans coals rc cpt de tax lead packages/enterprise/src/routes/[ ... 404). ts: GitHub - v y: — = 0 = gyi trace ul DEGPESEEE module: mj ./no Pipi fextract- EET, ts chat.tsx nr ome Ee 2026-06-15T05:58:59.940344Z INFO dystil_app::commands: Window-specific shortcuts unregistered 6 Look S Add a Oo ©
```

### atom_0017 (frame_ocr)
- **Timestamp**: 2026-06-15T06:00:16.640461220+00:00
- **App**: Chromium
- **Window**: Beyond Scaling: Making Large Language Models Efficient · Luma - Chromium - Work
- **Text**:
```
0 e 2 3 4 Monday 11:30 & < % ® 0 8 install winget (Prerequisite): Before proceeding with the other installations, make sure you have winget installed. You can download and install it by following this « Add to calendar: https://shorturl.at/rGZU1 guide: « Gmeet link: meet.google.com/uzb-mmdh-wjs To attend online: install required tools: Pre-read: winget insta -e --id Microsoft.Vi i0.2022.BuildTools winget install -e --id Rustlang.Rustup « Basics of Transformer architectures winget install -e --id LLVM.LLVM + The lllustrated Transformer winget install -e --id Kitware.CMake « Memory-Efficient Attention: MHA vs. MQA vs. GQA winget install -e --id GnuWin32.UnZip vs. MLA winget install -e --id Git.Git winget install -e --id JernejSimoncic.Wget winget install -e --id 7zip.7zip irm https://bun.sh/install.psl | iex « Understanding DeepSeek's Multi-Head Latent Attention Looking forward to seeing you! set environment variables: System.Environment]:: > REE LIBCLANG_PATH', 'C: \Program Files\LLVM\b...
```

### atom_0018 (frame_ocr)
- **Timestamp**: 2026-06-15T06:00:44.110213903+00:00
- **App**: Chromium
- **Window**: Meet - Chromium - Work
- **Text**:
```
Monday 11:30 & ™M Udit Agar x Beyond Xx = AlFatigue x = @ how does x = Downloac Xx = BaseFran Xx @ Screenpi; x | () jay2os/s &« > Cc 25 mail.google.com/mail/u/O/#chat/dm/xkf1ZyAAAAE M Gmail Q Search chat omayr @ © © 4 [J New chat 3 @ udit Agarwal va R, {4 Join video meeting ~ Shortcuts mn Home Udit Agarwal (via Meet) 43 min @ Mentions (U) [lk call ended Yr Starred ~ Direct messages ) Udit Agarwal 6 min (u] Udit Agarwal o might be interesting to you - ~ Spaces & Create a space to chat and ollaborate ~ Apps Linear £ Google Drive J) {4 Join video meeting ar History is on = --id GnuWin32. UnZip winget install - e --id Git.Git winget install - e --id JernejSimonc wi sh/install.psl | iex environment [systen. Environment SetEnvironmentVaria ble('LIBCLANG_PATH' , 'C:\Program Files\LLVM\bin' 'User') [System. Environment]: SET ET OEE Geteniromentiara ble('P , sell \Program Files (x86) \6nuWin32\bin" , 'Use ¥ 20s/distil
```

### atom_0019 (frame_ocr)
- **Timestamp**: 2026-06-15T09:55:59.585659655+00:00
- **App**: Chromium
- **Window**: Release Dystil · jay2os/screenpipe@20b0293 - Chromium - Work
- **Text**:
```
013 4 5 2026-06-15T09:55:59. pea en capture for monitor 33 (device: monitor_33) Fors EW ies INFO screenpipe_engine ot supported on this platform (monitor 33) 2026-06-15T09:55:59.078680Z 0 Rl engine: i 33) INFO screenpipe_ _manager::manager: Starting event-driv :hd_recorder: hd recorder: high-fps capture n revent_driven_capture: event-driven capture s vice: monitor_ tor : INFO screenpipe_ _manager::manager: Starting vision rec ording for monitor 35 (1660x900) 2026-06-15T09:55:59.081177Z INFO s enpip _manager::manager: Starting event-driv en capture for monitor 35 (device: monitor_35) 2026-06-15T09:55:59.081189Z INFO screenpipe_ _manager::manager: VisionManager start ed with 2/2 monitor (s) 2026-06-15T09:55:59.081197Z 2026-06-15T09:55:59.081195Z INFO dystil_app: INFO screenpipe_engine::h ot supported s platform (monitor 35) Tt 06- ts i 59.081213Z INFO i engine: tarted for monitor 35 (device: monitor_35) 2026-06-15T09:55:59.081218Z 0 screenpipe_ nitor watcher (polling every 5 seconds) INF...
```

### atom_0020 (frame_ocr)
- **Timestamp**: 2026-06-15T09:56:43.079350655+00:00
- **App**: Chromium
- **Window**: Inbox (2) - jayvardhan@2os.ai - Second Order Systems Mail - Chromium - Work
- **Text**:
```
BB @Fr 2 mail.google.com Gmail Compose Inbox Starred Snoozed Sent Drafts Categories Purchases More Labels Q Search mail a-~ Cc jay2os jay2os tl;dv Team Luma Lossfunk Event Cale. ti;dv Team Udit Agarwal Anthropic Team Microsoft Azure Ope. Udit Agarwal (via G. jay2os jay2os jay2os Microsoft Azure Microsoft Azure | inear © DYSTIL O Away v = ® © 9D + Welcome to tl;dv! § - Hi there our Luma sign-i arge Language i Scaling Udit invited you to "Madurai / Udit" - You're mentioned in the Meeting Invitation: Madurai / Udit @ Mon Jun 15, 2026 12pm - 12:45pm (GMT+... [5 We're updating our Privacy Policy - We're writing to inform you about Request for quota increase denied. - Request denied to increase quo. Udit Ag: [jay2os/screenpipe] Run failed: E2E Tests - main (37db96d) - [jay [jay2os/screenpipe] Run failed: Release Dystil - 2os/distil (9bc4443) - [ [jay2os/screenpipe] Run failed: Release Dystil - 2os/distil (a0454c3) - [ Get quickstart guides for popular Azure services - Create apps, virtu the ...
```

### atom_0021 (audio_transcription)
- **Timestamp**: 2026-06-13T06:44:17+00:00
- **App**: audio
- **Window**: alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source
- **Speaker ID**: 8
- **Text**:
```
 ¡Vos sin generar el día de ese día!
```

### atom_0022 (audio_transcription)
- **Timestamp**: 2026-06-13T06:44:17+00:00
- **App**: audio
- **Window**: alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source
- **Speaker ID**: 1
- **Text**:
```
 .
```

### atom_0023 (audio_transcription)
- **Timestamp**: 2026-06-13T06:44:17+00:00
- **App**: audio
- **Window**: alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source
- **Speaker ID**: 8
- **Text**:
```
 Thank you.
```

### atom_0024 (audio_transcription)
- **Timestamp**: 2026-06-13T06:44:17+00:00
- **App**: audio
- **Window**: alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source
- **Speaker ID**: 1
- **Text**:
```
 Okay, what I'm going to do is...
```

### atom_0025 (audio_transcription)
- **Timestamp**: 2026-06-13T06:45:31+00:00
- **App**: audio
- **Window**: alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink
- **Speaker ID**: 2
- **Text**:
```
This is all our rules. Let's go. We're going to need a set of rules. Let's just do that. I'm going to put that one on the right. I need a set of rules. I need to have that. This is our story.
```

### atom_0026 (audio_transcription)
- **Timestamp**: 2026-06-13T07:32:04+00:00
- **App**: audio
- **Window**: alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source
- **Speaker ID**: 5
- **Text**:
```
y a la cara como su vida.
```

### atom_0027 (audio_transcription)
- **Timestamp**: 2026-06-13T07:39:28+00:00
- **App**: audio
- **Window**: alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink
- **Speaker ID**: 2
- **Text**:
```
 I just did.
```

### atom_0028 (audio_transcription)
- **Timestamp**: 2026-06-13T07:39:28+00:00
- **App**: audio
- **Window**: alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink
- **Speaker ID**: 2
- **Text**:
```
 Thank you.
```

### atom_0029 (audio_transcription)
- **Timestamp**: 2026-06-13T07:39:46+00:00
- **App**: audio
- **Window**: alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink
- **Speaker ID**: 2
- **Text**:
```
 of this.
```

### atom_0030 (audio_transcription)
- **Timestamp**: 2026-06-13T07:39:46+00:00
- **App**: audio
- **Window**: alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink
- **Speaker ID**: 2
- **Text**:
```
 Thank you.
```
