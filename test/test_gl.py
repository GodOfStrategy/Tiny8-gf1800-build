
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer


@cocotb.test()
async def test_tiny8_gate_level(dut):

    dut.clk.value = 0
    dut.rst_n.value = 0
    dut.ena.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    clock = Clock(dut.clk, 60, unit="ns")
    cocotb.start_soon(clock.start())

    await Timer(300, unit="ns")

    assert int(dut.uio_oe.value) == 0xF7, \
        "Bidirectional output-enable configuration is incorrect"

    dut.ena.value = 1
    dut.rst_n.value = 1

    await Timer(300, unit="ns")

    assert int(dut.uio_oe.value) == 0xFF, \
        "Output-enable changed after reset"

    dut.rst_n.value = 0
    await Timer(120, unit="ns")

    dut.rst_n.value = 1
    await Timer(300, unit="ns")

    dut._log.info("PASS: Tiny8 gate-level wrapper smoke test")
