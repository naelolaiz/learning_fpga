library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Integration TB for the control_panel building block, focused on the
-- pause / reset / speed-select state-machine + LED panel (the testable
-- surface that the bigger top_level_vga_test sits on top of). The
-- smoke TB next door (tb_vga_smoke.vhd) covers the VGA primitives
-- (Square, Font_Rom); this one is about wiring through the debouncers.
--
-- Instantiating control_panel directly (rather than the full top)
-- has two benefits:
--   * control_panel has a Verilog mirror (control_panel.v), so tb_vga_top
--     can have a 1:1 Verilog twin (test/tb_vga_top.v) — the full top
--     can't be mirrored because its Pixel_On_Text* generics use VHDL
--     strings yosys+ghdl-plugin can't synthesise either way.
--   * Sim time stays bounded because there's no VGA raster running.
--
-- The TB shrinks DEBOUNCE_LIMIT to 100 ticks (instead of the synth
-- default 250000) so each press settles in ~2 us. Buttons are
-- active-low; a press = drive low, hold > DEBOUNCE_LIMIT, release high.

entity tb_vga_top is
end tb_vga_top;

architecture testbench of tb_vga_top is
   constant CLK_PERIOD     : time    := 20 ns;   -- 50 MHz
   constant DBLIM          : integer := 100;     -- shrunk debouncer settle window
   constant SETTLE_CYCLES  : integer := DBLIM + 20;

   signal tbClock           : std_logic := '0';
   signal sSimulationActive : boolean   := true;
   signal tbStage           : integer   := 0;

   signal tbButtons         : std_logic_vector(2 downto 0) := "111";
   signal tbHeartbeat       : std_logic := '0';

   signal tbPaused          : std_logic;
   signal tbResetActive     : std_logic;
   signal tbSpeedSelect     : std_logic_vector(1 downto 0);
   signal tbPanelLeds       : std_logic_vector(2 downto 0);

begin

   tbClock <= not tbClock after CLK_PERIOD / 2 when sSimulationActive else '0';

   dut : entity work.control_panel
      generic map (
         DEBOUNCE_LIMIT => DBLIM
      )
      port map (
         clk           => tbClock,
         inputButtons  => tbButtons,
         heartbeatTick => tbHeartbeat,
         paused        => tbPaused,
         resetActive   => tbResetActive,
         speedSelect   => tbSpeedSelect,
         panelLeds     => tbPanelLeds
      );

   stim : process
      procedure press(constant idx : in integer) is
      begin
         tbButtons(idx) <= '0';
         for k in 1 to SETTLE_CYCLES loop
            wait until rising_edge(tbClock);
         end loop;
         tbButtons(idx) <= '1';
         for k in 1 to SETTLE_CYCLES loop
            wait until rising_edge(tbClock);
         end loop;
      end procedure;
   begin
      ----------------------------------------------------------------
      -- Stage 0: let the debouncers' o_Switch outputs rise from their
      -- power-on '0' to '1' (no buttons pressed). Without this lead-in
      -- the first real press would race the boot-up rising edge of
      -- the debounced output, and the falling edge that the toggles
      -- are looking for could be missed.
      ----------------------------------------------------------------
      tbStage <= 0;
      for k in 1 to SETTLE_CYCLES loop
         wait until rising_edge(tbClock);
      end loop;

      ----------------------------------------------------------------
      -- Stage 1: pause toggle. paused should start cleared, latch on
      -- one press of button 0, then clear on the next.
      ----------------------------------------------------------------
      tbStage <= 1;
      assert tbPaused = '0'
         report "stage 1: paused must start cleared"
         severity failure;
      assert tbPanelLeds(0) = '0'
         report "stage 1: panelLeds(0) (pause LED) must mirror paused"
         severity failure;

      press(0);
      assert tbPaused = '1'
         report "stage 1a: paused should latch high after one press"
         severity failure;
      assert tbPanelLeds(0) = '1'
         report "stage 1a: panelLeds(0) must follow paused"
         severity failure;

      press(0);
      assert tbPaused = '0'
         report "stage 1b: paused should clear after second press"
         severity failure;

      ----------------------------------------------------------------
      -- Stage 2: speed cycler. speedSelect walks 00 → 01 → 10 → 00.
      -- panelLeds(2) (fast indicator) lights iff speedSelect = "10".
      ----------------------------------------------------------------
      tbStage <= 2;
      assert tbSpeedSelect = "00"
         report "stage 2: speedSelect must start at MEDIUM (00)"
         severity failure;
      assert tbPanelLeds(2) = '0'
         report "stage 2: fast LED must start cleared"
         severity failure;

      press(2);
      assert tbSpeedSelect = "01"
         report "stage 2a: MEDIUM -> SLOW expected (01)"
         severity failure;
      assert tbPanelLeds(2) = '0'
         report "stage 2a: SLOW must not light fast LED"
         severity failure;

      press(2);
      assert tbSpeedSelect = "10"
         report "stage 2b: SLOW -> FAST expected (10)"
         severity failure;
      assert tbPanelLeds(2) = '1'
         report "stage 2b: FAST must light fast LED"
         severity failure;

      press(2);
      assert tbSpeedSelect = "00"
         report "stage 2c: FAST -> MEDIUM expected (00 -- wrap)"
         severity failure;
      assert tbPanelLeds(2) = '0'
         report "stage 2c: MEDIUM must clear fast LED"
         severity failure;

      ----------------------------------------------------------------
      -- Stage 3: reset is a level. While button 1 is held low, the
      -- debounced output should settle to '0' and resetActive should
      -- be the inversion of that ('1' = held). Release the button
      -- and resetActive falls back to '0'.
      ----------------------------------------------------------------
      tbStage <= 3;
      assert tbResetActive = '0'
         report "stage 3: resetActive must start cleared"
         severity failure;

      tbButtons(1) <= '0';
      for k in 1 to SETTLE_CYCLES loop
         wait until rising_edge(tbClock);
      end loop;
      assert tbResetActive = '1'
         report "stage 3a: resetActive should rise while button 1 is held"
         severity failure;

      tbButtons(1) <= '1';
      for k in 1 to SETTLE_CYCLES loop
         wait until rising_edge(tbClock);
      end loop;
      assert tbResetActive = '0'
         report "stage 3b: resetActive should fall when button 1 is released"
         severity failure;

      ----------------------------------------------------------------
      -- Stage 4: heartbeat passthrough. panelLeds(1) follows the
      -- driven heartbeat tick directly (no pause gate, no divider).
      ----------------------------------------------------------------
      tbStage <= 4;
      tbHeartbeat <= '1';
      wait until rising_edge(tbClock);
      wait for 1 ns;
      assert tbPanelLeds(1) = '1'
         report "stage 4a: panelLeds(1) must follow heartbeatTick high"
         severity failure;

      tbHeartbeat <= '0';
      wait until rising_edge(tbClock);
      wait for 1 ns;
      assert tbPanelLeds(1) = '0'
         report "stage 4b: panelLeds(1) must follow heartbeatTick low"
         severity failure;

      ----------------------------------------------------------------
      tbStage <= 99;
      for k in 1 to 4 loop
         wait until rising_edge(tbClock);
      end loop;
      sSimulationActive <= false;
      wait;
   end process;

end testbench;
