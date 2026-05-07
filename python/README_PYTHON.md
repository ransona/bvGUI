# bvGUI Python

Python replacement for the MATLAB `bvGUI` app.

## Features

- JSON save/load for experiment configs
- In-app conversion from legacy MATLAB `.mat` configs to JSON
- Feature/stimulus editor
- Test selected stimulus or run the full protocol
- Compatibility with existing machine `bvGUI.ini` files
- Legacy export generation for per-run `.mat` and CSV outputs
- Integrated Python Timeline recorder for the `daq00_TL` DAQ path

## Install

```bash
cd /home/adamranson/code/bvGUI/python
python -m pip install -r requirements.txt
```

## Launch

```bash
cd /home/adamranson/code/bvGUI/python
python -m bvgui.main
```

Or:

```bash
cd /home/adamranson/code/bvGUI/python
python run_bvgui.py
```

## Notes

- JSON is the native authoring format for experiment configs.
- Legacy MATLAB configs are converted through the `Convert MATLAB Config` button in the app.
- Runtime control still targets the existing Bonvision and opto UDP/OSC protocols.
- Timeline is now handled in Python inside `bvGUI`; no MATLAB `startTimeline` / `stopTimeline` call is required.
- The GUI exposes a `Timeline backend` selector so you can choose `simulated` for testing or `nidaqmx` on the real rig.
- Headless core regression tests can be run with `PYTHONPATH=. python -m unittest discover -s tests -v`.
