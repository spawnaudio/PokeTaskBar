---
summary: "Sunsama product research and 60 candidate ideas for a possible PokeTasks v2.2."
read_when:
  - Exploring daily planning, task queues, workload limits, reflection, or calendar features
  - Assessing Sunsama inspired ideas for a future PokeTasks release
---

# Sunsama research and ideas for PokeTasks v2.2

Research collected on **2 October 2026**, Australia/Perth. This is an idea collection and proposed direction, not an approved release scope.

Sunsama's most useful contribution to PokeTasks is a way to turn an open-ended backlog into a realistic day: deliberately choose work, estimate its time, work through a short sequence, and close the day with a record of progress. PokeTasks can combine that approach with its existing Linear integration, shared focus timer and companion. The strongest first step is a daily task playlist with capacity checking and a short shutdown review. Calendar writes, broader integrations and AI can follow if they solve a demonstrated need. This recommendation is our interpretation of Sunsama's [planning workflow][planning] and [playlist method][playlist].

The outline contains **60 possible additions**, grouped into eight areas. Each numbered entry is a **PokeTasks proposal**, not a claim that the feature already exists in PokeTasks or that Sunsama implements the proposed details.

## Research scope and evidence

The research uses Sunsama's official website, public user manual and founder essays. It covers planning, workload estimates, task management, calendars, focus, breaks, objectives, reviews, integrations, keyboard controls, privacy and AI. Existing PokeTasks behavior was checked against this checkout's documentation and relevant source files.

This was public documentation research, not a signed-in Sunsama trial. Descriptions below establish what Sunsama documents; they do not establish usability, sync reliability, plan availability or a measured improvement in wellbeing. Founder essays explain design intent. Older roadmap posts establish historical intent, not delivery.

## Product philosophy worth adapting

| Documented Sunsama principle | Proposed implication for PokeTasks |
| --- | --- |
| Work should feel meaningful and sustainable. Sunsama emphasizes wellbeing and uninterrupted attention in its [philosophy of work][about]. | Make a manageable day and meaningful progress visible alongside XP. A longer workday should not automatically look like a better day. |
| The backlog can always contain more work. Its daily planning flow asks what can wait and checks estimated workload. [Daily Planning][planning] | Treat a daily plan as a deliberate commitment. Adding a task should reveal its effect on capacity and offer a way to defer something. |
| A short daily list limits exposure to tomorrow's work and reduces repeated decisions about what comes next. [Daily task list rationale][daily-list-rationale] | Show the selected daily queue during execution. Keep the rest available through deliberate navigation. |
| Scheduling should preserve agency. The playlist method projects task order and remaining duration using explicit rules, without AI. [Playlist method][playlist] | Prefer understandable estimates and manual ordering before introducing a scheduler. Explain why a task is suggested. |
| AI can lower the effort of expressing intentions. The founder's April 2025 essay describes editable estimate suggestions; the current manual documents Sunny's broader task and planning capabilities. [AI design rationale][ai-rationale], [Sunny][sunny] | Keep suggestions easy to correct. An assistant can propose a plan while the user owns the choices. Do not describe Sunsama as opposed to AI or limited to its 2025 capabilities. |
| Reflection should require less writing effort. Daily Highlights drafts a record from activity, while leaving editing and personal reflection to the user. [Highlights rationale][highlights-rationale] | Start a review from recorded work rather than a blank page. Preserve the user's voice and allow partial progress to appear. |
| Organization should serve work. Sunsama recommends broad channels and warns against spending too much effort on taxonomy. [Channels and Contexts][channels] | Reuse Linear projects and labels where useful. Add only the local distinctions that improve planning. |
| Its pricing manifesto favors sustainable maintenance, clear terms and easy cancellation over manipulative sales tactics. [Pricing Manifesto][pricing] | Apply the same clarity to reward rules, permissions and optional features. This is an ethical design lesson, not a recommendation to copy Sunsama's subscription model. |

**Proposed PokeTasks principle:** help the user choose enough meaningful work for today, support them while doing it, and make it comfortable to stop.

## What PokeTasks already provides

These findings describe the inspected checkout on the research date, not a newly tested installed release.

| Existing foundation | Where the new opportunity starts |
| --- | --- |
| One shared focus session across the main window, popover and floating timer; durations, pause/resume and explicit expiry choices. [Today and Focus surfaces](today-desk-sidebars.md) | A timer is already present. Add a plan around it rather than another timer implementation. |
| Local task timers with a title and description, without creating a Linear issue. [Today and Focus surfaces](today-desk-sidebars.md), [FocusSessionStore](../../Sources/PokeTaskBar/Core/FocusSessionStore.swift) | An unscheduled local task collection and a queue that can be prepared before starting a timer are separate additions. |
| Linear issue cards, status and priority actions, sorting, focus duration controls, project and initiative browsing. [Issue cards](linear-issue-cards.md) | Selecting an issue for today should become a personal planning action, distinct from changing its shared Linear workflow status. |
| Session notes, check-ins and recorded timer summaries. [FocusSessionStore](../../Sources/PokeTaskBar/Core/FocusSessionStore.swift) | Daily reflection can reuse recorded information. Long-term analysis needs more complete historical storage. |
| A Today dashboard showing the companion, navigation shortcuts and current or suggested focus. [MainWindowView](../../Sources/PokeTaskBar/UI/MainWindowView.swift) | A deliberately ordered daily playlist, capacity indicator and daily wrap would add a new planning function to Today. |
| XP, Coins, companion growth and collection mechanics. [Product and economy](../../README.md) | Review how rewards and presentation support sustainable work before adding new incentive rules. |

Two distinctions matter:

- **Linear Planned is a workflow view.** It is not evidence of a date-based personal daily plan. A task can belong in today's plan without changing its Linear status.
- **Current history is not a complete session ledger.** `recordHistory` replaces the previous summary for the same issue and keeps up to 200 issue summaries; the displayed log is filtered on day rollover. Weekly totals cannot safely be reconstructed from those latest summaries alone. See [FocusSessionStore](../../Sources/PokeTaskBar/Core/FocusSessionStore.swift) and [FocusIssueHistory](../../Sources/PokeTaskBar/Core/FocusSession.swift).

## Candidate additions

**Fit labels:** **Core** means a strong candidate for the first planning release; **Next** means useful after the daily plan works; **Later** means a larger integration or behavior project; **Extend** means build on an existing PokeTasks capability. These labels are recommendations, not effort estimates or commitments. Extend items can still require substantial work.

### 1 Daily planning and capacity

**Sunsama observation:** guided planning reviews prior work, gathers tasks, compares planned workload with a limit, orders the day and sets a shutdown time. It can also plan tomorrow in the evening. [Daily Planning][planning], [Account Settings][settings]

| # | Proposed addition | Minimum useful behavior | Fit |
| --- | --- | --- | --- |
| 1 | A short daily planning ritual | Choose today's work, estimate it, decide what can wait, then select the first task. Let the user skip or reopen planning. | Core |
| 2 | A personal daily capacity setting | Ask how much task work fits today. Allow a smaller value for a short day and remember the usual preference. | Core |
| 3 | A workload indicator with unknown estimates | Show planned minutes against capacity and flag tasks without estimates. Do not silently count unknown work as zero. | Core |
| 4 | An expected finish estimate | Show an approximate finishing time that updates with remaining work. Explain the assumptions and missing calendar information. | Next |
| 5 | A deliberate carryover decision | Offer Keep today, Tomorrow, Another day and Backlog for unfinished items. Preserve progress and make the plan change reversible. | Core |
| 6 | Evening preparation for tomorrow | Let users select tomorrow's important work while winding down today. Keep tomorrow's plan editable in the morning. | Next |
| 7 | A buffer for interruptions and low capacity days | Reserve user-chosen time for lunch, admin, interruptions or recovery. A shorter day should shrink the plan without creating catch-up debt. | Next |

**PokeTasks example, not a Sunsama default:** an eight-hour window contains 90 minutes of meetings, 30 minutes of lunch and a 60-minute buffer. That leaves five hours for tasks. A five-hour-45-minute task queue is 45 minutes over that task budget. Later calendar support must count overlapping busy periods once and avoid subtracting meetings again if they were already included in the workload total.

### 2 Capture and a manageable backlog

**Sunsama observation:** tasks can be captured with a global shortcut, imported through connected source URLs, stored in rough backlog time buckets and repeated as routines. Repeatedly unfinished tasks can move into a recoverable archive; smaller tasks can be merged as subtasks. [Global capture][global-capture], [Add via URL][url], [Backlog][backlog], [Recurring Tasks][recurring], [Task rollover][rollover], [Merge Tasks][merge]

| # | Proposed addition | Minimum useful behavior | Fit |
| --- | --- | --- | --- |
| 8 | Global quick capture | Open a small capture window from any app, save the thought and return to the previous work. Avoid requiring classification first. | Next |
| 9 | Persistent local tasks before timer start | Save a task without starting a session or creating a Linear issue. Add it to a chosen day later. Existing local timers are the execution foundation. | Core |
| 10 | A simple brain dump | Paste several lines and turn selected lines into draft tasks. Review the result before adding dates or estimates. | Next |
| 11 | Capture by source link | Paste a Linear issue link to select the existing issue; attach an ordinary URL as a reference to a local task. Preserve the original link. | Next |
| 12 | A small unscheduled backlog | Start with Later and Someday, with optional This week when needed. Offer an easy route back into today's plan. | Next |
| 13 | Recurring local routines | Repeat tasks such as inbox review or studio backup. Offer Skip today and Pause routine; preserve edited notes and avoid duplicate pending copies. | Later |
| 14 | Batch small tasks into a work block | Group several follow-ups under an admin block, retaining their links and individual checkboxes. Start with local checklists before synced subtask behavior. | Next |
| 15 | Review items that keep carrying over | Ask whether to split, defer, drop or retain repeatedly postponed work. Keep any parked items easy to find and restore. | Next |

The useful lesson from Sunsama's archive is recovery and reduced clutter. PokeTasks should initially **suggest** parking stale work instead of hiding it automatically. That is a proposed adaptation, not Sunsama's documented default.

### 3 A daily queue connected to meaningful goals

**Sunsama observation:** the daily list can function as an ordered playlist. Daily priority is separate from persistent backlog priority; optional auto-sort respects manual choices. Weekly objectives connect several tasks to an outcome, and contexts filter work or personal areas. [Playlist][playlist], [Task Priority][priority], [Auto-sort][auto-sort], [Weekly Objectives][objectives], [Weekly Review][weekly-review], [Channels and Contexts][channels]

| # | Proposed addition | Minimum useful behavior | Fit |
| --- | --- | --- | --- |
| 16 | An ordered Today playlist | Collect selected Linear issues and local tasks, add planned minutes and reorder them. Show the current task and the next task. | Core |
| 17 | A personal daily priority | Mark one main priority or a few important tasks without overwriting Linear priority. Let the daily designation expire or be deliberately renewed. | Core |
| 18 | Optional sorting that respects manual order | Offer a one-time priority sort first. If automatic ordering is later useful, preserve deliberate user placement and keep the current task stable. | Next |
| 19 | A focused Today view | Keep future and backlog work out of the execution list. Offer a compact Now and Next view with a deliberate way to see the full plan. | Extend |
| 20 | A few weekly objectives | Define a small number of outcomes such as Finish the mix revision. Reuse a Linear project or milestone as a reference when suitable. | Next |
| 21 | Connect planned tasks to objectives | Show which outcome a task serves and which objectives received attention. Treat objective completion as a user decision, not an inference from hours. | Next |
| 22 | A short weekly review and reset | Review outcomes, decide what continues and choose the next week's focus. Make journaling optional and avoid demanding detailed plans far ahead. | Next |
| 23 | Work and personal context filters | Start with a small distinction where useful, reusing Linear projects for work. Show both work capacity and total commitments so personal obligations remain visible. | Next |

Sunsama excludes personal contexts from its work workload threshold. PokeTasks could use that distinction while still displaying **total occupied time**, since personal commitments also affect what fits. This is our proposed adaptation. [Channels and Contexts][channels]

### 4 Calendar visibility and time allocation

**Sunsama observation:** it supports calendar timeboxing, rule-based task projections, scheduling around visible busy events and rescheduling of task working sessions. Meetings can enter the daily checklist, and tasks can span several days while retaining evidence of daily work. [Timeboxing basics][timeboxing-basics], [Playlist][playlist], [Auto-scheduling][auto-schedule], [Auto-rescheduling][auto-reschedule], [Importing Meetings][meetings], [Multi-day tasks][multi-day]

| # | Proposed addition | Minimum useful behavior | Fit |
| --- | --- | --- | --- |
| 24 | A read-only agenda beside Today | Show meetings from calendars the user chooses, including the next fixed commitment. Start with reading before writing calendar events. | Later |
| 25 | Capacity that accounts for meetings | Distinguish meetings, task work and free time. Make calendar selection and busy/free rules visible; avoid counting the same meeting twice. | Later |
| 26 | Include meetings in the workday | Offer selected meetings as agenda items with reference links and a place for notes. Label scheduled duration separately from confirmed attendance or measured work. | Later |
| 27 | A local projection of the task playlist | Draw approximate task blocks from order and remaining estimates without changing an external calendar. Explain that a projection does not reserve time. | Next |
| 28 | Explicit calendar timeboxing | Let users place a work block on a chosen calendar, with visible title privacy and busy/free options. Keep external event creation a deliberate action. | Later |
| 29 | Find the next suitable gap | Suggest an available block for a selected task within working hours. Let the user accept it, choose another day or keep the task unscheduled. | Later |
| 30 | Preview and undo schedule adjustments | When a task runs long, offer a visible revised plan. Respect fixed meetings and manual choices; let users undo changes. | Later |
| 31 | Daily work chunks for a multi-day issue | Plan 30 minutes on a larger issue today, finish that day's chunk and leave the Linear issue open. Preserve each chunk's notes and time. | Extend |

PokeTasks already distinguishes ending a timer while leaving an issue in progress from marking the issue done. Candidate 31 extends that distinction into daily planning; it should not replace it. [Existing completion controls](linear-issue-create-and-timer-controls.md)

The public manual has conflicting calendar wording: Calendar Integration first describes a built-in private calendar, then later says timeboxing requires an external calendar and that Sunsama has no calendar of its own. The basics and calendar-choice guides also describe internal scheduling. The playlist guide clearly says projections remain internal. This research therefore treats **projections**, **internal scheduled blocks** and **external calendar reservations** as separate concepts; exact live behavior needs a trial. [Calendar Integration][calendar], [Timeboxing basics][timeboxing-basics], [Choosing Your Calendar][choose-calendar], [Playlist][playlist]

### 5 Focus and recovery during the day

**Sunsama observation:** Focus Mode narrows the workspace to one task, its Focus Bar keeps that task visible outside the app, and breaks can be started, snoozed or skipped. Its timer supports elapsed-time and Pomodoro displays. [Focus Mode][focus], [Focus Bar][focus-bar], [Breaks][breaks]

| # | Proposed addition | Minimum useful behavior | Fit |
| --- | --- | --- | --- |
| 32 | A more focused current-task surface | Extend the existing Focus screen with the task's next action, relevant notes and a small next-task preview. Keep collection and usage detail out of the work area. | Extend |
| 33 | A next-task handoff | After a session, offer Start next, Take a break or Choose something else. Selecting the next task must not start its timer until the user chooses to start. | Core |
| 34 | A real break state | Add a user-controlled break duration and optional reminder, separate from work time. Offer snooze, skip and resume without punishment. | Next |
| 35 | Elapsed and remaining time views | Let users choose the timer display that helps them focus, while preserving one underlying session and the existing expiry choices. | Extend |
| 36 | A resume breadcrumb | Ask for an optional one-line next step when leaving a task. Show it when returning so users can restart without rereading everything. | Extend |
| 37 | A small focus preparation checklist | Offer reusable prompts such as Open session file, Put phone away and Mute chat, plus relevant links. Begin with a checklist rather than desktop automation. | Next |
| 38 | A budget for prompts and sounds | Make planning, break and shutdown cues independently optional. Coordinate them with existing check-ins and timer alarms to avoid overlapping interruptions. | Extend |

Candidate 37 is inspired by the founder's explanation of preparing a distraction-free work environment. The proposal does not assume unrestricted access to change macOS Focus settings or rearrange other apps. [Focus preparation rationale][status-rationale]

### 6 Daily reflection and useful insight

**Sunsama observation:** Daily Highlights combines selected activity, editable summaries and manual reflection; weekly reviews show a body of work and time allocation. Planned and actual times are distinct. [Daily Highlights][highlights], [Weekly Review][weekly-review], [Planned and Actual Times][times]

| # | Proposed addition | Minimum useful behavior | Fit |
| --- | --- | --- | --- |
| 39 | A daily shutdown ritual | At a user-chosen time, review work, park unfinished tasks, optionally prepare tomorrow and end the day. Keep reminders dismissible. | Core |
| 40 | A record of daily wins | Show completed work and meaningful partial progress, with links and actual recorded time where available. Include work that has no Linear completion yet. | Core |
| 41 | An editable daily highlight draft | Populate a short summary from recorded events; let the user select, rename and reorder items. A plain template is enough for the first version. | Core |
| 42 | Optional personal reflection | Offer one question or a feeling check-in. Save privately and allow users to skip it permanently. | Next |
| 43 | A searchable progress journal | Keep daily wraps, next steps and highlights by date. Offer Markdown copy or export for the user's existing note system. | Next |
| 44 | A weekly planned versus actual view | Show where time went and which objectives received attention. Separate timer-recorded time, manual entries and estimates; incomplete records must stay visible. | Later |
| 45 | Improve estimates from experience | Show previous recorded durations for the same task or a recurring routine. Offer an editable suggested estimate rather than a judgement about speed. | Next |

**Storage dependency:** daily wraps need date-based records. Candidate 44 needs retained session entries across days, rather than summing the latest per-issue summaries. Candidate 45 can initially display the last recorded session, clearly labeled; richer suggestions require a fuller history. These are implementation dependencies identified in the local source, not Sunsama claims.

Sunsama can optionally substitute planned time for actual time on completion. PokeTasks should label any such substitution as an estimate; a completed task is not proof that its time was measured. [Planned and Actual Times][times]

### 7 Integrations and fast controls

**Sunsama observation:** its Linear panel supports custom views and linked tasks with separate planning information. It imports Reminders, email and message follow-ups, provides keyboard commands and can share selected reviews. [Linear][linear], [Apple Reminders][reminders], [Gmail][gmail], [Slack][slack], [Command Palette][commands], [MCP][mcp]

| # | Proposed addition | Minimum useful behavior | Fit |
| --- | --- | --- | --- |
| 46 | Bring selected Linear views into planning | Browse useful saved views, identify already-selected issues and add references to the daily queue. Validate view support before implementation. | Later |
| 47 | Keep private planning separate from shared issue state | Store the personal day, estimate and next step locally. Reuse existing explicit status controls; offer completion or comment sync only when requested. | Extend |
| 48 | Import selected Apple Reminders | Add a reminder as a linked local task with a clear completion policy. Preserve the source reminder and disclose fields that cannot transfer. | Later |
| 49 | Turn communications into follow-ups | Begin with email or message links in local tasks. Add authenticated inbox or message import only when link capture proves insufficient. | Later |
| 50 | A small command palette and consistent shortcuts | Search for existing task and navigation actions; offer capture, start/pause and next-task controls. Surface shortcuts in menus and allow global conflicts to be resolved. | Next |
| 51 | Optional Slack or Teams focus status | Let users opt into a generic focus status and muted chat notifications during a session. Hide task titles by default and restore prior settings when focus ends. | Later |
| 52 | Copy a daily or weekly update | Generate a preview with selected wins, blockers and links. Copy it for the user to send; direct Slack, Teams or Linear posting can be a later explicit action. | Next |
| 53 | A narrow automation entry point | Explore Shortcuts or MCP for adding a local task and reading a plan. Start with the smallest useful actions and clear access boundaries. | Later |

Sunsama's Reminders documentation identifies native-desktop requirements and field limitations. Its integration privacy guide distinguishes browsing from imported or retained data. Those are useful reasons to design PokeTasks imports around selected content, provenance and a clear disconnect path. This research does not establish the exact fields a future PokeTasks integration would support. [Apple Reminders][reminders], [Integrations and Privacy][privacy]

### 8 Optional AI and companion behavior

**Sunsama observation:** editable AI time suggestions were an early example of its assistive philosophy. Current Sunny documentation describes text and voice planning, task management and retrospective summaries. Its backlog also documents a voice brain dump. [AI rationale][ai-rationale], [Sunny][sunny], [Backlog][backlog]

| # | Proposed addition | Minimum useful behavior | Fit |
| --- | --- | --- | --- |
| 54 | Optional AI time suggestions | Suggest a duration with a visible edit control and explain what information was used. Use saved durations or presets first where they work. | Later |
| 55 | Optional summaries of recorded work | Draft a recap from selected session notes and completion records. Let users inspect and edit it; never invent work to fill gaps. | Later |
| 56 | A conversational planning assistant | Help users compare candidate tasks with capacity and draft an order. Preview changes before applying them, especially shared-service writes. | Later |
| 57 | Voice capture before voice automation | Allow dictation into the capture field, then review a task draft. Add AI extraction of several tasks only if ordinary dictation is insufficient. | Later |
| 58 | Reward sustainable actions through the companion | Explore bounded recognition for starting meaningful work, completing a planned session or deliberately wrapping up. Review balance before adding new XP sources. | Later |
| 59 | A companion wind-down state | Let the pet visibly settle after daily shutdown, giving the user a sense of closure. Offer Resume day for genuine changes without suggesting failure. | Next |
| 60 | Adjustable encouragement and visual intensity | Let users reduce score prominence, celebrations and prompts while keeping accessible controls. Preserve Reduce Motion, keyboard access and calm language. | Extend |

Candidates 58–60 are **original PokeTasks adaptations of the research**, not Sunsama pet features. Candidate 58 is an economy proposal, not permission to change existing rewards. Existing [session completion and forfeit rules](linear-issue-create-and-timer-controls.md) deserve a deliberate review if a planning workflow makes normal task switching feel punitive.

Any new incentives should avoid uncapped overtime rewards, lost progress for a missed ritual, pet distress for absence, or mandatory streaks. Recognition for breaks should not become a new obligation. These are proposed design constraints for PokeTasks, derived from the goal of a sustainable day and its existing companion identity. [Sunsama philosophy][about], [PokeTasks economy](../../README.md)

## Recommended scope for a possible v2.2

Build one complete daily loop first. The following six feature groups would form a coherent candidate release; their feasibility still needs implementation discovery.

| Candidate feature group | Ideas covered | Why it belongs together |
| --- | --- | --- |
| Prepare an ordered daily playlist | 9, 16 | A user can choose several tasks before starting work, combining Linear references with local tasks. |
| Make the plan realistic | 1, 2, 3 | A short planning flow and visible workload help the user decide what actually fits. |
| Select what matters today | 17 | Personal daily priority can guide execution without changing shared Linear priority. |
| Carry work forward deliberately | 5 | Unfinished work remains safe while tomorrow's plan stays manageable. |
| Move from one task to the next | 33 | The existing timer becomes the execution path for the queue, with explicit starts. |
| Close the day with visible progress | 39, 40, 41 | A short wrap recognizes completed and partial work and reduces tomorrow's restart effort. |

The core recommendation is **a personal daily plan around the existing focus session**. Weekly objectives, break mode, a progress journal and local timeline projections are the strongest follow-ups. Calendar integration, timeboxing, retained weekly analytics, new service connectors and AI are larger subsequent projects.

There is no need to add a second timer, recreate Linear's project hierarchy, implement a general scheduling engine or invent another currency to deliver the first daily loop.

## Example PokeTasks day

This is a proposed user experience, not a Sunsama walkthrough.

1. **Prepare:** open Today, choose a capacity, select two Linear issues and one local task, and estimate each. Move anything that does not fit to another day.
2. **Start:** choose the day's main priority and begin its timer through the existing Focus controls.
3. **Continue:** finish a work chunk, leave the larger issue open when appropriate, record an optional next step, then choose a break or the next task.
4. **Adapt:** capture incoming work without abandoning the current task. Add it to today only after seeing its effect on capacity.
5. **Wrap up:** review actual recorded progress, edit a short highlight draft and decide what carries forward. Let the companion settle for the evening.

## Product and implementation checks before selecting scope

- **Keep the existing identity.** Extend the approved Today and Focus surfaces; the idea bank does not propose copying Sunsama's entire interface or replacing PokeTasks' companion design.
- **Define the planning object.** A daily item needs a day, order, intended work duration and a local task or Linear reference. Completing that item, ending its timer and completing its source issue are distinct actions.
- **Preserve user work.** Relaunches, offline use, missing Linear items and carryover must not silently remove a plan or its notes. Reuse the existing session and confirmation flows where appropriate.
- **Separate minutes from Linear estimates.** Do not treat issue points as minutes. Daily work duration is a personal estimate unless the user chooses to publish it.
- **Show uncertainty.** Missing estimates, incomplete records and unconnected calendars limit capacity and finish-time predictions. Label those limits in the relevant view.
- **Retain records only as needed.** Use date-based session records when daily wraps or weekly analysis require them. Avoid collecting a broader activity feed just to imitate Sunsama's highlights.
- **Keep imports traceable.** Maintain stable source identities, links and sync status. Removing an item from today's plan should not delete its source task or calendar event.
- **Respect choice and access.** Make journaling, reminders, sharing and AI optional. Read-only calendar work and external calendar writes have different purposes and permission needs.

**Proposed acceptance check for the first daily loop:** a user can plan, reorder, start and finish task chunks, restart the app, defer unfinished work and save a daily wrap without losing notes, duplicating a timer or unexpectedly changing Linear. This is a future validation target, not a test result from this research.

**Proposed pilot questions:** did the user finish planning quickly enough to use it regularly; did the selected tasks fit more often; did the next task remain obvious; and did shutdown make the next day easier? Treat these as learning questions, not performance targets or mental-health claims.

## Reading guide and research limits

For the shortest route through the original material, read [Daily Planning][planning], [Playlist Method][playlist], [Daily task list rationale][daily-list-rationale], [AI design rationale][ai-rationale] and [Daily Highlights][highlights]. Together they explain most of the recommended direction.

For deeper work, use [Linear Integration][linear] for the source-task versus personal-planning distinction; [Planned and Actual Times][times] and [Multi-day tasks][multi-day] for time and progress; [Weekly Objectives][objectives] and [Weekly Review][weekly-review] for outcomes; and [Auto-scheduling][auto-schedule] and [Auto-rescheduling][auto-reschedule] for calendar behavior.

Additional relevant Sunsama capabilities include a wider set of task connectors, Zapier, team sharing, desktop/mobile access and enterprise security options. They are documented on its [product site][home]. They provide context for a mature product, but do not by themselves justify equivalent PokeTasks features. Cross-device PokeTasks support would need a separate persistence and synchronization design.

The May 2025 [task manager roadmap][roadmap-2025] describes ambition beyond daily planning, including broader objectives. This report does not infer that every roadmap item shipped. Current weekly objective and Sunny capabilities are supported by their current manuals instead.

The standalone Daily Shutdown link reached from the planning guide returned the manual home page during research. Shutdown findings here rely on the working Daily Highlights, Account Settings, product site and founder explanations. Calendar documentation conflicts are noted in the calendar section. Exact live availability, integration behavior and the effort of each PokeTasks proposal remain unverified.

[home]: https://www.sunsama.com/
[about]: https://www.sunsama.com/about
[planning]: https://help.sunsama.com/docs/usage-guides/daily-planning/
[settings]: https://help.sunsama.com/docs/settings/user-settings/
[playlist]: https://help.sunsama.com/docs/usage-guides/playlisting/
[daily-list-rationale]: https://www.sunsama.com/blog/why-we-built-it-daily-task-list
[ai-rationale]: https://www.sunsama.com/blog/when-less-is-more-building-thoughtful-products-in-the-age-of-ai
[sunny]: https://help.sunsama.com/docs/usage-guides/sunny/
[highlights-rationale]: https://www.sunsama.com/blog/why-we-built-it-daily-highlights
[channels]: https://help.sunsama.com/docs/usage-guides/channels-and-contexts/
[pricing]: https://help.sunsama.com/docs/billing/pricing-manifesto/
[global-capture]: https://help.sunsama.com/docs/usage-guides/keyboard-driven-actions/global-add-task/
[url]: https://help.sunsama.com/docs/usage-guides/tasks/add-via-url/
[backlog]: https://help.sunsama.com/docs/usage-guides/backlog/
[recurring]: https://help.sunsama.com/docs/usage-guides/tasks/recurring-tasks/
[merge]: https://help.sunsama.com/docs/usage-guides/tasks/merge-tasks/
[rollover]: https://help.sunsama.com/docs/getting-started/basics/task-rollover-and-recurring-tasks-the-basics/
[priority]: https://help.sunsama.com/docs/usage-guides/tasks/task-priority/
[auto-sort]: https://help.sunsama.com/docs/usage-guides/tasks/auto-sort/
[objectives]: https://help.sunsama.com/docs/usage-guides/weekly-objectives/
[weekly-review]: https://help.sunsama.com/docs/usage-guides/weekly-objectives/weekly-review/
[timeboxing-basics]: https://help.sunsama.com/docs/getting-started/basics/timeboxing-the-basics/
[auto-schedule]: https://help.sunsama.com/docs/usage-guides/timeboxing/timeboxing-auto-scheduling/
[auto-reschedule]: https://help.sunsama.com/docs/usage-guides/timeboxing/auto-rescheduling/
[multi-day]: https://help.sunsama.com/docs/pro-tips/multi-day-tasks/
[meetings]: https://help.sunsama.com/docs/usage-guides/importing-meetings/
[calendar]: https://help.sunsama.com/docs/integrations/calendar/
[choose-calendar]: https://help.sunsama.com/docs/usage-guides/timeboxing/timeboxing-choosing-calendar/
[focus]: https://help.sunsama.com/docs/usage-guides/focus-mode/
[focus-bar]: https://help.sunsama.com/docs/usage-guides/focus-bar/
[breaks]: https://help.sunsama.com/docs/usage-guides/breaks/
[status-rationale]: https://www.sunsama.com/blog/why-we-built-it-slack-and-teams-status-sync
[highlights]: https://help.sunsama.com/docs/usage-guides/daily-highlights/
[times]: https://help.sunsama.com/docs/usage-guides/tasks/planned-and-actual-times/
[linear]: https://help.sunsama.com/docs/integrations/linear/
[reminders]: https://help.sunsama.com/docs/integrations/apple-reminders/
[gmail]: https://help.sunsama.com/docs/integrations/gmail/
[slack]: https://help.sunsama.com/docs/integrations/slack/
[commands]: https://help.sunsama.com/docs/usage-guides/keyboard-driven-actions/command-palette/
[mcp]: https://help.sunsama.com/docs/integrations/mcp/
[privacy]: https://help.sunsama.com/docs/security/privacy-notes/
[roadmap-2025]: https://www.sunsama.com/blog/sunsama-2025-task-manager-roadmap
