library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tl_rom_lut is
generic(ARRAY_SIZE          : integer := 32;
        ELEMENTS_BITS_COUNT : integer := 9);
port (inClock50Mhz    : in std_logic;
      inAddressToRead : in integer range 0 to ARRAY_SIZE*16 -1;
      outReadMemory   : out std_logic_vector(ELEMENTS_BITS_COUNT-1 downto 0)
     );
end tl_rom_lut;

architecture logic of tl_rom_lut is
   signal sLUTDataOut : std_logic_vector(ELEMENTS_BITS_COUNT-1 downto 0);
   signal sInAddress    : integer range 0 to ARRAY_SIZE*16-1;

component single_clock_rom is
   GENERIC(
           ARRAY_SIZE          : integer;
           ELEMENTS_BITS_COUNT : integer
   );
   PORT (
         clock: IN STD_LOGIC;
         read_address: IN INTEGER RANGE 0 to ARRAY_SIZE*16-1;
         output: OUT STD_LOGIC_VECTOR (ELEMENTS_BITS_COUNT-1 DOWNTO 0)
   );
end component;


begin

  ROM_INSTANCE : single_clock_rom
  generic map(
           ARRAY_SIZE          => ARRAY_SIZE,
           ELEMENTS_BITS_COUNT => ELEMENTS_BITS_COUNT)
  port map(clock      => inClock50Mhz,
           read_address => sInAddress,
           output       => sLUTDataOut);


   outReadMemory <= sLUTDataOut;

   syncProcess : process (inClock50Mhz)
   begin
      if rising_edge(inClock50Mhz) then
         sInAddress <= inAddressToRead;
      end if;
   end process;

end logic;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tl_sin_lut_reader is
generic (TABLE_SIZE   : integer := 32 * 4); -- the table is of 32 samples from 0 to pi, we accept the entire 0-2PI range
port (inClock50MHz    : in std_logic;
      inAddressToRead : in std_logic_vector (6 downto 0);  --range 0 to TABLE_SIZE - 1;
      inFactor        : in integer range -128 to 127;
      outProduct      : out integer range -256 to 255;
      outDone         : out std_logic
);
end tl_sin_lut_reader;

architecture logic_sin_lut_reader of tl_sin_lut_reader is
  type  STATE_MACHINE_ENUM is (IDLE, WAITING_READ);

  signal sClock         : std_logic;
  --signal sReadAddress : integer range 0 to 32*16-1;
  signal sReadAddress   : integer range 0 to 31;
  signal sOutputLUT     : std_logic_vector (8 downto 0);
  signal sMachineState  : STATE_MACHINE_ENUM := IDLE;
begin

LUTInstance : entity work.tl_rom_lut(logic)
port map (inClock50Mhz    => sClock,
          inAddressToRead => sReadAddress,
          outReadMemory   => sOutputLUT);

syncProcess : process (inClock50Mhz)
   variable vAddressForLUT : integer range 0 to 31;
   variable vTempToReturn  : std_logic_vector (17 downto 0); -- adding a sign to the table 8 bit unsigned
begin
   if rising_edge(inClock50Mhz) then
      case sMachineState is
         when IDLE =>
            case inAddressToRead(5) is
               when '0' =>  -- 0 to PI/2  or PI to 3/2 PI: read direct from table
                  vAddressForLUT := to_integer(unsigned(inAddressToRead(4 downto 0)));
               when '1' =>  -- PI/2 to PI or 3/2PI to 2PI : read from inverted table
                  vAddressForLUT := 31 - to_integer(unsigned(inAddressToRead(4 downto 0)));
               when others => report "WTF, MAN?" severity error;
            end case;
            outDone <= '0';
            sMachineState <= WAITING_READ;
         when WAITING_READ => -- since we have only one clock of latency, we can already take the output value
            if inAddressToRead(6) = '1' -- negative part of the sine (PI..2PI)
               xor inFactor < 0 then -- xor negative input : negative result
                  vTempToReturn := std_logic_vector(inFactor * signed(sOutputLUT) * (-1));
            else  -- else, positive
                  vTempToReturn := std_logic_vector(inFactor * unsigned(sOutputLUT));
            end if;

            outProduct <= to_integer(signed(vTempToReturn(17 downto 8)));
             
            outDone <= '1';
            sMachineState <= IDLE;
      end case;

      sReadAddress <= vAddressForLUT;

   end if;
end process;




end logic_sin_lut_reader;

