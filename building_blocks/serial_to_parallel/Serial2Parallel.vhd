library ieee;
use ieee.std_logic_1164.all;

-- Serial2Parallel: continuously shifts inData into the LSB of an
-- internal shift register and exposes a snapshot of that register on
-- outData when inPrint is held high at the rising clock edge. Between
-- inPrint pulses outData stays at its last snapshot.
--
-- Internally a thin wrapper around the shared `shift_register` entity
-- (in ../shift_register/) plus one snapshot register, instead of a
-- bespoke shift loop. Same external behaviour; the only difference
-- vs a flat hand-rolled implementation is that shifting continues
-- regardless of inPrint, which is the natural snapshot semantic.

entity Serial2Parallel is
  generic (NUMBER_OF_BITS : integer := 16);
  port    (inClock  : in  std_logic;
           inData   : in  std_logic;
           inPrint  : in  std_logic;
           outData  : out std_logic_vector(NUMBER_OF_BITS-1 downto 0)
                          := (others => '0'));
end Serial2Parallel;

architecture wrapper of Serial2Parallel is
  signal sShifted : std_logic_vector(NUMBER_OF_BITS-1 downto 0);
begin

  inner : entity work.shift_register
    generic map (WIDTH => NUMBER_OF_BITS)
    port map (
      clk          => inClock,
      load         => '0',
      load_data    => (others => '0'),
      serial_in    => inData,
      parallel_out => sShifted,
      serial_out   => open);

  snapshot : process(inClock)
  begin
    if rising_edge(inClock) then
      if inPrint = '1' then
        outData <= sShifted;
      end if;
    end if;
  end process;

end architecture wrapper;
