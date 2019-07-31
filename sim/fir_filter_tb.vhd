----------------------------------------------------------------------------------
-- Company:
-- Engineer: Daniel Copley
-- 
-- Create Date: 07/12/2019 03:03:44 PM
-- Module Name: fir_filter_tb
-- 
-- Revision: 1.0
-- Additional Comments:
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

use std.textio.all;

library modules;

entity fir_filter_tb is
end fir_filter_tb;


architecture rtl of fir_filter_tb is
  
  constant TAP_WIDTH : natural := 18;
  constant DATA_IN_WIDTH : natural := 25;
  constant NUM_TAPS : natural := 20;
  constant DATA_OUT_WIDTH : natural := 48;
  
  constant CLK_FREQ     : natural := 100e6;  -- Hertz
  constant CLK_DUTYHIGH : real    := 50.0;   -- Percent time high.
  constant CLK_PHASE    : real    := 0.0;    -- Degrees between 0 and 359
  constant CLK_PERIOD   : time    := 1.0 sec / CLK_FREQ;
  
  constant RST_PERIOD   : time    := 50 ns;
  
  signal clk : std_logic := '0';
  signal rst : std_logic := '0';
  
  signal data_in : std_logic_vector(DATA_IN_WIDTH-1 downto 0) := (others => '0');
  signal data_out : std_logic_vector(DATA_OUT_WIDTH-1 downto 0) := (others => '0');
  signal data_in_vld : std_logic := '0';
  signal data_out_vld : std_logic;
  signal load_tap : std_logic := '0';
  signal new_tap : std_logic_vector(TAP_WIDTH-1 downto 0) := (others => '0');
  
begin

dut : entity modules.fir_filter
  generic map (
    TAP_IN_WIDTH => TAP_WIDTH,
    DATA_IN_WIDTH => DATA_IN_WIDTH,
    NUM_TAPS => NUM_TAPS,
    DATA_OUT_WIDTH => DATA_OUT_WIDTH,
    
    RESET_ALL => true
  )
  port map (
    rst => rst,
    clk => clk,
    data_in => data_in,
    load_tap => load_tap,
    new_tap => new_tap,
    data_in_vld => data_in_vld,
    data_out_vld => data_out_vld,
    data_out => data_out
  );

clkGen : process
begin
  clk <= transport '1' after (CLK_PERIOD * CLK_PHASE/360.0);
  clk <= transport '0' after (CLK_PERIOD * (CLK_DUTYHIGH/100.0 + CLK_PHASE/360.0));
  wait for CLK_PERIOD;
end process;

rstProc : process
begin
  rst <= '1', '0' after RST_PERIOD;
  wait;
end process;

loadTaps : process

  file in_taps : text open read_mode is "taps.data";
  variable inline : line;
  variable in_int : integer;

begin
  
  wait until rst='0';
  
  while (not endfile(in_taps)) loop
    
    wait until falling_edge(clk);
    load_tap <= '1';
    readline(in_taps, inline);
    read(inline, in_int);
    new_tap <= std_logic_vector(to_signed(in_int, TAP_WIDTH));
    
  end loop;
  
  wait until falling_edge(clk);
  load_tap <= '0';
  wait;
      
end process;

stimFir : process

  file in_sig : text open read_mode is "sig.data";
  variable inline : line;
  variable in_int : integer;
  
begin
  
  wait until rst='0';
  wait until load_tap='0';
  
  
  while (not endfile(in_sig)) loop
  
    wait until falling_edge(clk); 

    data_in_vld <= '1';
    readline(in_sig, inline);
    read(inline, in_int);
    data_in <= std_logic_vector(to_signed(in_int, DATA_IN_WIDTH));
    
  end loop;
  
  wait until falling_edge(clk);
  data_in_vld <= '0';
  
  wait until data_out_vld='0';
  
  wait until falling_edge(clk);
  assert (false) report "--SIMULATION COMPLETE--" severity failure;
  wait;

end process;

end rtl;
