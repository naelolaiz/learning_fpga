-- tb_pwm_led.vhd
--
-- Sweeps duty across a few values and counts the high-cycles in each
-- 256-tick window. Asserts the count equals the duty.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pwm_led is
end entity tb_pwm_led;

architecture testbench of tb_pwm_led is
  constant WIDTH      : integer := 8;
  constant CLK_PERIOD : time    := 20 ns;
  signal sClk     : std_logic := '0';
  signal sDuty    : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
  signal sPwm     : std_logic;
  signal sSimulationActive  : boolean := true;
begin

  dut : entity work.pwm_led
    generic map (WIDTH => WIDTH)
    port map (clk => sClk, duty => sDuty, pwm_out => sPwm);

  sClk <= not sClk after CLK_PERIOD/2 when sSimulationActive;

  driver : process
    variable expected : integer;
    variable observed : integer;
  begin
    -- Try a small set of duty values, measure across one full PWM window.
    for d in 0 to 255 loop
      if (d mod 32) = 0 or d = 255 then
        sDuty <= std_logic_vector(to_unsigned(d, WIDTH));
        wait for CLK_PERIOD;            -- let the new duty settle one cycle
        observed := 0;
        for c in 0 to (2**WIDTH)-1 loop
          wait for CLK_PERIOD;
          if sPwm = '1' then
            observed := observed + 1;
          end if;
        end loop;
        expected := d;
        assert observed = expected
          report "duty=" & integer'image(d)
              & " expected high-count " & integer'image(expected)
              & " got " & integer'image(observed)
          severity error;
      end if;
    end loop;
    report "pwm_led simulation done!" severity note;
    sSimulationActive <= false;
    wait;
  end process;

end architecture testbench;
