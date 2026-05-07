from __future__ import annotations

import ast
import faulthandler
import itertools
import json
import os
import subprocess
import sys
import traceback
from pathlib import Path

from .automation import new_temp_abort_file, write_temp_protocol
from .config import load_machine_config, save_machine_settings
from .legacy_matlab import load_feature_catalog, load_protocol_from_mat
from .protocol_io import load_protocol_json, save_protocol_json
from .runtime import ExperimentRunner, new_exp_id
from .timeline import get_shared_timeline_recorder
from .timeline.backends import nidaqmx_runtime_available

try:
    from PySide6 import QtCore, QtGui, QtWidgets
except Exception as exc:  # pragma: no cover - import failure is surfaced to the user at runtime
    QtCore = None
    QtGui = None
    QtWidgets = None
    _qt_import_error = exc
else:
    _qt_import_error = None


def parse_build_feature_indexes(text: str) -> list[int]:
    cleaned = text.strip()
    if not cleaned:
        raise ValueError("Feature list is empty.")
    if cleaned.startswith("[") and cleaned.endswith("]"):
        cleaned = cleaned[1:-1]
    items = [chunk.strip() for chunk in cleaned.replace(";", ",").split(",") if chunk.strip()]
    indexes = [int(float(item)) for item in items]
    if not indexes:
        raise ValueError("Feature list is empty.")
    return indexes


def parse_build_values(text: str) -> list[float]:
    cleaned = text.strip()
    if not cleaned:
        raise ValueError("Parameter values are empty.")
    if ":" in cleaned and "," not in cleaned and "[" not in cleaned and "(" not in cleaned:
        parts = [piece.strip() for piece in cleaned.split(":")]
        if len(parts) == 3:
            start, step, stop = (float(piece) for piece in parts)
            if step == 0:
                raise ValueError("Step size cannot be zero.")
            values: list[float] = []
            current = start
            if step > 0:
                while current <= stop + (abs(step) * 1e-9):
                    values.append(current)
                    current += step
            else:
                while current >= stop - (abs(step) * 1e-9):
                    values.append(current)
                    current += step
            return values
    if "," in cleaned and "[" not in cleaned and "(" not in cleaned:
        return [float(piece.strip()) for piece in cleaned.split(",") if piece.strip()]
    parsed = ast.literal_eval(cleaned)
    if isinstance(parsed, (int, float)):
        return [float(parsed)]
    if isinstance(parsed, (list, tuple)):
        return [float(item) for item in parsed]
    raise ValueError(f"Unsupported parameter value format: {text}")


def _format_build_value(value: float) -> str:
    if float(value).is_integer():
        return str(int(value))
    return f"{value:g}"


if QtWidgets is not None:
    class ToggleSwitch(QtWidgets.QCheckBox):
        def __init__(self, parent=None) -> None:
            super().__init__(parent)
            self.setTristate(False)
            self.setCursor(QtCore.Qt.PointingHandCursor)
            self.setMinimumWidth(56)
            self.setStyleSheet(
                """
                QCheckBox {
                    spacing: 0px;
                    padding: 0px;
                }
                QCheckBox::indicator {
                    width: 52px;
                    height: 28px;
                    border-radius: 14px;
                    background: #6b7280;
                    border: 1px solid #4b5563;
                }
                QCheckBox::indicator:checked {
                    background: #16a34a;
                    border: 1px solid #15803d;
                }
                """
            )

        def paintEvent(self, event) -> None:  # noqa: N802
            super().paintEvent(event)
            painter = QtGui.QPainter(self)
            painter.setRenderHint(QtGui.QPainter.Antialiasing, True)
            indicator_rect = self.style().subElementRect(QtWidgets.QStyle.SE_CheckBoxIndicator, self._style_option(), self)
            knob_diameter = indicator_rect.height() - 6
            knob_y = indicator_rect.top() + 3
            knob_x = indicator_rect.right() - knob_diameter - 3 if self.isChecked() else indicator_rect.left() + 3
            painter.setBrush(QtGui.QColor("#f9fafb"))
            painter.setPen(QtGui.QPen(QtGui.QColor("#e5e7eb"), 1))
            painter.drawEllipse(QtCore.QRectF(knob_x, knob_y, knob_diameter, knob_diameter))

        def _style_option(self) -> QtWidgets.QStyleOptionButton:
            option = QtWidgets.QStyleOptionButton()
            self.initStyleOption(option)
            return option


    class DaqToggleRow(QtWidgets.QFrame):
        def __init__(self, daq_name: str, enabled: bool = True, parent=None) -> None:
            super().__init__(parent)
            self.daq_name = daq_name
            self.setFrameShape(QtWidgets.QFrame.StyledPanel)
            self.setStyleSheet(
                """
                QFrame {
                    background: #050505;
                    border: 1px solid #1f1f1f;
                    border-radius: 8px;
                }
                QLabel {
                    color: #f3f4f6;
                }
                """
            )
            layout = QtWidgets.QHBoxLayout(self)
            layout.setContentsMargins(12, 8, 12, 8)
            layout.setSpacing(12)
            self.name_label = QtWidgets.QLabel(daq_name)
            self.name_label.setMinimumWidth(120)
            self.state_label = QtWidgets.QLabel()
            self.toggle = ToggleSwitch()
            self.toggle.setChecked(enabled)
            self.toggle.toggled.connect(self._update_state_label)
            layout.addWidget(self.name_label, 1)
            layout.addWidget(self.state_label)
            layout.addWidget(self.toggle, 0, QtCore.Qt.AlignRight)
            self._update_state_label(self.toggle.isChecked())

        def _update_state_label(self, enabled: bool) -> None:
            if enabled:
                self.state_label.setText("On")
                self.state_label.setStyleSheet("color: #86efac;")
            else:
                self.state_label.setText("Off")
                self.state_label.setStyleSheet("color: #fca5a5;")

        def is_enabled(self) -> bool:
            return self.toggle.isChecked()

        def set_enabled(self, enabled: bool) -> None:
            self.toggle.setChecked(enabled)


    class TimelinePlotWidget(QtWidgets.QWidget):
        def __init__(self, parent=None) -> None:
            super().__init__(parent)
            self._data = None
            self._channel_names: list[str] = []
            self.setMinimumHeight(360)

        def set_data(self, data, channel_names: list[str]) -> None:
            self._data = data
            self._channel_names = channel_names
            self.update()

        def paintEvent(self, event) -> None:  # noqa: N802
            painter = QtGui.QPainter(self)
            painter.fillRect(self.rect(), QtGui.QColor("#0b1117"))
            margin_left = 90
            margin_right = 20
            margin_top = 20
            margin_bottom = 20
            plot_rect = self.rect().adjusted(margin_left, margin_top, -margin_right, -margin_bottom)
            painter.setPen(QtGui.QPen(QtGui.QColor("#2f3b47"), 1))
            painter.drawRect(plot_rect)

            if self._data is None or self._data.shape[0] == 0 or self._data.shape[1] == 0:
                painter.setPen(QtGui.QColor("#c9d1d9"))
                painter.drawText(plot_rect, QtCore.Qt.AlignCenter, "No Timeline samples yet.")
                return

            channel_count = self._data.shape[1]
            colors = [
                QtGui.QColor("#59c3c3"),
                QtGui.QColor("#f4d35e"),
                QtGui.QColor("#ee964b"),
                QtGui.QColor("#f95738"),
                QtGui.QColor("#8ecae6"),
                QtGui.QColor("#90be6d"),
            ]
            row_height = plot_rect.height() / max(channel_count, 1)
            max_points = self._data.shape[0] - 1
            for idx in range(channel_count):
                top = plot_rect.top() + idx * row_height
                center_y = top + row_height / 2.0
                painter.setPen(QtGui.QPen(QtGui.QColor("#25303b"), 1))
                painter.drawLine(plot_rect.left(), int(center_y), plot_rect.right(), int(center_y))
                painter.setPen(QtGui.QColor("#c9d1d9"))
                label = self._channel_names[idx] if idx < len(self._channel_names) else f"Ch {idx + 1}"
                painter.drawText(10, int(center_y) + 5, label)

                series = self._data[:, idx]
                lo = float(series.min())
                hi = float(series.max())
                scale = hi - lo
                if scale < 1e-6:
                    scale = 1.0
                path = QtGui.QPainterPath()
                for sample_index, value in enumerate(series):
                    x = plot_rect.left() + (sample_index / max(max_points, 1)) * plot_rect.width()
                    y = top + row_height - ((float(value) - lo) / scale) * (row_height - 8) - 4
                    if sample_index == 0:
                        path.moveTo(x, y)
                    else:
                        path.lineTo(x, y)
                painter.setRenderHint(QtGui.QPainter.Antialiasing, True)
                painter.setPen(QtGui.QPen(colors[idx % len(colors)], 1.5))
                painter.drawPath(path)


    class ConfigFunctionsDialog(QtWidgets.QDialog):
        def __init__(self, parent: "MainWindow") -> None:
            super().__init__(parent)
            self.setWindowTitle("Config functions")
            self.setModal(True)
            self.resize(360, 180)
            layout = QtWidgets.QVBoxLayout(self)
            info = QtWidgets.QLabel("Less-used config tools and builders.")
            info.setWordWrap(True)
            layout.addWidget(info)

            self.convert_mat_btn = QtWidgets.QPushButton("Convert MATLAB Config")
            self.build_set_btn = QtWidgets.QPushButton("Build Set")
            self.placeholder_label = QtWidgets.QLabel("More config builders can be added here later.")
            self.placeholder_label.setStyleSheet("color: #9ca3af;")
            layout.addWidget(self.convert_mat_btn)
            layout.addWidget(self.build_set_btn)
            layout.addWidget(self.placeholder_label)
            layout.addStretch(1)

            self.convert_mat_btn.clicked.connect(parent.convert_matlab_config)
            self.build_set_btn.clicked.connect(parent.build_set)


    class MainWindow(QtWidgets.QMainWindow):
        def __init__(self) -> None:
            super().__init__()
            self.config = load_machine_config()
            self.catalog = load_feature_catalog(self.config.features_dir)
            self.catalog_by_name = {item.name: item for item in self.catalog}
            from .models import Protocol

            self.protocol = Protocol()
            self.runner = ExperimentRunner(self.config, self.catalog, self.log)
            self.timeline_recorder = get_shared_timeline_recorder()
            self.nidaqmx_available, self.nidaqmx_reason = nidaqmx_runtime_available()
            self.worker_thread = None
            self.worker = None
            self.run_process: QtCore.QProcess | None = None
            self.run_process_output: list[str] = []
            self.run_process_protocol_path: Path | None = None
            self.run_process_abort_path: Path | None = None
            self.run_process_test_mode = False
            self.setWindowTitle(f"bvGUI Python - {self.config.machine_name}")
            self.resize(1480, 920)
            self._apply_theme()
            self._build_ui()
            self._reload_daq_table()
            self.refresh_view()
            self.timeline_timer = QtCore.QTimer(self)
            self.timeline_timer.setInterval(500)
            self.timeline_timer.timeout.connect(self._refresh_timeline_tab)
            self.timeline_timer.start()

        def _build_ui(self) -> None:
            central = QtWidgets.QWidget()
            self.setCentralWidget(central)
            root = QtWidgets.QVBoxLayout(central)
            self.tabs = QtWidgets.QTabWidget()
            root.addWidget(self.tabs)

            self.protocol_tab = QtWidgets.QWidget()
            self.timeline_tab = QtWidgets.QWidget()
            self.tabs.addTab(self.protocol_tab, "bvGUI")
            self.tabs.addTab(self.timeline_tab, "Timeline")

            self._build_protocol_tab()
            self._build_timeline_tab()

        def _build_protocol_tab(self) -> None:
            root = QtWidgets.QHBoxLayout(self.protocol_tab)

            left = QtWidgets.QVBoxLayout()
            middle = QtWidgets.QVBoxLayout()
            right = QtWidgets.QVBoxLayout()
            root.addLayout(left, 1)
            root.addLayout(middle, 1)
            root.addLayout(right, 2)

            self.stim_list = QtWidgets.QListWidget()
            left.addWidget(QtWidgets.QLabel("Stimuli"))
            left.addWidget(self.stim_list, 1)
            stim_buttons = QtWidgets.QHBoxLayout()
            self.add_stim_btn = QtWidgets.QPushButton("Add Stim")
            self.remove_stim_btn = QtWidgets.QPushButton("Remove Stim")
            self.copy_stim_btn = QtWidgets.QPushButton("Copy Stim")
            self.stim_reps_label = QtWidgets.QLabel("Reps")
            self.stim_reps_edit = QtWidgets.QLineEdit("1")
            self.stim_reps_edit.setMaximumWidth(64)
            stim_buttons.addWidget(self.add_stim_btn)
            stim_buttons.addWidget(self.remove_stim_btn)
            stim_buttons.addWidget(self.copy_stim_btn)
            stim_buttons.addWidget(self.stim_reps_label)
            stim_buttons.addWidget(self.stim_reps_edit)
            left.addLayout(stim_buttons)

            feature_header = QtWidgets.QLabel("Features")
            feature_header.setAlignment(QtCore.Qt.AlignCenter)
            middle.addWidget(feature_header)
            feature_labels = QtWidgets.QHBoxLayout()
            self.possible_features_label = QtWidgets.QLabel("Possible")
            self.possible_features_label.setAlignment(QtCore.Qt.AlignCenter)
            self.present_features_label = QtWidgets.QLabel("Present")
            self.present_features_label.setAlignment(QtCore.Qt.AlignCenter)
            feature_labels.addWidget(self.possible_features_label, 1)
            feature_labels.addWidget(self.present_features_label, 1)
            middle.addLayout(feature_labels)

            feature_lists = QtWidgets.QHBoxLayout()
            self.feature_type_list = QtWidgets.QListWidget()
            self.feature_type_list.addItems([item.name for item in self.catalog])
            self.feature_list = QtWidgets.QListWidget()
            feature_lists.addWidget(self.feature_type_list, 1)
            feature_lists.addWidget(self.feature_list, 1)
            self.param_table = QtWidgets.QTableWidget(0, 2)
            self.param_table.setHorizontalHeaderLabels(["Parameter", "Value"])
            self.param_table.horizontalHeader().setStretchLastSection(True)
            self.param_table.verticalHeader().setVisible(False)
            middle.addLayout(feature_lists)
            feat_buttons = QtWidgets.QHBoxLayout()
            self.add_feature_btn = QtWidgets.QPushButton("Add Feature")
            self.remove_feature_btn = QtWidgets.QPushButton("Remove Feature")
            self.copy_feature_btn = QtWidgets.QPushButton("Copy Feature")
            feat_buttons.addWidget(self.add_feature_btn)
            feat_buttons.addWidget(self.remove_feature_btn)
            feat_buttons.addWidget(self.copy_feature_btn)
            middle.addLayout(feat_buttons)
            middle.addWidget(QtWidgets.QLabel("Parameters"))
            middle.addWidget(self.param_table, 1)

            controls_form = QtWidgets.QFormLayout()
            self.animal_edit = QtWidgets.QLineEdit("TEST")
            self.bv_server_edit = QtWidgets.QLineEdit(self.config.bv_server)
            self.variables_edit = QtWidgets.QLineEdit("")
            self.iti_edit = QtWidgets.QLineEdit("1")
            self.seq_repeats_edit = QtWidgets.QLineEdit("10")
            self.randomize_check = QtWidgets.QCheckBox()
            self.randomize_check.setChecked(True)
            self.comment_edit = QtWidgets.QLineEdit("")
            self.final_comment_default_edit = QtWidgets.QLineEdit("")
            self.pre_blank_edit = QtWidgets.QLineEdit("0")
            self.pause_after_preload_edit = QtWidgets.QLineEdit("0.5")
            self.bonvision_backend_combo = QtWidgets.QComboBox()
            self.bonvision_backend_combo.addItems(["simulated", "real"])
            self.bonvision_backend_combo.setCurrentText("real")
            controls_form.addRow("Animal ID", self.animal_edit)
            controls_form.addRow("BV server", self.bv_server_edit)
            controls_form.addRow("Variables", self.variables_edit)
            controls_form.addRow("ITI", self.iti_edit)
            controls_form.addRow("Sequence repeats", self.seq_repeats_edit)
            controls_form.addRow("Randomize", self.randomize_check)
            controls_form.addRow("Experiment comment", self.comment_edit)
            controls_form.addRow("Final comment default", self.final_comment_default_edit)
            controls_form.addRow("Pre-blank (s)", self.pre_blank_edit)
            controls_form.addRow("Pause after preload (s)", self.pause_after_preload_edit)
            controls_form.addRow("Bonvision backend", self.bonvision_backend_combo)
            right.addLayout(controls_form)

            right.addWidget(QtWidgets.QLabel("DAQs"))
            self.daq_scroll = QtWidgets.QScrollArea()
            self.daq_scroll.setWidgetResizable(True)
            self.daq_scroll.setFrameShape(QtWidgets.QFrame.NoFrame)
            self.daq_panel = QtWidgets.QWidget()
            self.daq_layout = QtWidgets.QGridLayout(self.daq_panel)
            self.daq_layout.setContentsMargins(0, 0, 0, 0)
            self.daq_layout.setSpacing(8)
            self.daq_layout.setColumnStretch(0, 1)
            self.daq_layout.setColumnStretch(1, 1)
            self.daq_scroll.setWidget(self.daq_panel)
            right.addWidget(self.daq_scroll)
            daq_buttons = QtWidgets.QHBoxLayout()
            self.enable_all_daqs_btn = QtWidgets.QPushButton("Enable All")
            self.disable_all_daqs_btn = QtWidgets.QPushButton("Disable All")
            daq_buttons.addWidget(self.enable_all_daqs_btn)
            daq_buttons.addWidget(self.disable_all_daqs_btn)
            right.addLayout(daq_buttons)

            file_buttons = QtWidgets.QHBoxLayout()
            self.new_btn = QtWidgets.QPushButton("New")
            self.load_json_btn = QtWidgets.QPushButton("Load")
            self.save_json_btn = QtWidgets.QPushButton("Save")
            self.config_functions_btn = QtWidgets.QPushButton("Config functions")
            file_buttons.addWidget(self.new_btn)
            file_buttons.addWidget(self.load_json_btn)
            file_buttons.addWidget(self.save_json_btn)
            file_buttons.addWidget(self.config_functions_btn)
            right.addLayout(file_buttons)

            tools_buttons = QtWidgets.QHBoxLayout()
            self.save_settings_btn = QtWidgets.QPushButton("Save Settings")
            self.open_log_btn = QtWidgets.QPushButton("Open Animal Log")
            tools_buttons.addWidget(self.save_settings_btn)
            tools_buttons.addWidget(self.open_log_btn)
            right.addLayout(tools_buttons)

            run_buttons = QtWidgets.QHBoxLayout()
            self.test_btn = QtWidgets.QPushButton("Test Selected")
            self.run_btn = QtWidgets.QPushButton("Run")
            self.abort_btn = QtWidgets.QPushButton("Abort")
            self.abort_btn.setEnabled(False)
            run_buttons.addWidget(self.test_btn)
            run_buttons.addWidget(self.run_btn)
            run_buttons.addWidget(self.abort_btn)
            right.addLayout(run_buttons)

            self.run_status_label = QtWidgets.QLabel("")
            self.run_status_label.setWordWrap(True)
            right.addWidget(self.run_status_label)

            right.addWidget(QtWidgets.QLabel("Log"))
            self.log_view = QtWidgets.QPlainTextEdit()
            self.log_view.setReadOnly(True)
            right.addWidget(self.log_view)

            self.stim_list.currentRowChanged.connect(self.refresh_view)
            self.feature_type_list.currentRowChanged.connect(self._feature_type_changed)
            self.feature_list.currentRowChanged.connect(self.refresh_view)
            self.param_table.itemChanged.connect(self._param_item_changed)
            self.stim_reps_edit.editingFinished.connect(self._stim_reps_changed)
            self.add_stim_btn.clicked.connect(self.add_stimulus)
            self.remove_stim_btn.clicked.connect(self.remove_stimulus)
            self.copy_stim_btn.clicked.connect(self.copy_stimulus)
            self.add_feature_btn.clicked.connect(self.add_feature)
            self.remove_feature_btn.clicked.connect(self.remove_feature)
            self.copy_feature_btn.clicked.connect(self.copy_feature)
            self.new_btn.clicked.connect(self.new_protocol)
            self.load_json_btn.clicked.connect(self.load_json)
            self.save_json_btn.clicked.connect(self.save_json)
            self.config_functions_btn.clicked.connect(self.open_config_functions)
            self.save_settings_btn.clicked.connect(self.save_settings)
            self.open_log_btn.clicked.connect(self.open_animal_log)
            self.run_btn.clicked.connect(self.run_protocol)
            self.test_btn.clicked.connect(self.test_selected)
            self.abort_btn.clicked.connect(self.abort_run)
            self.variables_edit.editingFinished.connect(self._pull_form_to_protocol)
            self.iti_edit.editingFinished.connect(self._pull_form_to_protocol)
            self.seq_repeats_edit.editingFinished.connect(self._pull_form_to_protocol)
            self.randomize_check.stateChanged.connect(self._pull_form_to_protocol)
            self.enable_all_daqs_btn.clicked.connect(lambda: self._set_all_daqs(True))
            self.disable_all_daqs_btn.clicked.connect(lambda: self._set_all_daqs(False))

        def _apply_theme(self) -> None:
            self.setStyleSheet(
                """
                QMainWindow, QWidget {
                    background: #000000;
                    color: #f5f5f5;
                }
                QLabel {
                    color: #f5f5f5;
                }
                QListWidget, QPlainTextEdit, QLineEdit, QTableWidget, QScrollArea, QTabWidget::pane {
                    background: #050505;
                    color: #f5f5f5;
                    border: 1px solid #202020;
                }
                QHeaderView::section {
                    background: #0d0d0d;
                    color: #f5f5f5;
                    border: 1px solid #202020;
                }
                QPushButton {
                    background: #111111;
                    color: #f5f5f5;
                    border: 1px solid #2a2a2a;
                    padding: 6px 10px;
                }
                QPushButton:hover {
                    background: #1a1a1a;
                }
                QPushButton:disabled {
                    color: #666666;
                    border-color: #1a1a1a;
                }
                QCheckBox {
                    color: #f5f5f5;
                }
                QComboBox {
                    background: #050505;
                    color: #f5f5f5;
                    border: 1px solid #202020;
                    padding: 4px;
                }
                QTabBar::tab {
                    background: #0d0d0d;
                    color: #f5f5f5;
                    border: 1px solid #202020;
                    padding: 8px 14px;
                }
                QTabBar::tab:selected {
                    background: #161616;
                }
                """
            )

        def _build_timeline_tab(self) -> None:
            root = QtWidgets.QVBoxLayout(self.timeline_tab)
            controls = QtWidgets.QGridLayout()
            self.timeline_backend_combo = QtWidgets.QComboBox()
            self.timeline_backend_combo.addItems(["nidaqmx", "simulated"])
            if not self.nidaqmx_available:
                self.timeline_backend_combo.setCurrentText("simulated")
            self.timeline_output_dir_edit = QtWidgets.QLineEdit("")
            self.timeline_manual_exp_id_edit = QtWidgets.QLineEdit("")
            self.timeline_start_btn = QtWidgets.QPushButton("Start Timeline")
            self.timeline_stop_btn = QtWidgets.QPushButton("Stop Timeline")
            self.timeline_stop_btn.setEnabled(False)
            self.timeline_status_label = QtWidgets.QLabel("Idle")
            self.timeline_samples_label = QtWidgets.QLabel("0")
            self.timeline_file_label = QtWidgets.QLabel("")
            self.timeline_file_label.setWordWrap(True)
            controls.addWidget(QtWidgets.QLabel("Backend"), 0, 0)
            controls.addWidget(self.timeline_backend_combo, 0, 1)
            controls.addWidget(QtWidgets.QLabel("Output dir override"), 0, 2)
            controls.addWidget(self.timeline_output_dir_edit, 0, 3)
            controls.addWidget(QtWidgets.QLabel("Manual expID"), 1, 0)
            controls.addWidget(self.timeline_manual_exp_id_edit, 1, 1)
            controls.addWidget(self.timeline_start_btn, 1, 2)
            controls.addWidget(self.timeline_stop_btn, 1, 3)
            controls.addWidget(QtWidgets.QLabel("Status"), 2, 0)
            controls.addWidget(self.timeline_status_label, 2, 1)
            controls.addWidget(QtWidgets.QLabel("Samples"), 2, 2)
            controls.addWidget(self.timeline_samples_label, 2, 3)
            controls.addWidget(QtWidgets.QLabel("File"), 3, 0)
            controls.addWidget(self.timeline_file_label, 3, 1, 1, 3)
            for col in range(4):
                controls.setColumnStretch(col, 1)
            root.addLayout(controls)

            self.timeline_info_label = QtWidgets.QLabel("")
            self.timeline_info_label.setWordWrap(True)
            if self.nidaqmx_available:
                self.timeline_info_label.setText("NI-DAQmx backend available.")
            else:
                self.timeline_info_label.setText(f"NI-DAQmx backend unavailable on this host. Using simulated mode by default. {self.nidaqmx_reason}")
            root.addWidget(self.timeline_info_label)

            self.timeline_plot = TimelinePlotWidget()
            root.addWidget(self.timeline_plot, 1)

            self.timeline_start_btn.clicked.connect(self.start_timeline_manual)
            self.timeline_stop_btn.clicked.connect(self.stop_timeline_manual)

        def log(self, message: str) -> None:
            timestamp = QtCore.QDateTime.currentDateTime().toString("HH:mm:ss")
            self.log_view.appendPlainText(f"{timestamp}: {message}")

        def set_run_status(self, message: str) -> None:
            self.run_status_label.setText(message)
            if message:
                self.log(message)

        def _get_daq_names(self) -> list[str]:
            from .daq import DaqController

            controller = DaqController(self.config, self.log)
            self.daq_rows: list[DaqToggleRow] = []
            names = []
            while self.daq_layout.count() > 0:
                item = self.daq_layout.takeAt(0)
                widget = item.widget()
                if widget is not None:
                    widget.deleteLater()
            for row, entry in enumerate(controller.entries):
                daq_row = DaqToggleRow(entry.name, enabled=True)
                daq_row.setToolTip(f"Enable {entry.name}")
                self.daq_layout.addWidget(daq_row, row // 2, row % 2)
                self.daq_rows.append(daq_row)
                names.append(entry.name)
            return names

        def _selected_daqs(self) -> list[str]:
            return [row.daq_name for row in getattr(self, "daq_rows", []) if row.is_enabled()]

        def _reload_daq_table(self) -> None:
            self._get_daq_names()

        def _set_all_daqs(self, enabled: bool) -> None:
            for row in getattr(self, "daq_rows", []):
                row.set_enabled(enabled)

        def _pull_form_to_protocol(self) -> None:
            self.protocol.variables = self.variables_edit.text()
            self.protocol.iti = self.iti_edit.text()
            self.protocol.sequence_repeats = self.seq_repeats_edit.text()
            self.protocol.randomize = self.randomize_check.isChecked()

        def refresh_view(self, *_args) -> None:
            self._pull_form_to_protocol()
            self.variables_edit.setText(self.protocol.variables)
            self.iti_edit.setText(self.protocol.iti)
            self.seq_repeats_edit.setText(self.protocol.sequence_repeats)
            self.randomize_check.setChecked(self.protocol.randomize)

            self.stim_list.blockSignals(True)
            selected_stim = self.stim_list.currentRow()
            self.stim_list.clear()
            for index, stim in enumerate(self.protocol.stimuli, start=1):
                self.stim_list.addItem(f"Stim {index} (reps={stim.reps})")
            self.stim_list.setCurrentRow(max(0, min(selected_stim, len(self.protocol.stimuli) - 1)) if self.protocol.stimuli else -1)
            self.stim_list.blockSignals(False)

            self.feature_list.blockSignals(True)
            selected_feature = self.feature_list.currentRow()
            self.feature_list.clear()
            if self.feature_type_list.currentRow() < 0 and self.feature_type_list.count():
                self.feature_type_list.setCurrentRow(0)
            stim = self.current_stimulus()
            if stim is not None:
                for feature in stim.features:
                    self.feature_list.addItem(feature.type)
            self.feature_list.setCurrentRow(max(0, min(selected_feature, self.feature_list.count() - 1)) if self.feature_list.count() else -1)
            self.feature_list.blockSignals(False)
            fixed_list_height = self._list_height_for_rows(5)
            self.feature_type_list.setFixedHeight(fixed_list_height)
            self.feature_list.setFixedHeight(fixed_list_height)

            self.stim_reps_edit.blockSignals(True)
            self.stim_reps_edit.setText(str(stim.reps) if stim is not None else "1")
            self.stim_reps_edit.setEnabled(stim is not None)
            self.stim_reps_edit.blockSignals(False)

            self.param_table.blockSignals(True)
            self.param_table.setRowCount(0)
            if stim is not None:
                feature = self.current_feature()
                param_count = len(feature.params) if feature is not None else 0
                self.param_table.setRowCount(param_count)
                if feature is not None:
                    for row, (name, value) in enumerate(feature.params.items()):
                        key_item = QtWidgets.QTableWidgetItem(name)
                        key_item.setFlags(key_item.flags() & ~QtCore.Qt.ItemIsEditable)
                        self.param_table.setItem(row, 0, key_item)
                        self.param_table.setItem(row, 1, QtWidgets.QTableWidgetItem(value))
            self.param_table.blockSignals(False)

        def current_stimulus(self):
            row = self.stim_list.currentRow()
            if 0 <= row < len(self.protocol.stimuli):
                return self.protocol.stimuli[row]
            return None

        def current_feature(self):
            stimulus = self.current_stimulus()
            row = self.feature_list.currentRow()
            if stimulus is not None and 0 <= row < len(stimulus.features):
                return stimulus.features[row]
            return None

        def _feature_type_changed(self, *_args) -> None:
            self.refresh_view()

        def _list_height_for_rows(self, rows: int) -> int:
            row_height = self.feature_type_list.sizeHintForRow(0)
            if row_height <= 0:
                row_height = max(24, self.fontMetrics().height() + 8)
            frame = self.feature_type_list.frameWidth() * 2
            return (row_height * rows) + frame + 4

        def _stim_reps_changed(self) -> None:
            stimulus = self.current_stimulus()
            if stimulus is None:
                return
            try:
                stimulus.reps = max(1, int(float(self.stim_reps_edit.text().strip() or "1")))
            except ValueError:
                self.stim_reps_edit.setText(str(stimulus.reps))
                return
            self.refresh_view()

        def add_stimulus(self) -> None:
            from .models import Stimulus

            self.protocol.stimuli.append(Stimulus(reps=1, features=[]))
            self.refresh_view()
            self.stim_list.setCurrentRow(len(self.protocol.stimuli) - 1)

        def remove_stimulus(self) -> None:
            row = self.stim_list.currentRow()
            if 0 <= row < len(self.protocol.stimuli):
                del self.protocol.stimuli[row]
            self.refresh_view()

        def copy_stimulus(self) -> None:
            stimulus = self.current_stimulus()
            if stimulus is not None:
                self.protocol.stimuli.append(stimulus.clone())
                self.refresh_view()

        def add_feature(self) -> None:
            stimulus = self.current_stimulus()
            if stimulus is None:
                return
            current_item = self.feature_type_list.currentItem()
            if current_item is None:
                return
            definition = self.catalog_by_name[current_item.text()]
            stimulus.features.append(definition.make_feature())
            self.refresh_view()
            self.feature_list.setCurrentRow(len(stimulus.features) - 1)

        def remove_feature(self) -> None:
            stimulus = self.current_stimulus()
            row = self.feature_list.currentRow()
            if stimulus is not None and 0 <= row < len(stimulus.features):
                del stimulus.features[row]
                self.refresh_view()

        def copy_feature(self) -> None:
            stimulus = self.current_stimulus()
            feature = self.current_feature()
            if stimulus is not None and feature is not None:
                stimulus.features.append(feature.clone())
                self.refresh_view()

        def _param_item_changed(self, item) -> None:
            stimulus = self.current_stimulus()
            if stimulus is None or item.column() != 1:
                return
            feature = self.current_feature()
            key_item = self.param_table.item(item.row(), 0)
            if feature is not None and key_item is not None:
                feature.params[key_item.text()] = item.text()

        def new_protocol(self) -> None:
            from .models import Protocol

            self.protocol = Protocol()
            self.refresh_view()
            self.log("Created new protocol.")

        def load_json(self) -> None:
            path, _ = QtWidgets.QFileDialog.getOpenFileName(self, "Load JSON Protocol", str(self.config.stimsets_dir), "JSON Files (*.json)")
            if not path:
                return
            self.protocol = load_protocol_json(path)
            self.refresh_view()
            self.log(f"Loaded JSON protocol {path}")

        def save_json(self) -> None:
            self._pull_form_to_protocol()
            default_path = self.protocol.source_path or str(self.config.stimsets_dir / "protocol.json")
            path, _ = QtWidgets.QFileDialog.getSaveFileName(self, "Save JSON Protocol", default_path, "JSON Files (*.json)")
            if not path:
                return
            if not path.lower().endswith(".json"):
                path += ".json"
            save_protocol_json(self.protocol, path)
            self.protocol.source_path = path
            self.log(f"Saved JSON protocol {path}")

        def convert_matlab_config(self) -> None:
            mat_path, _ = QtWidgets.QFileDialog.getOpenFileName(self, "Convert MATLAB Config", str(self.config.stimsets_dir), "MATLAB Files (*.mat)")
            if not mat_path:
                return
            protocol = load_protocol_from_mat(mat_path)
            default_json = str(Path(mat_path).with_suffix(".json"))
            json_path, _ = QtWidgets.QFileDialog.getSaveFileName(self, "Save Converted JSON", default_json, "JSON Files (*.json)")
            if not json_path:
                return
            if not json_path.lower().endswith(".json"):
                json_path += ".json"
            save_protocol_json(protocol, json_path)
            self.protocol = protocol
            self.protocol.source_path = json_path
            self.refresh_view()
            self.log(f"Converted {mat_path} -> {json_path}")

        def open_config_functions(self) -> None:
            dialog = ConfigFunctionsDialog(self)
            dialog.exec()

        def save_settings(self) -> None:
            new_server = self.bv_server_edit.text().strip()
            if not new_server:
                QtWidgets.QMessageBox.warning(self, "Invalid settings", "BV server cannot be empty.")
                return
            save_machine_settings(self.config, bv_server=new_server)
            self.config.bv_server = new_server
            self.runner.config.bv_server = new_server
            self.log(f"Saved settings to {self.config.ini_path}")

        def build_set(self) -> None:
            if not self.protocol.stimuli:
                QtWidgets.QMessageBox.warning(self, "No stimuli", "Create or load a protocol before building a set.")
                return
            base_stim_text, ok = QtWidgets.QInputDialog.getText(self, "Build Set", "Base stimulus number")
            if not ok or not base_stim_text.strip():
                return
            try:
                base_index = int(float(base_stim_text.strip()))
            except ValueError:
                QtWidgets.QMessageBox.warning(self, "Invalid stimulus", "Base stimulus number must be numeric.")
                return
            if not (1 <= base_index <= len(self.protocol.stimuli)):
                QtWidgets.QMessageBox.warning(self, "Invalid stimulus", f"Base stimulus must be between 1 and {len(self.protocol.stimuli)}.")
                return

            feature_text, ok = QtWidgets.QInputDialog.getText(self, "Build Set", "Features to vary, e.g. 1,2")
            if not ok or not feature_text.strip():
                return
            try:
                feature_indexes = parse_build_feature_indexes(feature_text)
            except Exception as exc:
                QtWidgets.QMessageBox.warning(self, "Invalid features", str(exc))
                return
            base_stimulus = self.protocol.stimuli[base_index - 1]
            if not feature_indexes or min(feature_indexes) < 1 or max(feature_indexes) > len(base_stimulus.features):
                QtWidgets.QMessageBox.warning(self, "Invalid features", f"Feature indexes must be between 1 and {len(base_stimulus.features)}.")
                return

            overwrite = QtWidgets.QMessageBox.question(
                self,
                "Build Set",
                "Replace base stimulus?",
                QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No | QtWidgets.QMessageBox.Cancel,
                QtWidgets.QMessageBox.No,
            )
            if overwrite == QtWidgets.QMessageBox.Cancel:
                return
            overwrite_base = overwrite == QtWidgets.QMessageBox.Yes

            param_specs: list[tuple[str, list[float]]] = []
            while True:
                param_name, ok = QtWidgets.QInputDialog.getText(self, "Build Set", "Parameter name to vary")
                if not ok:
                    return
                param_name = param_name.strip()
                if not param_name:
                    QtWidgets.QMessageBox.warning(self, "Invalid parameter", "Parameter name cannot be empty.")
                    continue
                values_text, ok = QtWidgets.QInputDialog.getText(
                    self,
                    "Build Set",
                    "Parameter values. Use x,y,z or start:step:stop",
                )
                if not ok:
                    return
                try:
                    values = parse_build_values(values_text)
                except Exception as exc:
                    QtWidgets.QMessageBox.warning(self, "Invalid values", str(exc))
                    continue
                param_specs.append((param_name, values))
                more = QtWidgets.QMessageBox.question(
                    self,
                    "Build Set",
                    "Add another parameter?",
                    QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No,
                    QtWidgets.QMessageBox.No,
                )
                if more != QtWidgets.QMessageBox.Yes:
                    break

            if not param_specs:
                return

            for param_name, _values in param_specs:
                for feature_index in feature_indexes:
                    if param_name not in base_stimulus.features[feature_index - 1].params:
                        QtWidgets.QMessageBox.warning(
                            self,
                            "Parameter missing",
                            f"Parameter '{param_name}' does not exist on feature {feature_index}.",
                        )
                        return

            new_stimuli = [stim.clone() for stim in self.protocol.stimuli]
            value_product = itertools.product(*[values for _name, values in param_specs])
            for combo in value_product:
                new_stim = base_stimulus.clone()
                for param_index, param_value in enumerate(combo):
                    param_name = param_specs[param_index][0]
                    rendered = _format_build_value(param_value)
                    for feature_index in feature_indexes:
                        new_stim.features[feature_index - 1].params[param_name] = rendered
                new_stimuli.append(new_stim)

            if overwrite_base:
                del new_stimuli[base_index - 1]
            self.protocol.stimuli = new_stimuli
            self.refresh_view()
            self.log(f"Build Set created {len(new_stimuli)} stimuli.")

        def open_animal_log(self) -> None:
            animal_id = self.animal_edit.text().strip() or "TEST"
            animal_dir = self.config.local_save_root / animal_id
            animal_dir.mkdir(parents=True, exist_ok=True)
            log_path = animal_dir / "animal_log.txt"
            if not log_path.exists():
                log_path.write_text("", encoding="utf-8")
            try:
                if sys.platform.startswith("win"):
                    os.startfile(str(log_path))  # type: ignore[attr-defined]
                elif sys.platform == "darwin":
                    subprocess.Popen(["open", str(log_path)])
                else:
                    subprocess.Popen(["xdg-open", str(log_path)])
            except Exception:
                self.log(f"Animal log: {log_path}")

        def run_protocol(self) -> None:
            self._start_worker(test_mode=False, selected_stimuli=None)

        def test_selected(self) -> None:
            stim_row = self.stim_list.currentRow()
            if stim_row < 0:
                QtWidgets.QMessageBox.warning(self, "No selection", "Select a stimulus to test.")
                return
            self._start_worker(test_mode=True, selected_stimuli=[stim_row + 1])

        def _start_worker(self, test_mode: bool, selected_stimuli: list[int] | None) -> None:
            self._pull_form_to_protocol()
            if self.timeline_backend_combo.currentText() == "nidaqmx" and not self.nidaqmx_available:
                self.set_run_status(f"Timeline backend unavailable: {self.nidaqmx_reason}")
                return
            if self.run_process is not None:
                self.set_run_status("A run is already in progress.")
                return
            self.run_btn.setEnabled(False)
            self.test_btn.setEnabled(False)
            self.abort_btn.setEnabled(True)
            self.set_run_status("Run started.")
            protocol_path = write_temp_protocol(self.protocol.clone())
            abort_path = new_temp_abort_file()
            self.run_process_protocol_path = protocol_path
            self.run_process_abort_path = abort_path
            self.run_process_test_mode = test_mode
            self.run_process_output = []
            process = QtCore.QProcess(self)
            process.setProcessChannelMode(QtCore.QProcess.SeparateChannels)
            process.readyReadStandardOutput.connect(self._read_run_stdout)
            process.readyReadStandardError.connect(self._read_run_stderr)
            process.finished.connect(self._run_process_finished)
            python_exe = os.path.join(Path(sys.executable).resolve().parent, "python")
            if not Path(python_exe).exists():
                python_exe = sys.executable
            args = [
                "-m",
                "bvgui.run_job",
                "--protocol",
                str(protocol_path),
                "--animal-id",
                self.animal_edit.text().strip() or "TEST",
                "--comment",
                self.comment_edit.text().strip(),
                "--bv-server",
                self.bv_server_edit.text().strip(),
                "--bonvision-backend",
                self.bonvision_backend_combo.currentText().strip(),
                "--timeline-backend",
                self.timeline_backend_combo.currentText().strip(),
                "--timeline-output-override",
                self.timeline_output_dir_edit.text().strip(),
                "--pre-blank-s",
                self.pre_blank_edit.text().strip() or "0",
                "--pause-after-preload-s",
                self.pause_after_preload_edit.text().strip() or "0.5",
                "--enabled-daqs",
                ",".join(self._selected_daqs()),
                "--abort-file",
                str(abort_path),
            ]
            if test_mode:
                args.append("--test-mode")
            if selected_stimuli:
                args.extend(["--selected-stimuli", ",".join(str(item) for item in selected_stimuli)])
            process.setWorkingDirectory(str(Path(__file__).resolve().parents[1]))
            process.start(python_exe, args)
            self.run_process = process

        def _read_run_stdout(self) -> None:
            if self.run_process is None:
                return
            text = bytes(self.run_process.readAllStandardOutput()).decode("utf-8", errors="replace")
            if text:
                self.run_process_output.extend(line for line in text.splitlines() if line.strip())

        def _read_run_stderr(self) -> None:
            if self.run_process is None:
                return
            text = bytes(self.run_process.readAllStandardError()).decode("utf-8", errors="replace")
            if text:
                for line in text.splitlines():
                    if line.strip():
                        self.log(f"job stderr: {line}")

        def _run_process_finished(self, exit_code: int, exit_status) -> None:
            self.run_btn.setEnabled(True)
            self.test_btn.setEnabled(True)
            self.abort_btn.setEnabled(False)
            payload = None
            if self.run_process_output:
                last_line = self.run_process_output[-1]
                try:
                    payload = json.loads(last_line)
                except Exception:
                    payload = None
            if self.run_process is not None:
                self.run_process.deleteLater()
                self.run_process = None
            self.run_process_output = []
            protocol_path = self.run_process_protocol_path
            abort_path = self.run_process_abort_path
            test_mode = self.run_process_test_mode
            self.run_process_protocol_path = None
            self.run_process_abort_path = None
            self.run_process_test_mode = False
            self._cleanup_temp_run_file(protocol_path)
            self._cleanup_temp_run_file(abort_path)
            if exit_status != QtCore.QProcess.NormalExit:
                self.set_run_status(f"Run process crashed with exit status {exit_status}.")
                return
            if payload is None:
                self.set_run_status(f"Run failed with exit code {exit_code}.")
                return
            logs = payload.get("logs", [])
            for line in logs:
                self.log(line)
            if payload.get("aborted", False):
                self.set_run_status("Run aborted.")
                if not test_mode:
                    self._finalize_experiment_logs(payload, status_line="Run aborted by user.")
                return
            if not payload.get("ok", False):
                self.set_run_status(f"Run failed: {payload.get('error_type','Error')}: {payload.get('error','Unknown error')}")
                if not test_mode:
                    self._finalize_experiment_logs(
                        payload,
                        status_line=f"Run failed: {payload.get('error_type','Error')}: {payload.get('error','Unknown error')}",
                    )
                return
            self.set_run_status(f"Run complete. Outputs saved to {payload.get('exp_dir','')}")
            if not test_mode:
                self._finalize_experiment_logs(payload, status_line=f"Experiment complete - {payload.get('exp_id', '')}")

        def abort_run(self) -> None:
            if self.run_process is not None:
                if self.run_process_abort_path is not None:
                    self.run_process_abort_path.parent.mkdir(parents=True, exist_ok=True)
                    self.run_process_abort_path.write_text("abort\n", encoding="utf-8")
                if self.run_process.state() == QtCore.QProcess.NotRunning:
                    self.set_run_status("No run is active.")
                    return
                self.run_btn.setEnabled(False)
                self.abort_btn.setEnabled(False)
                self.set_run_status("Aborting...")
            else:
                self.set_run_status("No run is active.")

        def _cleanup_temp_run_file(self, path: Path | None) -> None:
            if path is None:
                return
            try:
                if path.exists():
                    path.unlink()
            except Exception:
                pass
            try:
                parent = path.parent
                if parent.exists() and not any(parent.iterdir()):
                    parent.rmdir()
            except Exception:
                pass

        def _finalize_experiment_logs(self, payload: dict, status_line: str) -> None:
            exp_dir_text = str(payload.get("exp_dir", "")).strip()
            exp_id = str(payload.get("exp_id", "")).strip()
            animal_id = exp_id[14:] if len(exp_id) > 14 else (self.animal_edit.text().strip() or "TEST")
            if not exp_dir_text:
                return
            exp_dir = Path(exp_dir_text)
            exp_dir.mkdir(parents=True, exist_ok=True)
            final_comment, accepted = QtWidgets.QInputDialog.getText(
                self,
                "Final comments",
                "Final comments?",
                text=self.final_comment_default_edit.text().strip(),
            )
            if not accepted:
                final_comment = self.final_comment_default_edit.text().strip()
            else:
                self.final_comment_default_edit.setText(final_comment)
            timestamp = QtCore.QDateTime.currentDateTime().toString("yyyy-MM-dd HH:mm:ss")
            exp_log_path = exp_dir / "exp_log.txt"
            with exp_log_path.open("a", encoding="utf-8") as handle:
                handle.write(f"{status_line}\n")
                if final_comment:
                    handle.write(f"{final_comment}\n")
                handle.write(f"{timestamp}\n")
            if final_comment != "x":
                animal_dir = self.config.local_save_root / animal_id
                animal_dir.mkdir(parents=True, exist_ok=True)
                animal_log_path = animal_dir / "animal_log.txt"
                with animal_log_path.open("a", encoding="utf-8") as handle:
                    handle.write(f"{exp_id}\n")
                    if self.comment_edit.text().strip():
                        handle.write(f"{self.comment_edit.text().strip()}\n")
                    handle.write(f"{status_line}\n")
                    if final_comment:
                        handle.write(f"{final_comment}\n")
                    handle.write(f"{timestamp}\n")
                    handle.write("======================\n")

        def start_timeline_manual(self) -> None:
            if self.timeline_recorder.status().running:
                QtWidgets.QMessageBox.warning(self, "Timeline running", "Timeline is already running.")
                return
            if self.timeline_backend_combo.currentText() == "nidaqmx" and not self.nidaqmx_available:
                QtWidgets.QMessageBox.critical(self, "Timeline backend unavailable", self.nidaqmx_reason)
                return
            exp_id = self.timeline_manual_exp_id_edit.text().strip() or new_exp_id(self.animal_edit.text().strip() or "TEST")
            animal = exp_id[14:] if len(exp_id) > 14 else (self.animal_edit.text().strip() or "TEST")
            output_dir_text = self.timeline_output_dir_edit.text().strip()
            output_dir = Path(output_dir_text) if output_dir_text else Path(self.config.remote_save_root) / animal / exp_id
            try:
                status = self.timeline_recorder.start(
                    exp_id=exp_id,
                    output_dir=output_dir,
                    backend_mode=self.timeline_backend_combo.currentText().strip(),
                )
                self.log(f"Timeline started: {status.file_path}")
                self._refresh_timeline_tab()
            except Exception as exc:
                QtWidgets.QMessageBox.critical(self, "Timeline start failed", str(exc))

        def stop_timeline_manual(self) -> None:
            try:
                status = self.timeline_recorder.stop()
                summary = self.timeline_recorder.summary()
                if summary is not None:
                    self.log(f"Timeline saved to {summary.file_path}")
                elif status.error:
                    self.log(f"Timeline error: {status.error}")
                self._refresh_timeline_tab()
            except Exception as exc:
                QtWidgets.QMessageBox.critical(self, "Timeline stop failed", str(exc))

        def _refresh_timeline_tab(self) -> None:
            status = self.timeline_recorder.status()
            state = "Running" if status.running else "Idle"
            if status.error:
                state += f" | error: {status.error}"
            self.timeline_status_label.setText(state)
            self.timeline_samples_label.setText(str(status.sample_count))
            self.timeline_file_label.setText(status.file_path)
            self.timeline_start_btn.setEnabled(not status.running)
            self.timeline_stop_btn.setEnabled(status.running)
            self.timeline_plot.set_data(self.timeline_recorder.recent_data(), status.channel_names or [])


def launch() -> int:
    if QtWidgets is None:
        print("PySide6 is required to launch the bvGUI desktop app.", file=sys.stderr)
        print(f"Import error: {_qt_import_error}", file=sys.stderr)
        return 1
    crash_log = Path(__file__).resolve().parents[1] / "bvgui_crash.log"
    try:
        crash_log.parent.mkdir(parents=True, exist_ok=True)
        crash_handle = crash_log.open("a", encoding="utf-8")
        faulthandler.enable(crash_handle)
    except Exception:
        crash_handle = None
    app = QtWidgets.QApplication(sys.argv)
    window = MainWindow()
    window.showMaximized()
    exit_code = app.exec()
    if crash_handle is not None:
        crash_handle.close()
    return exit_code
