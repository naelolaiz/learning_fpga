library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Reusable control surface for the vga top: three active-low buttons
-- through Debounce instances driving pause / reset / speed-select
-- state, plus a four-LED status panel. Pulled out of
-- top_level_vga_test.vhd so the integration TB can exercise it
-- directly without instantiating the VGA timing + text rendering, and
-- so a 1:1 Verilog mirror (control_panel.v) can be tested by an
-- equivalent Verilog testbench.
--
-- The panel does NOT own the bouncing-square step counter — that
-- stays in the top so the dynamic-text counter, the static-text
-- scroll counter and the half-second counter can share the same
-- TickProcess sPaused gate. The top exports `paused` from the panel
-- to gate its motion counters and `resetActive` to drive moveSquare's
-- async-reset path. `speedSelect` is a 2-bit code; the top decodes it
-- to one of the SQUARE_PERIOD_* constants.
--
-- panelLeds maps:
--   panelLeds(0) <- paused          (lit while pause is engaged)
--   panelLeds(1) <- heartbeatTick   (passthrough of the ~12.5 Hz toggle
--                                    the top derives from its own
--                                    half-second counter)
--   panelLeds(2) <- '1' when speedSelect = "10" (FAST) else '0'
-- The top wires panelLeds onto leds(3 downto 1); leds(0) (the
-- per-step pulse) stays in the top since the step toggle lives there.

entity control_panel is
   generic (
      -- Forwarded to every Debounce instance below. Default matches
      -- Debounce's own default (250000 ticks of a 50 MHz clock = 5 ms),
      -- which is what synthesis uses. Testbenches drop this to a small
      -- value so simulated debounce settle is fast.
      DEBOUNCE_LIMIT : integer := 250000
   );
   port (
      clk            : in  std_logic;
      inputButtons   : in  std_logic_vector(2 downto 0);
      heartbeatTick  : in  std_logic;
      paused         : out std_logic;
      resetActive    : out std_logic;
      speedSelect    : out std_logic_vector(1 downto 0);
      panelLeds      : out std_logic_vector(2 downto 0)
   );
end entity control_panel;

architecture rtl of control_panel is

   signal sBtnPauseDebounced : std_logic;
   signal sBtnResetDebounced : std_logic;
   signal sBtnSpeedDebounced : std_logic;

   signal sPaused      : std_logic := '0';
   signal sSpeedSelect : std_logic_vector(1 downto 0) := "00";  -- 00 = MEDIUM

begin

   debouncePause : entity work.Debounce(RTL)
      generic map (DEBOUNCE_LIMIT => DEBOUNCE_LIMIT)
      port map (i_Clk => clk, i_Switch => inputButtons(0), o_Switch => sBtnPauseDebounced);

   debounceReset : entity work.Debounce(RTL)
      generic map (DEBOUNCE_LIMIT => DEBOUNCE_LIMIT)
      port map (i_Clk => clk, i_Switch => inputButtons(1), o_Switch => sBtnResetDebounced);

   debounceSpeed : entity work.Debounce(RTL)
      generic map (DEBOUNCE_LIMIT => DEBOUNCE_LIMIT)
      port map (i_Clk => clk, i_Switch => inputButtons(2), o_Switch => sBtnSpeedDebounced);

   -- Pause toggle on each press of button 0. Buttons are active-low,
   -- so a press shows up as a falling edge on the debounced output.
   pauseToggleProcess : process (sBtnPauseDebounced)
   begin
      if falling_edge(sBtnPauseDebounced) then
         sPaused <= not sPaused;
      end if;
   end process;

   -- Speed cycler. Each press of button 2 advances medium → slow →
   -- fast → medium. 2-bit code: 00 = MEDIUM, 01 = SLOW, 10 = FAST.
   speedCycleProcess : process (sBtnSpeedDebounced)
   begin
      if falling_edge(sBtnSpeedDebounced) then
         case sSpeedSelect is
            when "00"   => sSpeedSelect <= "01";  -- MEDIUM -> SLOW
            when "01"   => sSpeedSelect <= "10";  -- SLOW   -> FAST
            when others => sSpeedSelect <= "00";  -- FAST   -> MEDIUM
         end case;
      end if;
   end process;

   paused        <= sPaused;
   resetActive   <= not sBtnResetDebounced;          -- active-low button → active-high level
   speedSelect   <= sSpeedSelect;
   panelLeds(0)  <= sPaused;
   panelLeds(1)  <= heartbeatTick;
   panelLeds(2)  <= '1' when sSpeedSelect = "10" else '0';

end architecture rtl;
