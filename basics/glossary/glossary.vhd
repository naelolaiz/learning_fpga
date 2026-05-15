-- Glossary of basic logic primitives.
--
-- One module, one output per primitive — read alongside the rendered
-- netlist diagram (build/glossary.svg) to learn which netlistsvg shape
-- maps to which cell. The Verilog mirror in glossary.v is byte-for-byte
-- equivalent in behaviour and port shape.
--
-- The intentional D-latch and the small inline RAM both expand the
-- glossary beyond yosys's "easy" primitives:
--   * the latch needs `GHDL_SYNTH_EXTRA := --latches` in the Makefile
--     so ghdl-yosys-plugin tolerates a level-sensitive memory cell
--     (see basics/logic_styles for the latch-trap tutorial);
--   * the RAM is a small 8 × 1-bit single-port synchronous memory —
--     enough for yosys to lift to a `$mem_v2` cell rather than
--     flatten to flip-flops.

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

        -- 4-bit one-hot select for the parallel mux (o_pmux below)
        sel4_oh : in std_logic_vector(3 downto 0);

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
        o_reduce_or   : out std_logic;
        o_reduce_and  : out std_logic;
        o_reduce_xor  : out std_logic;
        o_reduce_bool : out std_logic;     -- '1' iff av /= 0

        -- multi-bit logicals (operate on whole bus, return 1 bit)
        o_logic_not : out std_logic;       -- !av     == (av == 0)
        o_logic_and : out std_logic;       -- av && bv (true if both non-zero)
        o_logic_or  : out std_logic;       -- av || bv (true if either non-zero)

        -- multiplexers
        o_mux2 : out std_logic;
        o_mux4 : out std_logic;
        o_pmux : out std_logic;            -- parallel mux on one-hot select

        -- arithmetic
        o_add : out std_logic_vector(3 downto 0);
        o_sub : out std_logic_vector(3 downto 0);
        o_mul : out std_logic_vector(7 downto 0);  -- 4×4 = 8-bit product
        o_neg : out std_logic_vector(3 downto 0);
        o_pos : out std_logic_vector(3 downto 0);

        -- comparators
        o_eq  : out std_logic;
        o_ne  : out std_logic;
        o_lt  : out std_logic;
        o_gt  : out std_logic;
        o_ge  : out std_logic;
        o_le  : out std_logic;

        -- shifters
        o_shl   : out std_logic_vector(3 downto 0);
        o_shr   : out std_logic_vector(3 downto 0);
        o_sshr  : out std_logic_vector(3 downto 0);  -- arithmetic right shift
        o_shift : out std_logic_vector(3 downto 0);  -- variable left shift by bv(1:0)

        -- sequential cells
        o_dff     : out std_logic;
        o_dffe    : out std_logic;
        o_dffr    : out std_logic;
        o_dlatch  : out std_logic;                    -- level-sensitive latch
        o_counter : out std_logic_vector(3 downto 0);

        -- single-port synchronous memory (yosys $mem_v2)
        o_mem : out std_logic
    );
end entity glossary;

architecture rtl of glossary is
    signal r_dff     : std_logic                    := '0';
    signal r_dffe    : std_logic                    := '0';
    signal r_dffr    : std_logic                    := '0';
    signal r_counter : unsigned(3 downto 0)         := (others => '0');
    signal r_dlatch  : std_logic                    := '0';

    -- 8 × 1-bit single-port RAM. Address is the 3-bit concatenation of
    -- sel & sel4 (so the existing inputs drive it without needing a
    -- new port). Sync write on `en`, sync read.
    type ram_t is array (0 to 7) of std_logic;
    signal mem_arr  : ram_t                          := (others => '0');
    signal mem_addr : std_logic_vector(2 downto 0);
    signal mem_dout : std_logic                      := '0';
begin

    o_and  <= a and  b;
    o_or   <= a or   b;
    o_not  <= not a;
    o_xor  <= a xor  b;
    o_nand <= a nand b;
    o_nor  <= a nor  b;
    o_xnor <= a xnor b;

    o_reduce_or   <= or  av;
    o_reduce_and  <= and av;
    o_reduce_xor  <= xor av;
    o_reduce_bool <= '1' when av /= "0000" else '0';

    -- Logical operators on multi-bit operands. VHDL doesn't have a
    -- "logical not on a vector" operator, so we open-code the
    -- semantics — yosys-ghdl-plugin will collapse these to $logic_not /
    -- $logic_and / $logic_or in the netlist (which the beautifier
    -- relabels back to "!", "&&", "||" in the rendered diagram).
    o_logic_not <= '1' when av  =  "0000" else '0';
    o_logic_and <= '1' when (av /= "0000") and (bv /= "0000") else '0';
    o_logic_or  <= '1' when (av /= "0000") or  (bv /= "0000") else '0';

    o_mux2 <= a when sel = '1' else b;

    with sel4 select
        o_mux4 <= av(0) when "00",
                  av(1) when "01",
                  av(2) when "10",
                  av(3) when others;

    -- Parallel mux on a one-hot select. yosys recognises the "one
    -- branch per active bit" pattern below as $pmux rather than a
    -- chain of $mux. Default to '0' if no bit is set.
    process (sel4_oh, av) is
    begin
        case sel4_oh is
            when "0001" => o_pmux <= av(0);
            when "0010" => o_pmux <= av(1);
            when "0100" => o_pmux <= av(2);
            when "1000" => o_pmux <= av(3);
            when others => o_pmux <= '0';
        end case;
    end process;

    o_add <= std_logic_vector(unsigned(av) + unsigned(bv));
    o_sub <= std_logic_vector(unsigned(av) - unsigned(bv));
    o_mul <= std_logic_vector(unsigned(av) * unsigned(bv));
    o_neg <= std_logic_vector(-signed(av));
    o_pos <= av;                                                     -- +av is identity

    o_eq <= '1' when av = bv else '0';
    o_ne <= '1' when av /= bv else '0';
    o_lt <= '1' when unsigned(av) <  unsigned(bv) else '0';
    o_gt <= '1' when unsigned(av) >  unsigned(bv) else '0';
    o_ge <= '1' when unsigned(av) >= unsigned(bv) else '0';
    o_le <= '1' when unsigned(av) <= unsigned(bv) else '0';

    o_shl   <= std_logic_vector(shift_left (unsigned(av), 1));
    o_shr   <= std_logic_vector(shift_right(unsigned(av), 1));
    o_sshr  <= std_logic_vector(shift_right(signed(av),   1));
    o_shift <= std_logic_vector(shift_left (unsigned(av), to_integer(unsigned(bv(1 downto 0)))));

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

    -- Intentional D-latch: the missing `else` is the textbook "latch
    -- trap" — the process is sensitive to (en, a), and when en = '0'
    -- the body doesn't assign, so the synthesiser MUST hold the last
    -- value. ghdl-yosys-plugin defaults to erroring on inferred
    -- latches (the project's repo-wide `GHDL_SYNTH_EXTRA` is empty);
    -- this Makefile sets `GHDL_SYNTH_EXTRA := --latches` to permit
    -- the deliberate one here.
    DLATCH : process (en, a) is
    begin
        if en = '1' then
            r_dlatch <= a;
        end if;
    end process DLATCH;
    o_dlatch <= r_dlatch;

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

    -- 8 × 1-bit single-port synchronous RAM. Address is `sel & sel4`
    -- (3 bits), data-in is `a`, write-enable is `en`. yosys lifts
    -- this to a `$mem_v2` cell.
    mem_addr <= sel & sel4;
    MEM : process (clk) is
    begin
        if rising_edge(clk) then
            if en = '1' then
                mem_arr(to_integer(unsigned(mem_addr))) <= a;
            end if;
            mem_dout <= mem_arr(to_integer(unsigned(mem_addr)));
        end if;
    end process MEM;
    o_mem <= mem_dout;

end architecture rtl;
