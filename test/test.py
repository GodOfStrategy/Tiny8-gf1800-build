
import cocotb
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def test_tiny8_program(dut):

    dut._log.info("Waiting for Tiny8 program execution")

    # The Verilog testbench loads and executes the program itself.
    # Wait until the CPU reports that it has halted.
    for _ in range(400):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ps")

        if int(dut.debug_halted.value) == 1:
            break
    else:
        assert False, "Tiny8 timed out: CPU did not halt"

    # Verify the program's results.
    assert int(dut.port_out.value) == 0x08, "Incorrect CPU output"
    assert int(dut.debug_pc.value) == 0x05, "Incorrect program counter"
    assert int(dut.debug_ir.value) == 0x0800, "Incorrect instruction register"

    dut._log.info("PASS: Tiny8 executed the test program successfully")
