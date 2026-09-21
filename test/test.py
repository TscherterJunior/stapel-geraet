# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.triggers import ReadWrite

@cocotb.test()
async def test_instptre(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    async def step(num = 1,d = dut):
        await ClockCycles(d.clk, num)
        await ReadWrite()
        # assert dut.uio_oe.value == 0b1111_1111

    dut._log.info("Test project behavior")

    await ReadWrite()

    # Set the input values you want to test
    dut.ui_in.value = 0b1010_0000
    await ReadWrite()

    for i in range(255):
        assert dut.uio_out.value == i
        await step()

    assert dut.uio_out.value == 255


@cocotb.test()
async def test_push_zero(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    async def step(num = 1,d = dut):
        await ClockCycles(d.clk, num)
        await ReadWrite()
        # assert dut.uio_oe.value == 0b1111_1111

    dut._log.info("Test project behavior")

    dut.ui_in.value = 0x0
    await ReadWrite()
    
    assert dut.uo_out.value  == 0x0
    assert dut.uio_out.value == 0x0
    
    await step()

    assert dut.uo_out.value  == 0x0
    assert dut.uio_out.value == 0x1

    dut.ui_in.value = 0x0
    await step()

    assert dut.uo_out.value  == 0x0
    assert dut.uio_out.value == 0x2

    dut.ui_in.value = 0x20

    await step()

    assert dut.uo_out.value == 0x80
    assert dut.uio_out.value == 0x00

    await step()

    assert dut.uo_out.value == 0x00
    assert dut.uio_out.value == 0x00