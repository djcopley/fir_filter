----------------------------------------------------------------------------------
-- Company:
-- Engineer: Daniel Copley
-- 
-- Create Date: 07/15/2019 04:00:45 PM
-- Module Name: fir_filter
--
-- Revision: 1.0
-- Additional Comments:
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fir_filter is
  generic(
    NUM_TAPS : natural := 12;
    DATA_IN_WIDTH : natural := 25; -- DSP48 coeff width 25 bits
    TAP_IN_WIDTH : natural := 18; -- DSP48 coeff width 18 bits
    DATA_OUT_WIDTH : natural := 48; -- DSP48 accumulator width 48 bits
    
    RESET_ALL : boolean := false -- if true, coefficients and processing chain will also be reset
  );
  port(
    clk : in std_logic;
    rst : in std_logic;
    load_tap : in std_logic; -- active high
    new_tap : in std_logic_vector(TAP_IN_WIDTH-1 downto 0);
    data_in_vld : in std_logic;
    data_in : in std_logic_vector(DATA_IN_WIDTH-1 downto 0);
    data_out_vld : out std_logic;
    data_out : out std_logic_vector(DATA_OUT_WIDTH-1 downto 0) -- 48 bit output from DSP48 accumulator
  );
end entity fir_filter;

architecture rtl of fir_filter is
  -- constants
  constant DSP48_DATA_IN_WIDTH : natural := 25;
  constant DSP48_TAP_WIDTH : natural := 18;
  constant DSP48_MREG_WIDTH : natural := 43;
  constant DSP48_ACCUM_WIDTH : natural := 48;
  
  -- delays
  signal data_in_d : signed(DSP48_DATA_IN_WIDTH-1 downto 0) := (others => '0');
  
  type data_out_vld_d_t is array(0 to (NUM_TAPS + 1)) of std_logic;
  signal data_out_vld_d : data_out_vld_d_t := (others => '0');
  
  -- fir types
  type accumulator_t is array(0 to NUM_TAPS-1) of signed(DSP48_ACCUM_WIDTH-1 downto 0); -- 48 bits for DSP slice
  signal sum_chain : accumulator_t := (others => (others => '0'));

  type multiplier_t is array(0 to NUM_TAPS-1) of signed(DSP48_MREG_WIDTH-1 downto 0);
  signal mult_chain : multiplier_t := (others => (others => '0')); -- register multiplication result so mreg can be inferred

  type delay_reg_t is array(0 to NUM_TAPS-2) of signed(DSP48_DATA_IN_WIDTH-1 downto 0);
  signal delay_reg_1, delay_reg_2 : delay_reg_t := (others => (others => '0'));

  type taps_t is array(0 to NUM_TAPS-1) of signed(DSP48_TAP_WIDTH-1 downto 0);
  signal taps : taps_t := (others => (others => '0'));
  signal tap_in_d : signed(DSP48_TAP_WIDTH-1 downto 0);
 

  attribute use_dsp : string;
  attribute use_dsp of sum_chain, mult_chain : signal is "yes";

begin

  -- check data widths
  assert NUM_TAPS >= 2;
  assert DATA_IN_WIDTH <= 25 severity failure;
  assert TAP_IN_WIDTH <= 18 severity failure;
  assert DATA_OUT_WIDTH <= 48 severity failure;
  
  procFir : process(clk)
  begin
    if rising_edge(clk) then
    
      if rst='1' and RESET_ALL then
        
        data_in_d <= (others => '0');
        delay_reg_1 <= (others => (others => '0'));
        delay_reg_2 <= (others => (others => '0'));
        mult_chain <= (others => (others => '0'));
        sum_chain <= (others => (others => '0'));
        data_out <= (others => '0');

      else

        if data_in_vld='1' then
        
          --register input data and convert to signed for DSP slice
          data_in_d <= resize(signed(data_in), DSP48_DATA_IN_WIDTH);
                  
          -- register data in
          delay_reg_1(0) <= data_in_d;
          for ii in 1 to NUM_TAPS-2 loop
            delay_reg_1(ii) <= delay_reg_2(ii-1);
          end loop;
          
        end if;
                
        -- double register
        for ii in 0 to NUM_TAPS-2 loop
          delay_reg_2(ii) <= delay_reg_1(ii);
        end loop;
        
        -- multiply & accumulate
        mult_chain(0) <= resize(data_in_d * taps(0), DSP48_MREG_WIDTH);
        sum_chain(0) <= resize(mult_chain(0), DSP48_ACCUM_WIDTH);
        multAccumLoop : for ii in 1 to NUM_TAPS-1 loop
          mult_chain(ii) <= resize(delay_reg_2(ii-1) * taps(ii), DSP48_MREG_WIDTH);
          sum_chain(ii) <= resize(mult_chain(ii) + sum_chain(ii-1), DSP48_ACCUM_WIDTH);
        end loop;
        
        if data_out_vld_d(data_out_vld_d'high)='1' then
          data_out <= std_logic_vector(resize(sum_chain(sum_chain'high), DATA_OUT_WIDTH));
        end if;
          
        end if;
    end if;
  end process;

  loadTaps : process(clk)
  begin
    if rising_edge(clk) then
     
      if rst='1' and RESET_ALL then
        
        taps <= (others => (others => '0'));
        
      else
        
        -- shift taps in
        if load_tap='1' then
          taps(taps'high) <= resize(signed(new_tap), DSP48_TAP_WIDTH);
          for tap in taps'high-1 downto 0 loop
            taps(tap) <= taps(tap+1); -- Load taps in from the right (shift down)
          end loop;
        end if;
        
      end if;
    end if;
  end process;
  
  dataVld : process(clk)
  begin
    
    if rising_edge(clk) then
    
      if rst='1'  then
        
        data_out_vld_d <= (others => '0');
        data_out_vld <= '0';

      else

        -- Register data in valid        
        data_out_vld_d(0) <= data_in_vld;
        
        -- shift data valid
        for ii in 1 to data_out_vld_d'high loop
          data_out_vld_d(ii) <= data_out_vld_d(ii-1);
        end loop;
        data_out_vld <= data_out_vld_d(data_out_vld_d'high);
        
      end if;
    end if;
    
  end process;

end architecture rtl;
