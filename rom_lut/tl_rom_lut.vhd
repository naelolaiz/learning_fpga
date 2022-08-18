library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tl_rom_lut is
generic(ARRAY_SIZE          : integer := 32;
        ELEMENTS_BITS_COUNT : integer := 9);
port (inClock50Mhz       : in std_logic;
      inAngleIdxToRead   : in std_logic_vector(6 downto 0);
      inNibbleProductIdx : in std_logic_vector(3 downto 0);
      outReadMemory      : out std_logic_vector(ELEMENTS_BITS_COUNT downto 0)
     );
end tl_rom_lut;

architecture logic of tl_rom_lut is
   signal sLUTDataOut       : std_logic_vector(ELEMENTS_BITS_COUNT downto 0);
   signal sAngleIdx         : std_logic_vector(6 downto 0);
   signal sNibbleProductIdx : std_logic_vector(3 downto 0);

component single_clock_rom is
   GENERIC(
           ARRAY_SIZE          : integer;
           ELEMENTS_BITS_COUNT : integer
   );
   PORT (
         clock              : in std_logic;
         read_angle_idx     : std_logic_vector(6 downto 0);  --table of 32 elements * 4 quadrans (0-127)
         nibble_product_idx : std_logic_vector(3 downto 0);  -- multiplication table of an hex digit
         output: OUT STD_LOGIC_VECTOR (ELEMENTS_BITS_COUNT DOWNTO 0)
   );
end component;


begin

  ROM_INSTANCE : single_clock_rom
  generic map(
           ARRAY_SIZE          => ARRAY_SIZE,
           ELEMENTS_BITS_COUNT => ELEMENTS_BITS_COUNT)
  port map(clock               => inClock50Mhz,
           read_angle_idx      => sAngleIdx,
           nibble_product_idx  => sNibbleProductIdx,
           output              => sLUTDataOut);


   outReadMemory <= sLUTDataOut;

   syncProcess : process (inClock50Mhz)
   begin
      if rising_edge(inClock50Mhz) then
         sAngleIdx         <= inAngleIdxToRead;
         sNibbleProductIdx <= inNibbleProductIdx;
      end if;
   end process;

end logic;

-- library ieee;
-- use ieee.std_logic_1164.all;
-- use ieee.numeric_std.all;
-- 
-- entity tl_sin_lut_reader is
-- generic (TABLE_SIZE    : integer := 32 * 4); -- the table is of 32 samples from 0 to pi, we accept the entire 0-2PI range
-- port (inClock50MHz     : in std_logic;
--       inAngleIdxToRead : in std_logic_vector (6 downto 0);  --range 0 to TABLE_SIZE - 1;
--       inFactor         : in integer range -128 to 127;
--       outProduct       : out integer range -256 to 255;
--       outDone          : out std_logic
-- );
-- end tl_sin_lut_reader;
-- 
-- architecture logic_sin_lut_reader of tl_sin_lut_reader is
--   type  STATE_MACHINE_ENUM is (IDLE, WAITING_READ);
-- 
--   signal sClock         : std_logic;
--   --signal sReadAddress : integer range 0 to 32*16-1;
--   signal sReadAddress   : std_logic_vector (6 downto 0);
--   signal sOutputLUT     : std_logic_vector (8 downto 0);
--   signal sMachineState  : STATE_MACHINE_ENUM := IDLE;
-- begin
-- 
-- LUTInstance : entity work.tl_rom_lut(logic)
-- port map (inClock50Mhz     => sClock,
--           inAngleIdxToRead => sReadAddress,
--           outReadMemory    => sOutputLUT);
-- 
--  -- syncProcess : process (inClock50Mhz)
--  --    variable vAddressForLUT : std_logic_vector (6 downto 0);
--  --    variable vTempToReturn  : std_logic_vector (17 downto 0); -- adding a sign to the table 8 bit unsigned
--  -- begin
--  --    if rising_edge(inClock50Mhz) then
--  --       case sMachineState is
--  --          when IDLE =>
--  --             case inAngleIdxToRead(5) is
--  --                when '0' =>  -- 0 to PI/2  or PI to 3/2 PI: read direct from table
--  --                   vAddressForLUT := to_integer(unsigned(inAngleIdxToRead(4 downto 0)));
--  --                when '1' =>  -- PI/2 to PI or 3/2PI to 2PI : read from inverted table
--  --                   vAddressForLUT := 31 - to_integer(unsigned(inAngleIdxToRead(4 downto 0)));
--  --                when others => report "WTF, MAN?" severity error;
--  --             end case;
--  --             outDone <= '0';
--  --             sMachineState <= WAITING_READ;
--  --          when WAITING_READ => -- since we have only one clock of latency, we can already take the output value
--  --             if inAngleIdxToRead(6) = '1' -- negative part of the sine (PI..2PI)
--  --                xor inFactor < 0 then -- xor negative input : negative result
--  --                   vTempToReturn := std_logic_vector(inFactor * (-1) * unsigned(sOutputLUT));
--  --             else  -- else, positive
--  --                   vTempToReturn := std_logic_vector(inFactor * unsigned(sOutputLUT));
--  --             end if;
--  -- 
--  --             outProduct <= to_integer(signed(vTempToReturn(17 downto 8)));
--  --              
--  --             outDone <= '1';
--  --             sMachineState <= IDLE;
--  --       end case;
--  -- 
--  --       sReadAddress <= vAddressForLUT;
--  -- 
--  --    end if;
--  -- end process;
-- 
-- sReadAddress <= inAngleIdxToRead;
-- 
-- end logic_sin_lut_reader;
-- 
