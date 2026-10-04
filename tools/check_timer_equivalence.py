#!/usr/bin/env python3
"""Check Timer's public contract and VHDL/Verilog agreement cycle by cycle.

Uses only the Python standard library plus ghdl, iverilog and vvp. Each
scenario supplies one shared stimulus file and independently specified
expected output bits. All compilation and traces stay in a temporary folder.
"""

from dataclasses import dataclass
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile


@dataclass(frozen=True)
class Scenario:
    name: str
    maximum: int
    duration: int
    # Each step holds reset and limit for one clock per expected output bit.
    steps: tuple[tuple[int, int, str], ...]


SCENARIOS = (
    Scenario("reset held, release and reset during a pulse", 8, 3, (
        (1, 4, "000"), (0, 4, "000011100111"),
        (1, 4, "000"), (0, 4, "000011100111"),
    )),
    Scenario("reset restarts a partly completed period", 8, 1, (
        (1, 4, "00"), (0, 4, "00"), (1, 4, "0"),
        (0, 4, "0000100001"),
    )),
    Scenario("lower limit below count then lengthen an active pulse period", 8, 2, (
        (1, 8, "0"), (0, 8, "000000"), (0, 2, "11"),
        (0, 8, "000000011"),
    )),
    Scenario("raise limit before wrap and change to zero", 8, 2, (
        (1, 2, "0"), (0, 2, "00"), (0, 5, "00011"),
        (0, 0, "111"), (1, 0, "00"), (0, 0, "111"),
    )),
    Scenario("smallest bound and zero limit", 0, 1, (
        (1, 0, "00"), (0, 0, "1111"), (1, 0, "0"), (0, 0, "11"),
    )),
    Scenario("one-cycle pulse and smallest alternating period", 1, 1, (
        (1, 1, "0"), (0, 1, "01010101"),
    )),
    Scenario("pulse as long as period remains high after first trigger", 4, 5, (
        (1, 4, "0"), (0, 4, "00001111111111"), (1, 4, "00"),
    )),
    Scenario("overlapping pulses resume ending after increasing limit", 8, 4, (
        (1, 2, "0"), (0, 2, "00111111"), (0, 8, "10000011"),
    )),
)


def run(command: list[str], cwd: Path, *, must_succeed: bool = True) -> subprocess.CompletedProcess:
    result = subprocess.run(command, cwd=cwd, text=True, capture_output=True, timeout=30)
    if must_succeed and result.returncode:
        raise RuntimeError(f"{shlex.join(command)} failed:\n{result.stdout}{result.stderr}")
    return result


def check() -> None:
    timer = Path(__file__).resolve().parents[1] / "building_blocks" / "timer"
    commands = {name: shlex.split(os.environ.get(name.upper(), name))
                for name in ("ghdl", "iverilog", "vvp")}
    for name, command in commands.items():
        if not command or not shutil.which(command[0]):
            raise RuntimeError(f"Missing {name}; run in the documented HDL toolchain container")

    with tempfile.TemporaryDirectory(prefix="timer-equivalence-") as folder:
        work = Path(folder)
        (work / "ghdl").mkdir()
        ghdl_flags = ["--std=08", "--workdir=ghdl"]
        run(commands["ghdl"] + ["-a"] + ghdl_flags + [
            str(timer / "Timer.vhd"), str(timer / "test/tb_timer_trace.vhd")], work)
        run(commands["ghdl"] + ["-e"] + ghdl_flags + ["tb_timer_trace"], work)

        def simulate(maximum: int, duration: int, rows: list[tuple[int, int]],
                     *, invalid: bool = False) -> dict[str, str]:
            (work / "stimulus.txt").write_text(
                "".join(f"{reset} {limit}\n" for reset, limit in rows), encoding="utf-8")
            run(commands["iverilog"] + ["-g2012", "-s", "tb_timer_trace",
                f"-Ptb_timer_trace.MAX_NUMBER={maximum}",
                f"-Ptb_timer_trace.TRIGGER_DURATION={duration}",
                "-o", "trace.vvp", str(timer / "Timer.v"),
                str(timer / "test/tb_timer_trace.v")], work)
            traces = {}
            for language, command in (
                ("VHDL", commands["ghdl"] + ["-r"] + ghdl_flags + ["tb_timer_trace",
                    f"-gMAX_NUMBER={maximum}", f"-gTRIGGER_DURATION={duration}",
                    "--assert-level=error"]),
                ("Verilog", commands["vvp"] + ["-n", "trace.vvp"]),
            ):
                (work / "trace.txt").unlink(missing_ok=True)
                result = run(command, work, must_succeed=not invalid)
                if invalid:
                    if result.returncode == 0:
                        raise AssertionError(f"{language} accepted invalid Timer inputs")
                else:
                    traces[language] = "".join((work / "trace.txt").read_text().splitlines())
            return traces

        cycles = 0
        for scenario in SCENARIOS:
            rows = [(reset, limit) for reset, limit, expected in scenario.steps
                    for _ in expected]
            expected = "".join(bits for _, _, bits in scenario.steps)
            traces = simulate(scenario.maximum, scenario.duration, rows)
            for language, actual in traces.items():
                if actual != expected:
                    raise AssertionError(f"{scenario.name} ({language}):\n"
                                         f"expected: {expected}\nactual:   {actual}")
            if traces["VHDL"] != traces["Verilog"]:
                raise AssertionError(f"{scenario.name}: VHDL and Verilog disagree")
            cycles += len(rows)
            print(f"PASS: {scenario.name} ({len(rows)} cycles)")

        for name, maximum, duration, rows in (
            ("negative maximum", -1, 1, [(0, 0)]),
            ("zero pulse duration", 8, 0, [(0, 4)]),
            ("runtime limit above maximum", 8, 1, [(0, 9)]),
        ):
            simulate(maximum, duration, rows, invalid=True)
            print(f"PASS: both languages reject {name}")
        print(f"Timer contract matched in both languages: {len(SCENARIOS)} scenarios, "
              f"{cycles} cycles, 3 invalid-input checks")


if __name__ == "__main__":
    try:
        check()
    except (AssertionError, RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print(f"Timer equivalence failed: {error}", file=sys.stderr)
        sys.exit(1)
