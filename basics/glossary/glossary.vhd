-- Glossary of basic logic primitives.
--
-- One module, one output per primitive — read alongside the rendered
-- netlist diagram (build/glossary.svg) to learn which netlistsvg shape
-- maps to which cell. The Verilog mirror in glossary.v is byte-for-byte
-- equivalent in behaviour and port shape.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity glossary is
    port (
        -- 1-bit combinational inputs
        a    : in std_logic;
        b    : in std_logic;
        sel  : in std_logic;
        sel4 : in std_logic_vector(1 downto 0);

        -- 4-bit buses for reductions, arithmetic, shifts and the 4:1 mux
        av : in std_logic_vector(3 downto 0);
        bv : in std_logic_vector(3 downto 0);

        -- sequential controls
        clk : in std_logic;
        rst : in std_logic;
        en  : in std_logic;

        -- bitwise gates
        o_and  : out std_logic;
        o_or   : out std_logic;
        o_not  : out std_logic;
        o_xor  : out std_logic;
        o_nand : out std_logic;
        o_nor  : out std_logic;
        o_xnor : out std_logic;

        -- vector reductions (VHDL-2008 unary operators)
        o_reduce_or  : out std_logic;
        o_reduce_and : out std_logic;
        o_reduce_xor : out std_logic;

        -- multiplexers
        o_mux2 : out std_logic;
        o_mux4 : out std_logic;

        -- arithmetic + comparators + shifts
        o_add : out std_logic_vector(3 downto 0);
        o_sub : out std_logic_vector(3 downto 0);
        o_eq  : out std_logic;
        o_lt  : out std_logic;
        o_shl : out std_logic_vector(3 downto 0);
        o_shr : out std_logic_vector(3 downto 0);

        -- sequential cells
        o_dff     : out std_logic;
        o_dffe    : out std_logic;
        o_dffr    : out std_logic;
        o_counter : out std_logic_vector(3 downto 0)
    );
end entity glossary;

architecture rtl of glossary is
    signal r_dff     : std_logic                    := '0';
    signal r_dffe    : std_logic                    := '0';
    signal r_dffr    : std_logic                    := '0';
    signal r_counter : unsigned(3 downto 0)         := (others => '0');
begin

    o_and  <= a and  b;
    o_or   <= a or   b;
    o_not  <= not a;
    o_xor  <= a xor  b;
    o_nand <= a nand b;
    o_nor  <= a nor  b;
    o_xnor <= a xnor b;

    o_reduce_or  <= or  av;
    o_reduce_and <= and av;
    o_reduce_xor <= xor av;

    o_mux2 <= a when sel = '1' else b;

    with sel4 select
        o_mux4 <= av(0) when "00",
                  av(1) when "01",
                  av(2) when "10",
                  av(3) when others;

    o_add <= std_logic_vector(unsigned(av) + unsigned(bv));
    o_sub <= std_logic_vector(unsigned(av) - unsigned(bv));
    o_eq  <= '1' when av = bv else '0';
    o_lt  <= '1' when unsigned(av) < unsigned(bv) else '0';
    o_shl <= std_logic_vector(shift_left (unsigned(av), 1));
    o_shr <= std_logic_vector(shift_right(unsigned(av), 1));

    DFF : process (clk) is
    begin
        if rising_edge(clk) then
            r_dff <= a;
        end if;
    end process DFF;
    o_dff <= r_dff;

    DFFE : process (clk) is
    begin
        if rising_edge(clk) then
            if en = '1' then
                r_dffe <= a;
            end if;
        end if;
    end process DFFE;
    o_dffe <= r_dffe;

    DFFR : process (clk) is
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r_dffr <= '0';
            else
                r_dffr <= a;
            end if;
        end if;
    end process DFFR;
    o_dffr <= r_dffr;

    COUNTER : process (clk) is
    begin
        if rising_edge(clk) then
            if rst = '1' then
                r_counter <= (others => '0');
            else
                r_counter <= r_counter + 1;
            end if;
        end if;
    end process COUNTER;
    o_counter <= std_logic_vector(r_counter);

end architecture rtl;
