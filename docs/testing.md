# Testing

## Tested configuration

First-release work was exercised on an Apple Silicon Mac running **macOS 27.2 (26B123)**. The owner completed testing of the installed, signed and notarized 0.0.1 candidate and confirmed readiness for publication. Physical training, corner activation and application launching were exercised on that Mac.

The binary minimum is macOS 13.0 and its architecture is arm64. Other macOS versions, Intel, additional trackpad models and additional physical displays are untested. Keep this distinction in release notes; do not infer hardware compatibility from fixtures.

## Automated checks

Run `./test.sh`. It covers recognition/rejection, storage and failed writes, detached edit/cancel, preference import, corner thresholds, placement, multistroke/device gating, application-local command dispatch (including events without an associated window), focus gating, upstream command filtering without local delivery, repeated session registration/rollback, stale-callback teardown, cursor ownership/failure cleanup and shortcut registration/recording.

Updater tests cover separate consent, asynchronous shutdown acknowledgement, stale/duplicate replies, cancellation, retry, error rollback and unsaved-draft/shortcut-recording guards. Run `./scripts/test-updater-local.sh MODE` for isolated signed two-version tests. The modes `success`, `success-off`, `download-cancel`, `staged-cancel`, `bad-archive`, `bad-feed` and `incompatible` passed during candidate preparation. They do not replace an installed LeviOsa app or prove a future public feed is live.

An earlier baseline passed the full suite, inventory/link/credential-pattern audit and signed/notarized packaging. Later input changes require their own signed-candidate verification. CI is prepared but has not run remotely before repository publication.

## Native and physical checks

For settings changes, inspect create/edit states, Save eligibility, Cancel restoration and full list scrolling. Prior isolated-library checks covered save/order/delete. For capture changes, check Enter/C/Escape, ordinary typing afterward, pointer restoration, focus loss and Space changes. Native recording was observed over darkened Settings; automation is not a controlled physical recognition trial.

On November 13, local native checks received Enter/C/Escape in both normal drawing and recording above Settings. Enter showed validation feedback, C reset the prompt, Escape closed the surface, and typing C afterward reached the title field. Local diagnostics confirmed keyboard-monitor removal and pointer unlock on exit. These checks used synthesized keys and do not replace the owner’s physical signed-app retest or multi-display/Space checks.

In a later physical test that day, the owner reported C/Enter/Escape working in the trace-enabled review build. The trace independently recorded five physical Enter submissions across three drawing sessions, with focus gates satisfied and keyboard-monitor/cursor-lock ownership released after each completed session. C and Escape were not captured during an active session in that trace; their success is owner-reported. The earlier intermittent failure did not recur in this trial, so its cause remains unconfirmed. This is evidence for that review build, not acceptance of an exact signed distribution candidate.

Subsequent testing of the signed candidate found the keyboard failure again. A controlled native reproduction then showed a concrete mechanism: after the pad lost first-responder status, Enter/C/Escape reached the active key window but were rejected by the pad-specific focus gate. Commands now belong to the drawing window; pad focus is repaired only inside an already-active key window, invalid capture focus ends the session, and Escape remains a cleanup command when readiness changes. Five native responder-drift sessions passed all three commands, kept their window frame/display unchanged and released input/cursor ownership. Typing afterward also passed. These were injected responder transitions and synthesized keys; they did not establish physical acceptance, and a later physical test exposed the separate delivery failure below.

On November 14, the owner reproduced the failure again in the corrected notarized candidate. The saved trace distinguishes it from responder drift: two later sessions retained foreground/key-window/Pad/active-Space readiness and received multiple strokes, but the application-local monitor received no key events. This establishes the failing delivery boundary, not the underlying WindowServer cause. Drawing commands now have an Accessibility-gated, session-only Quartz event tap before application/window routing, with a local fallback for directly addressed events. If the tap cannot be acquired, becomes disabled or Secure Input is enabled, capture refuses to start or ends with pointer release. Injected tests cover upstream delivery with no local events across 100 sessions, command-only filtering, modifier/repeat handling, layout C keys, stale callbacks and partial-acquisition rollback. Twelve consecutive native review sessions and nine exact-installed sessions passed command handling and resource cleanup. The automated keys used the local fallback and did not prove physical WindowServer delivery.

Command-line test launches reported Accessibility access, but a normal macOS launch of the installed app required an explicit permission grant. After the owner enabled access, physical input reached the new system handler across seven drawing sessions: ten Enter submissions, one C clear and one Escape. Every completed session released keyboard and cursor ownership. The owner then confirmed completion of testing and readiness to publish this candidate. This verifies the observed repeated physical trial; it does not establish long-term reliability or compatibility with untested hardware.

For local investigation, `captureDiagnosticsDirectory` can opt in to command/focus logs across ordinary app restarts. It is unset by default and is not imported from review preferences. QA controls additionally require the explicit `LEVIOSA_CAPTURE_DIAGNOSTICS` environment setting; enabling local logs alone does not expose those controls.

For release validation, repeat training → save → quit/reopen → recognition → app launch with the actual signed candidate, and check first-launch/permission behavior with Gatekeeper enabled. Record only the tested scope. The owner has accepted the 0.0.1 candidate; approval of the complete documentation remains a separate publication requirement.

Private-API stability, physical Fn/Secure Input, calibrated physical sizing, sustained accidental activations, additional hardware and forced-crash recovery are not fully validated. Visual review scores cover supplied images, not runtime behavior.
