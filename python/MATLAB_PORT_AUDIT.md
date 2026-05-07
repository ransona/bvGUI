# MATLAB Port Audit

Audit date: 2026-04-01

Source app:
- [`temp/bvGUI2_exported.m`](/home/adamranson/code/bvGUI/temp/bvGUI2_exported.m)

Python target:
- [`python/bvgui/app.py`](/home/adamranson/code/bvGUI/python/bvgui/app.py)
- [`python/bvgui/runtime.py`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py)
- [`python/bvgui/config.py`](/home/adamranson/code/bvGUI/python/bvgui/config.py)
- [`python/bvgui/legacy_matlab.py`](/home/adamranson/code/bvGUI/python/bvgui/legacy_matlab.py)
- [`python/bvgui/daq.py`](/home/adamranson/code/bvGUI/python/bvgui/daq.py)
- [`python/bvgui/timeline/`](/home/adamranson/code/bvGUI/python/bvgui/timeline)

Status labels:
- `ported`: functional equivalent exists in Python
- `partial`: some behavior exists, but not full MATLAB parity
- `missing`: no Python equivalent exists yet
- `n/a`: generated or not meaningful to port directly

## Function-by-function status

| MATLAB function | Status | Python equivalent / note |
|---|---|---|
| `pauseWithEvents` | `partial` | [`ExperimentRunner._sleep_with_abort()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py) provides cooperative waits, but there is no exact GUI-event-processing equivalent because runs execute in a subprocess. |
| `send_udp_command` | `ported` | [`send_udp_command()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py) |
| `getRepoRoot` | `ported` | [`repo_root()`](/home/adamranson/code/bvGUI/python/bvgui/config.py) |
| `getRepoConfig` | `ported` | [`load_machine_config()`](/home/adamranson/code/bvGUI/python/bvgui/config.py) |
| `getMachineName` | `partial` | [`machine_name()`](/home/adamranson/code/bvGUI/python/bvgui/config.py); behavior differs because Python now prefers `ar-lab-tl2` when available. |
| `addRepoSupportPaths` | `n/a` | MATLAB path setup is not needed in Python. |
| `readIniFile` | `ported` | [`load_machine_config()`](/home/adamranson/code/bvGUI/python/bvgui/config.py) via `configparser` |
| `getIniValue` | `ported` | handled inside [`load_machine_config()`](/home/adamranson/code/bvGUI/python/bvgui/config.py) |
| `setIniValue` | `ported` | [`save_machine_settings()`](/home/adamranson/code/bvGUI/python/bvgui/config.py) writes `bv_server` back to the machine INI, matching MATLAB's settings-save behavior. |
| `writeIniFile` | `ported` | [`save_machine_settings()`](/home/adamranson/code/bvGUI/python/bvgui/config.py) |
| `debugMessage` | `ported` | [`MainWindow.log()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) and subprocess log capture |
| `newExpID` | `ported` | [`new_exp_id()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py) |
| `buildCompleteStimSeq` | `ported` | [`build_complete_sequence()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py) |
| `trialNeedsDefaultBonvisionTrigger` | `ported` | equivalent logic in [`ExperimentRunner.run()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py) using `needs_default_grating` |
| `collectOpto2pPrepData` | `ported` | [`collect_opto_prep()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py) |
| `collectTrialOpto2pData` | `ported` | [`collect_opto_trial()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py) |
| `addDefaultBonvisionTriggerGrating` | `ported` | equivalent inline default grating block in [`ExperimentRunner.run()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py) |
| `runOpto2pPrep` | `ported` | [`ExperimentRunner._prepare_opto()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py) |
| `triggerOpto2pForTrial` | `ported` | [`ExperimentRunner._trigger_opto()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py) |
| `abortOpto2p` | `ported` | [`ExperimentRunner._abort_opto()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py) |
| `waitForOpto2pIdle` | `ported` | [`ExperimentRunner._wait_for_opto_idle()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py) |
| `restoreRunButton` | `partial` | Python resets run controls in [`_run_process_finished()`](/home/adamranson/code/bvGUI/python/bvgui/app.py), but there is not a single shared reset helper with exact MATLAB state transitions yet. |
| `requestRunAbort` | `partial` | Python now has cooperative abort signaling in [`abort_run()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) and [`ExperimentRunner._check_abort()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py), but button-text parity is not complete. |
| `cleanupUdpSocket` | `n/a` | Python sockets use context managers. |
| `decodeUdpJsonReply` | `ported` | [`send_udp_json()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py) plus explicit reply checks in opto methods |
| `saveForPython` | `ported` | [`save_protocol_exports()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py) |
| `startupFcn` | `ported` | app startup, config loading, feature loading, DAQ discovery, and live Timeline view exist in [`MainWindow.__init__()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) and the integrated Timeline tab. |
| `FeatureListBoxValueChanged` | `ported` | [`refresh_view()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `NewButtonPushed` | `ported` | [`new_protocol()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `ButtonAddStimPushed` | `ported` | [`add_stimulus()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `ButtonAddFeaturePushed` | `ported` | [`add_feature()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `StimulusListBoxValueChanged` | `ported` | [`refresh_view()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `NewFeatureListBoxValueChanged` | `partial` | feature-type selection exists in the combo box, but MATLAB's separate listbox selection semantics are simplified. |
| `ButtonRemoveStimPushed` | `ported` | [`remove_stimulus()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `UITableCellEdit` | `ported` | [`_param_item_changed()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `SaveButtonPushed` | `partial` | save exists, but only as JSON via [`save_json()`](/home/adamranson/code/bvGUI/python/bvgui/app.py), not MATLAB `.mat`. |
| `LoadButtonPushed` | `ported` | direct JSON load plus direct MATLAB config load exist in [`load_json()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) and [`load_matlab()`](/home/adamranson/code/bvGUI/python/bvgui/app.py). |
| `RunButtonPushed` | `ported` | full run path exists in [`ExperimentRunner.run()`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py), including pre-blank, pause-after-preload, VR command execution, final comments, and cooperative abort with reverse-order DAQ shutdown. |
| `SavesettingsButtonPushed` | `ported` | [`save_settings()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `RepsEditFieldValueChanging` | `ported` | reps editing is handled by [`_pull_form_to_protocol()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `ButtonRemoveFeaturePushed` | `ported` | [`remove_feature()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `ResetButtonPushed` | `missing` | there is no Python reset button for run/test UI state. |
| `Rewardv1ButtonPushed` | `missing` | no reward/manual valve control UI exists in Python. |
| `BuildSetButtonPushed` | `ported` | [`build_set()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `TestStimBtnButtonPushed` | `ported` | test-selected exists in [`test_selected()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) and [`ExperimentRunner.run(..., test_mode=True)`](/home/adamranson/code/bvGUI/python/bvgui/runtime.py), including global test-mode preload behavior. |
| `CopyButtonPushed` | `ported` | [`copy_stimulus()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `FeatCopyButtonPushed` | `ported` | [`copy_feature()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `VariablesEditFieldValueChanged` | `partial` | variables field exists, but Python treats it mainly as persisted text; there is no distinct changed callback behavior. |
| `VariablesEditFieldValueChanging` | `ported` | variables are pulled into the protocol model in [`_pull_form_to_protocol()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `LogButtonPushed` | `ported` | [`open_animal_log()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `createComponents` | `n/a` | replaced by manual Qt construction in [`_build_ui()`](/home/adamranson/code/bvGUI/python/bvgui/app.py) |
| `delete` | `partial` | Qt/window shutdown exists, but there is no explicit Python equivalent with cleanup parity for all resources. |

## Missing functionality summary

These MATLAB features are not currently ported:

- Reset button behavior
- Manual reward / valve controls

## Partial-parity areas

These exist but are not full MATLAB matches:

- Abort UX and button-state transitions
- Explicit teardown/reset helper coverage

## High-risk runtime differences

- Run completion and abort UI behavior are not yet exact MATLAB matches.
- Manual bench controls for reward/valves are absent.
