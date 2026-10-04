-- One clock drives every register. tick is a clock enable, never a clock.
-- enable_async must be a slowly changing single bit, such as a button.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_enable is
    generic (DIVISOR : positive := 4; COUNT_WIDTH : positive := 4);
    port (
        clk, rst, enable_async : in std_logic;
        enable_sync, tick : out std_logic := '0';
        count : out unsigned(COUNT_WIDTH-1 downto 0) := (others => '0')
    );
end entity;

architecture rtl of clock_enable is
    signal divider : natural range 0 to DIVISOR-1 := 0;
    signal sync1, sync2 : std_logic := '0';
    attribute altera_attribute : string;
    attribute altera_attribute of sync1, sync2 : signal is
        "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS";
begin
    enable_sync <= sync2;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sync1 <= '0';
                sync2 <= '0';
                divider <= 0;
                tick <= '0';
                count <= (others => '0');
            else
                sync1 <= enable_async;
                sync2 <= sync1;
                tick <= '0';
                if divider = DIVISOR-1 then
                    divider <= 0;
                    tick <= '1';
                    if sync2 = '1' then count <= count + 1; end if;
                else
                    divider <= divider + 1;
                end if;
            end if;
        end if;
    end process;
end architecture;
