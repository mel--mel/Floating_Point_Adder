--VLSI III
--PROJECT: FLOATING POINT ADDER
--Floating Point Adder
--MEL XRIS

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    
    entity adder is
        port (clk, rst: in std_logic;
              float1, float2: in std_logic_vector(31 downto 0);
              float_sum: out std_logic_vector(31 downto 0));
    end adder;
    
    architecture adder_arch of adder is
        
        --state A
        signal nan: std_logic;
        signal exponent_difference, shift_right_pos: integer;
        --state B
        signal large_exp_ctrl, small_no_ctrl, large_no_ctrl: std_logic;
        signal addsub, sign_out: std_logic;
        --state C
        signal small_significand, large_significand: std_logic_vector(23 downto 0);
        signal large_exponent: std_logic_vector (7 downto 0);
        --state D
        signal small_significand_shifted: std_logic_vector(26 downto 0);
        signal large_grs_significand: std_logic_vector(26 downto 0);
        --state E
        signal initial_sum: std_logic_vector(27 downto 0);
        signal fraction_final: std_logic_vector (24 downto 0);
        signal exponent_out_final: std_logic_vector (7 downto 0);
        --state F
        signal exp_ctrl, shift_fraction_ctrl, end_ctrl: std_logic;
        signal positions: integer;
        --state G
        signal ovf, unf: std_logic;
        signal sum: std_logic_vector(27 downto 0);
        signal expon_mux: std_logic_vector (7 downto 0);
        --state H
        signal exponent_out: std_logic_vector (7 downto 0);
        signal sum_shifted: std_logic_vector(26 downto 0);
        
        type state is (A, B, C, D, E, F, G, H, AI, J);
        signal current_state, next_state: state;
        
        begin
            process(clk,rst)
                
                begin
                    if (rst='1') then
                        
                        current_state <= A;         
                
                    elsif (clk'event and clk='1') then
                        
                        current_state <= next_state;
                             
                    end if;
            end process;
                
            
            process(current_state, float1, float2)
                
                --state D
                variable small_grs_significand: std_logic_vector (26 downto 0);
                variable shifter: std_logic_vector (26 downto 0);
                variable decider: integer;
                --state F
                variable n,i: integer;
                --state H
                variable sum_sh: std_logic_vector (27 downto 0);
                --state AI
                variable fraction_fin: std_logic_vector (24 downto 0);
                
                
                begin
                   case current_state is
                                                 --nan checker
                       when A => if ((float1(30 downto 23) = "11111111") and (float2(30 downto 23) = "11111111") and (float1(31) /= float2(31))) then
                                     nan <= '1';
                                 elsif ((float1(30 downto 23) = "11111111") and (float1(22 downto 0)/="00000000000000000000000")) then
                                     nan <= '1';
                                 elsif ((float2(30 downto 23) = "11111111") and (float2(22 downto 0)/="00000000000000000000000")) then
                                     nan <= '1';
                                 else
                                     nan <= '0';
                                 end if;
                           
                                 --small alu
                                 exponent_difference <= to_integer(unsigned(float1(30 downto 23))) - to_integer(unsigned(float2(30 downto 23)));   
                                 
                                 next_state <= B;
                                 
                                 --control + result_sign
                      when B => if (exponent_difference > 0) then            
                                    large_exp_ctrl <= '1';
                                    small_no_ctrl <= '0';
                                    large_no_ctrl <= '1';
                                    shift_right_pos <= exponent_difference;
                                    sign_out <= float1(31); --result sign
                                 else
                                    large_exp_ctrl <= '0';
                                    small_no_ctrl <= '1'; 
                                    large_no_ctrl <= '0';
                                    shift_right_pos <= (0 - exponent_difference);
                                    sign_out <= float2(31); --result sign
                                end if;
                                
                                if (float1(31)=float2(31)) then
                                    addsub <= '0';
                                else
                                    addsub <= '1';
                                end if;       
            
                                next_state <= C;
                                
                                --small fraction mux
                      when C => if (small_no_ctrl='1') then
                                    small_significand <= ('1' & float1(22 downto 0));
                                else
                                    small_significand <= ('1' & float2(22 downto 0));
                                end if;
                                
                                --large fraction mux
                                if (large_no_ctrl='1') then             
                                    large_significand <= ('1' & float1(22 downto 0));
                                else
                                    large_significand <= ('1' & float2(22 downto 0));
                                end if;
                                
                                --large expo mux
                                if (large_exp_ctrl='1') then
                                    large_exponent <= float1(30 downto 23); 
                                else
                                    large_exponent <= float2(30 downto 23);
                                end if;
                          
                                next_state <= D;
                                
                                --GRS = 000
                      when D => small_grs_significand :=  small_significand & "000";    
                                large_grs_significand <=  large_significand & "000";
                                
                                --right shift
                                if (shift_right_pos < 27) then                     
                                    decider := to_integer(unsigned(small_grs_significand(shift_right_pos downto 0)));
                                elsif (small_grs_significand = "000000000000000000000000000") then
                                    decider := 0;
                                else 
                                    decider := 1;
                                end if;
                          
                                shifter := std_logic_vector(unsigned(small_grs_significand) srl shift_right_pos);
                           
                                if (decider > 0) then
                                   small_significand_shifted <= (shifter(26 downto 1) & '1');
                                else 
                                   small_significand_shifted <= (shifter(26 downto 1) & '0');
                                end if;
                                
                                next_state <= E;
                              
                              --big alu  
                    when E => if (addsub = '0') then              
                                   initial_sum <= std_logic_vector(unsigned('0'&large_grs_significand) + unsigned('0'&small_significand_shifted));
                               else
                                   initial_sum <= std_logic_vector(unsigned('0'&large_grs_significand) - unsigned('0'&small_significand_shifted));
                               end if;
                               
                               --arxikopoihsh aparaithtwn
                               fraction_final <= (others=>'0');
                               exponent_out_final <= (others=>'0');
                               
                               next_state <= F;
                               
                              --normalize control
                    when F => if (fraction_final(24) = '1') then     
                                   end_ctrl <= '1';
                               else 
                                   end_ctrl <= '0';
                               end if;
                               
                               if  ((initial_sum(27) = '1') or (fraction_final(24) = '1')) then
                                    shift_fraction_ctrl <= '1';
                                    exp_ctrl <= '1';
                                    positions <= 1;
                               else
                                    shift_fraction_ctrl <= '0';
                                    exp_ctrl <= '0';
                                    n := 0;                  
                                    for i in 0 to 27 loop                       
                                          if (initial_sum(i)='1') then
                                              n := i;
                                          else 
                                              n := n;
                                          end if;
                                    end loop;
                                    positions <= 27 - n;
                               end if;
                               
                               next_state <= G;
                               
                              --of uf infinity check 
                    when G => if ((exp_ctrl = '0') and (to_integer(unsigned(large_exponent)) - positions <= 0)) then
                                   unf <= '1';
                               else
                                   unf <= '0';
                               end if; 
            
                               if ((exp_ctrl = '1') and (to_integer(unsigned(large_exponent)) + positions >= 255)) or (large_exponent = "11111111") then
                                   ovf <= '1';
                               else
                                   ovf <= '0';
                               end if; 
                               
                               --norm expo + significant mux
                               if (end_ctrl = '1') then           
                                   sum <= fraction_final & "000";
                                   expon_mux <= exponent_out_final;
                               else 
                                   sum <= initial_sum;
                                   expon_mux <= large_exponent;
                               end if;
                      
                               next_state <= H;
                               
                              --incr_dec
                    when H => if (nan='1' or ovf = '1') then            
                                   exponent_out <= "11111111";
                               elsif (exp_ctrl='0' and positions=27 and ovf = '0') then
                                   exponent_out <= "00000000";
                               elsif (exp_ctrl='1' and ovf = '0') then
                                   exponent_out <= std_logic_vector(unsigned(expon_mux) + to_unsigned(positions,8));
                               elsif (exp_ctrl='0' and unf = '0') then
                                   exponent_out <= std_logic_vector(unsigned(expon_mux) - to_unsigned(positions,8) + to_unsigned(1,8));
                               else 
                                   exponent_out <= "00000000";
                               end if; 
                               
                               --shift_left_right
                               if (shift_fraction_ctrl='1' and ovf = '0') then
                                   sum_sh := std_logic_vector(unsigned(sum) srl positions);
                               elsif (shift_fraction_ctrl='0' and unf = '0') then
                                   sum_sh := std_logic_vector(unsigned(sum) sll positions);
                               elsif (shift_fraction_ctrl='0' and unf = '1') then
                                   sum_sh := std_logic_vector(unsigned(sum) sll (to_integer(unsigned(large_exponent))));
                               end if;
                               
                               if (nan='1') then             
                                   sum_shifted <= "010000000000000000000000000";
                               elsif (ovf = '1') then
                                   sum_shifted <= "000000000000000000000000000";
                               elsif (shift_fraction_ctrl='1') then
                                   sum_shifted <= sum_sh(26 downto 0);
                               else
                                   sum_shifted <= sum_sh(27 downto 1); 
                               end if;
                               
                               next_state <= AI;
                        
                              --rounding
                    when AI => if (ovf = '1' and nan='0') then         
                                   fraction_fin := (others => '0');
                               elsif (sum_shifted(2)='0') then
                                   fraction_fin := '0' & sum_shifted(26 downto 3);
                               elsif (sum_shifted(2)='1' and ((sum_shifted(1) or sum_shifted(0)) = '1')) then
                                   fraction_fin := std_logic_vector(unsigned('0' & sum_shifted(26 downto 3)) + 1);
                               elsif (sum_shifted(2 downto 0)="100" and sum_shifted(3)='0') then
                                   fraction_fin := '0' & sum_shifted(26 downto 3);
                               else 
                                   fraction_fin := std_logic_vector(unsigned('0' & sum_shifted(26 downto 3)) + 1);
                               end if;
                               
                               exponent_out_final <= exponent_out;
                               fraction_final <= fraction_fin;
                               
                               if fraction_fin(24) = '1' then
                                   next_state <= F;
                               else 
                                   next_state <= J;
                               end if;
                               
                               --out
                    when J => float_sum <= sign_out & exponent_out_final & fraction_final(22 downto 0);   
                           
                              next_state <= A;
                           
                           end case;
            end process;
                     
        end adder_arch;
