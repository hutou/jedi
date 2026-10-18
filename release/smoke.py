#!/usr/bin/env python3
"""Exercise a real Jedi binary in private production, demo and dev directories."""

import argparse
import json
import os
import platform
import pty
import re
import shlex
import shutil
import sqlite3
import subprocess
import tempfile
import tty
from pathlib import Path

from common import ROOT, sha256, version

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("binary", type=Path)
parser.add_argument("--graphics", action="store_true")
parser.add_argument("--log-dir", type=Path, default=ROOT / "build/smoke-target")
args = parser.parse_args()
binary = args.binary.resolve()
if not binary.is_file() or not os.access(binary, os.X_OK):
    raise SystemExit(f"Jedi binary missing or not executable: {binary}")
log_dir = args.log_dir.resolve()
log_dir.mkdir(parents=True, exist_ok=True)
result_file = log_dir / "result.json"
result_file.unlink(missing_ok=True)
report = {"success": False, "binary_sha256": sha256(binary),
          "version": version(), "system": platform.system(),
          "architecture": platform.machine(), "platform": platform.platform(),
          "graphics": args.graphics, "commands": []}
sequence = 0


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def run(command, cwd, env, input_text="", expected=0):
    global sequence
    sequence += 1
    # App.confirm reads raw terminal characters, so stdin must be a real TTY.
    master, slave = pty.openpty()
    tty.setraw(slave)
    process = None
    try:
        process = subprocess.Popen([str(part) for part in command], cwd=cwd, env=env,
                                   stdin=slave, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True)
        os.close(slave)
        slave = -1
        if input_text:
            os.write(master, input_text.encode())
        stdout, stderr = process.communicate(timeout=120)
        completed = subprocess.CompletedProcess(command, process.returncode, stdout, stderr)
    except subprocess.TimeoutExpired:
        process.kill()
        process.communicate()
        raise
    finally:
        os.close(master)
        if slave >= 0:
            os.close(slave)
    output = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", completed.stdout + completed.stderr)
    (log_dir / f"{sequence:02d}.txt").write_text(
        "$ " + shlex.join([str(part) for part in command]) +
        f"\nexit={completed.returncode}\n" + output)
    report["commands"].append({"argv": [str(part) for part in command],
                               "exit": completed.returncode})
    require(completed.returncode == expected,
            f"Unexpected exit status for {command}: {completed.returncode}\n{output}")
    return output


def paths_from(output):
    return dict(re.findall(r"^\s*(environment|\w+_dir|\w+_file)\s*:\s*(.+)$", output, re.M))


try:
    with tempfile.TemporaryDirectory(prefix="jedi-smoke-") as temporary:
        workspace = Path(temporary)
        package = workspace / "package with spaces"
        package.mkdir()
        shutil.copyfile(binary, package / "jedi")
        (package / "jedi").chmod(0o755)
        shutil.copyfile(ROOT / "install.sh", package / "install.sh")
        shutil.copytree(ROOT / "launchers", package / "launchers")
        shutil.copytree(ROOT / "examples", package / "examples")
        env = os.environ.copy()
        for key in list(env):
            if key.startswith("JEDI_"):
                del env[key]
        env.update({"TZ": "UTC", "LANG": "C.UTF-8", "GNUTERM": "svg",
                    "XDG_CONFIG_HOME": str(workspace / "production-config"),
                    "XDG_STATE_HOME": str(workspace / "production-state"),
                    "XDG_DATA_HOME": str(workspace / "production-data")})
        stage = workspace / "stage"
        run(["bash", package / "install.sh", "--destdir", stage], workspace, env)
        installed = stage / Path(os.environ["HOME"]).relative_to("/")
        core = installed / ".local/libexec/jedi"
        require(sha256(core) == sha256(binary), "Installer changed the binary")
        # A staged launcher keeps the final HOME path; adapt private copies only.
        launcher_dir = workspace / "private-launchers"
        launcher_dir.mkdir()
        core_quoted = str(core).replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$").replace("`", "\\`")
        for name in ("jedi", "jedidemo", "jedidev"):
            text = (installed / ".local/bin" / name).read_text()
            text = text.replace("$HOME/.local/libexec/jedi", core_quoted)
            target = launcher_dir / name
            target.write_text(text)
            target.chmod(0o755)
        env["PATH"] = str(launcher_dir) + os.pathsep + env["PATH"]
        demo = installed / "jedi-examples"
        dev = workspace / "development with spaces"
        dev.mkdir()
        env["JEDI_DEMO_DIR"] = str(demo)
        env["JEDI_DEV_DIR"] = str(dev)
        env["JEDI_ENV"] = "dev"
        for key in ("JEDI_CONFIG_DIR", "JEDI_LOG_DIR", "JEDI_DATA_DIR", "JEDI_DB_FILE", "JEDI_MARKET_DIR"):
            env[key] = str(workspace / "inherited-paths-must-not-be-used")

        cancelled = workspace / "cancelled"
        cancelled.mkdir()
        cancel_env = dict(env, JEDI_DEMO_DIR=str(cancelled))
        run(["jedidemo", "config", "--paths"], workspace, cancel_env, "n\n")
        require(not list(cancelled.rglob("*.db")) and not list(cancelled.rglob("*.conf")),
                "Cancelled initialization created application data")

        selected = {}
        for launcher, environment in (("jedi", "prod"), ("jedidemo", "test"), ("jedidev", "dev")):
            output = run([launcher, "config", "--paths"], workspace, env, "y\ny\ny\n")
            selected[launcher] = paths_from(output)
            require(selected[launcher].get("environment") == environment, "Incorrect environment")
        require(len({entry["db_file"] for entry in selected.values()}) == 3, "Database paths overlap")
        require(len({entry["market_dir"] for entry in selected.values()}) == 3, "Market paths overlap")
        require(Path(selected["jedi"]["db_file"]).is_relative_to(workspace / "production-data"),
                "Production ignored XDG paths")
        require(Path(selected["jedidemo"]["db_file"]).is_relative_to(demo), "Demo path escaped its directory")
        require(Path(selected["jedidev"]["db_file"]).is_relative_to(dev), "Dev path escaped its directory")
        report["environments"] = selected

        for language in ("C.UTF-8", "C", "POSIX", "fr_FR.UTF-8", "en_US.UTF-8"):
            output = run(["jedidemo", "version"], workspace, dict(env, LANG=language))
            require(version() in output, "Version output is inconsistent")
        for launcher in ("jedi", "jedidemo", "jedidev"):
            run([launcher], workspace, env)
        for tool in ("candidate", "backtest"):
            output = run(["jedidemo", "tools", tool, "--help"], workspace, env)
            require("default: 3" in output, "Default operability steps missing from help")
        config = Path(selected["jedidemo"]["config_file"])
        config.write_text("diagnostic_steps: 5\n")
        output = run(["jedidemo", "tools", "candidate", "--help"], workspace, env)
        require("default: 5" in output, "Effective operability steps missing from help")
        config.write_text("")

        run(["jedidemo", "tools", "calc", "spe",
             "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1", "position=1:0:0", "q0=100"], workspace, env)
        run(["jedidemo", "tools", "play", "-c", "o0,6-14,17", "--",
             "scale=vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0,q0=100,c0=10,tick=0.01", "1", "-1"], workspace, env)
        run(["jedidemo", "market", "init", "demo"], workspace, env, "y\n")
        run(["jedidemo", "market", "import", "demo", "Demo", "Demo_initial.txt", "labels_demo.txt"], workspace, env, "y\n")
        run(["jedidemo", "market", "update", "demo", "Demo", "Demo_partiel.txt", "labels_demo.txt"], workspace, env, "y\n")
        run(["jedidemo", "market", "update", "demo", "Demo", "Demo_update.txt", "labels_demo.txt"], workspace, env, "y\n")
        run(["jedidemo", "market", "info", "demo", "--dataset=Demo"], workspace, env)
        run(["jedidemo", "market", "list", "demo", "--dataset=Demo", "--last-quote"], workspace, env)
        run(["jedidemo", "tools", "profile", "cotations_EXA.txt"], workspace, env)
        run(["jedidemo", "tools", "profile", "--database=demo", "--dataset=Demo", "--rank-criteria=4"], workspace, env)
        run(["jedidemo", "tools", "score", "cotations_EXA.txt", "--budget=40"], workspace, env)
        scale = "vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0"
        run(["jedidemo", "tools", "candidate", "FR4487601001", "--price=10",
             f"--scale={scale}", "--amount=1000", "--capital=5000"], workspace, env)
        run(["jedidemo", "tools", "backtest", "cotations_EXA.txt", f"--scale={scale}"], workspace, env)
        run(["jedidemo", "security", "create", "--isin=FR4487601001", "--name=Example A",
             "--ticker=EXA", "--tick-buy=0.01", "--tick-sell=0.01", "--tax-rate=0"], workspace, env, "y\n")
        run(["jedidemo", "quote", "set", "FR4487601001", "--price=10"], workspace, env)
        run(["jedidemo", "scale", "create", "--comment=Release smoke test", f"--builder={scale}"], workspace, env, "y\n")
        run(["jedidemo", "trade", "create", "--name=T_exa_01", "--security=FR4487601001"], workspace, env, "y\n")
        run(["jedidemo", "settings", "create", "T_exa_01", "--scale=B_vr_01", "--date=2026-09-21", "--time=09:00:00"], workspace, env, "y\n")
        run(["jedidemo", "operation", "create", "T_exa_01", "--date=2026-09-21", "--time=09:01:00",
             "--type=Buy", "--mode=Limit", "--quantity=100", "--price=10", "--fees=3.50"], workspace, env, "y\n")
        run(["jedidemo", "trade", "orders", "T_exa_01"], workspace, env)
        with sqlite3.connect(selected["jedidemo"]["db_file"]) as connection:
            require(connection.execute("SELECT stock FROM operation ORDER BY id DESC LIMIT 1").fetchone()[0] == 100,
                    "Opening stock was not recorded")
        for launcher in ("jedi", "jedidev"):
            with sqlite3.connect(selected[launcher]["db_file"]) as connection:
                require(connection.execute("SELECT COUNT(*) FROM trade").fetchone()[0] == 0,
                        "Demo wrote a trade into another environment")
        if args.graphics:
            require(shutil.which("gnuplot"), "gnuplot is required for --graphics")
            run(["jedidemo", "tools", "plot", "cotations_EXA.txt", "--select=l20"], workspace, env)
            require((demo / "jedi_plot.svg").is_file(), "Quote plot SVG was not created")
            run(["jedidemo", "tools", "backtest", "cotations_EXA.txt", f"--scale={scale}", "-c", "rp"], workspace, env)
            require((demo / "jedi_backtest.svg").is_file(), "Backtest SVG was not created")
        report["success"] = True
except Exception as error:
    report["error"] = str(error)
    result_file.write_text(json.dumps(report, indent=2) + "\n")
    raise SystemExit(f"Smoke test failed: {error}\nLogs: {log_dir}")
result_file.write_text(json.dumps(report, indent=2) + "\n")
print(f"Installation and {sequence} CLI checks passed. Logs: {log_dir}")
