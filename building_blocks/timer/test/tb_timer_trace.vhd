library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;
use std.env.all;

-- Both trace benches read the same reset/limit rows. Expected results
-- live in the Python driver, independently of either HDL implementation.
entity tb_timer_trace is
   generic (MAX_NUMBER : natural := 8; TRIGGER_DURATION : positive := 3);
end entity;

architecture testbench of tb_timer_trace is
   signal clock : std_logic := '0';
   signal reset : std_logic := '0';
   signal limit : integer range 0 to MAX_NUMBER := MAX_NUMBER;
   signal tick : std_logic;
begin
   DUT : entity work.Timer
      generic map (MAX_NUMBER => MAX_NUMBER, TRIGGER_DURATION => TRIGGER_DURATION)
      port map (clock => clock, reset => reset, maxLimit => limit,
                timerTriggered => tick);

   stimulus : process
      file input_file : text open read_mode is "stimulus.txt";
      file output_file : text open write_mode is "trace.txt";
      variable input_line, output_line : line;
      variable reset_value, limit_value : integer;
      variable previous_tick : std_logic := '0';
   begin
      while not endfile(input_file) loop
         readline(input_file, input_line);
         read(input_line, reset_value);
         read(input_line, limit_value);
         if reset_value = 1 then reset <= '1'; else reset <= '0'; end if;
         limit <= limit_value;
         wait for 1 ns;
         assert tick = previous_tick
            report "Timer output changed between rising edges" severity failure;
         wait for 4 ns;
         clock <= '1';
         wait for 1 ns;
         if tick = '0' then
            write(output_line, string'("0"));
         elsif tick = '1' then
            write(output_line, string'("1"));
         else
            assert false report "Timer output is unknown" severity failure;
         end if;
         writeline(output_file, output_line);
         previous_tick := tick;
         wait for 4 ns;
         clock <= '0';
      end loop;
      finish;
   end process;
end architecture;
