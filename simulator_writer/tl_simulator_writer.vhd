library ieee;
use ieee.std_logic_1164.all;

entity tl_simulator_writer is
   generic (myString : string := "Hello world!");
   port (inClock  : in std_logic;
         outLines : out std_logic_vector(4 downto 0);
         done     : out boolean
        );
end tl_simulator_writer;

architecture logic of tl_simulator_writer is
  signal sOutRow : std_logic_vector(4 downto 0) := (others=>'0');
  type tChar is array (0 to 4) of std_logic_vector (4 downto 0);
  signal sCurrentChar  : tChar := (others => (others => '0'));
  signal sCurrentBlank : boolean := false;

begin
  clockProcess : process (inClock)
     variable vCurrentCharIdx  : integer range 1 to myString'length := 1;
     constant cCharHorLength   : integer := 5;
     constant cClocksForColumn : integer := 5;
     constant cColumnSeparatorBetweenChars : integer := 1;
     variable vCountForSeparatorBetweenChars : integer := 0;
     variable vCounterForClocksForColumn : integer range 0 to cClocksForColumn-1 := 0;
     variable vCharHorIndex    : integer range 0 to cCharHorLength-1 := 0;
  begin
     if rising_edge(inClock) then
        done <= false;
        if vCounterForClocksForColumn = cClocksForColumn-1 then
           vCounterForClocksForColumn := 0;
           if vCharHorIndex = cCharHorLength-1 then
              vCharHorIndex := 0;
              if vCurrentCharIdx = myString'length then
                 vCurrentCharIdx := 1;
                 done <= true;
              else
                 if vCountForSeparatorBetweenChars = cColumnSeparatorBetweenChars then
                    vCountForSeparatorBetweenChars := 0;
                    vCurrentCharIdx := vCurrentCharIdx + 1;
                    sCurrentBlank <= false;
                 else
                    sCurrentBlank <= true;
                    vCountForSeparatorBetweenChars := vCountForSeparatorBetweenChars + 1;
                 end if;
              end if;
           else
              vCharHorIndex := vCharHorIndex + 1;
           end if;
        else
           vCounterForClocksForColumn := vCounterForClocksForColumn + 1;
        end if;
        case vCurrentCharIdx is
           when  1 => sCurrentChar <= ("10001",
                                       "10001",
                                       "11111",
                                       "10001",
                                       "10001");
           when  2 => sCurrentChar <= ("11111",
                                       "10000",
                                       "11100",
                                       "10000",
                                       "11111");
           when  3 | 4 | 10 =>
                      sCurrentChar <= ("10000",
                                       "10000",
                                       "10000",
                                       "10000",
                                       "11111");
           when  5 | 8 =>
                      sCurrentChar <= ("01110",
                                       "10001",
                                       "10001",
                                       "10001",
                                       "01110");
           when  7 => sCurrentChar <= ("10001",
                                       "10001",
                                       "10001",
                                       "10101",
                                       "01010");
           when  9 => sCurrentChar <= ("11100",
                                       "10010",
                                       "11100",
                                       "10010",
                                       "10001");
           when 11 => sCurrentChar <= ("11110",
                                       "10001",
                                       "10001",
                                       "10001",
                                       "11110");

           when others => sCurrentChar <= (others => (others => '0'));

        end case;

        for i in 0 to 4 loop
--           sOutRow(i) <= sCurrentChar(i)(vCharHorIndex);
           sOutRow(i) <= sCurrentChar(i)(cCharHorLength-1 - vCharHorIndex);
--            case sCurrentChar(i)(vCharHorIndex) is
--               when '1'    => sOutRow(i) <= inClock;
--               when others => sOutRow(i) <= '0';
--            end case;
        end loop;
     end if;
  end process;

-- otherProcess : process ( sCurrentChar) 

 outLines(4) <= inClock when sOutRow(0) = '1' and not sCurrentBlank else '0';
 outLines(3) <= inClock when sOutRow(1) = '1' and not sCurrentBlank else '0';
 outLines(2) <= inClock when sOutRow(2) = '1' and not sCurrentBlank else '0';
 outLines(1) <= inClock when sOutRow(3) = '1' and not sCurrentBlank else '0';
 outLines(0) <= inClock when sOutRow(4) = '1' and not sCurrentBlank else '0';
--outLines <= sOutRow;


end logic;
