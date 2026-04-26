library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_blink_led_minimal is
end entity tb_blink_led_minimal;

architecture testbench of tb_blink_led_minimal is
    signal sSimulationActive : boolean   := true;
    signal sClock50MHz       : std_logic := '0';
    signal sLed              : std_logic;
begin

    -- WIDTH=4 -> counter wraps every 16 cycles; the MSB (counter(3))
    -- toggles every 8 cycles. With a 50 MHz / 20 ns clock that's
    -- 160 ns full period.
    DUT : entity work.blink_led_minimal(rtl)
        generic map (WIDTH => 4)
        port map (
            clk => sClock50MHz,
            led => sLed);

    sClock50MHz <= not sClock50MHz after 10 ns when sSimulationActive;

    CHECK : process is
    begin
        -- After delta-cycle settling, counter = 0 -> led = '0'.
        wait for 1 ns;
        assert sLed = '0' report "led must start at 0" severity error;

        -- 8 rising edges later (counter = 8 = 1000_2), MSB = '1'.
        for i in 1 to 8 loop
            wait until rising_edge(sClock50MHz);
        end loop;
        wait for 1 ns;
        assert sLed = '1'
            report "led must be 1 after 8 edges (counter MSB high)" severity error;

        -- 8 more edges (counter = 0 again), MSB = '0'.
        for i in 1 to 8 loop
            wait until rising_edge(sClock50MHz);
        end loop;
        wait for 1 ns;
        assert sLed = '0'
            report "led must be back to 0 after counter wrap" severity error;

        report "Simulation done!" severity note;
        sSimulationActive <= false;
        wait;
    end process;

end architecture testbench;
