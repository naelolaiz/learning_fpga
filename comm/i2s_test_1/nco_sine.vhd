----------------------------------------------------------------------
--                                                                  --
--  THIS VHDL SOURCE CODE IS PROVIDED UNDER THE GNU PUBLIC LICENSE  --
--                                                                  --
----------------------------------------------------------------------
--                                                                  --
--    Filename            : waveform_gen.vhd                        --
--                                                                  --
--    Author              : Simon Doherty                           --
--                          Senior Design Consultant                --
--                          www.zipcores.com                        --
--                                                                  --
--    Date last modified  : 23.10.2008                              --
--                                                                  --
--    Description         : NCO / Periodic Waveform Generator       --
--                                                                  --
----------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity nco_sine is

port (

  -- system signals
  clk         : in  std_logic;
  reset       : in  std_logic;

  -- NCO frequency control
  phase_inc   : in  std_logic_vector(31 downto 0);

  -- Output waveform: 16-bit signed sine, ±32767
  sin_out     : out std_logic_vector(15 downto 0)
    );
end entity;


architecture rtl of nco_sine is


component sincos_lut

port (

  clk      : in  std_logic;
  addr     : in  std_logic_vector(13 downto 0);
  sin_out  : out std_logic_vector(15 downto 0)
  );

end component;


signal  phase_acc : unsigned(31 downto 0) := (others => '0');
signal  lut_addr  : std_logic_vector(13 downto 0);


begin


--------------------------------------------------------------------------
-- Phase accumulator increments by 'phase_inc' every clock cycle        --
-- Output frequency determined by formula: Phase_inc = (Fout/Fclk)*2^32 --
-- E.g. Fout = 36MHz, Fclk = 100MHz,  Phase_inc = 36*2^32/100           --
-- Frequency resolution is 100MHz/2^32 = 0.00233Hz                      --
--------------------------------------------------------------------------

phase_acc_reg: process(clk, reset)
begin
  if reset = '1' then
    phase_acc <= (others => '0');
  elsif rising_edge(clk) then
    phase_acc <= phase_acc + unsigned(phase_inc);
  end if;
end process phase_acc_reg;

---------------------------------------------------------------------
-- use top 14 bits of phase accumulator to address the SIN/COS LUT --
---------------------------------------------------------------------

lut_addr <= std_logic_vector(phase_acc(31 downto 18));

------------------------------------------------------------------------
-- sincos_lut is 16384 x 16-bit signed sine. Address resolution =     --
-- 2*pi / 16384 ≈ 0.022 degrees per step.                             --
------------------------------------------------------------------------

lut: sincos_lut

  port map (

    clk       => clk,
    addr      => lut_addr,
    sin_out   => sin_out );

end rtl;