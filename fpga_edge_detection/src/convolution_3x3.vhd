library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity convolution_3x3 is
    generic (
        DATA_WIDTH : integer := 8
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        enable      : in  std_logic;
        pixel_in    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        pixel_valid : in  std_logic;
        p11, p12, p13 : out std_logic_vector(DATA_WIDTH-1 downto 0);
        p21, p22, p23 : out std_logic_vector(DATA_WIDTH-1 downto 0);
        p31, p32, p33 : out std_logic_vector(DATA_WIDTH-1 downto 0);
        window_valid  : out std_logic
    );
end convolution_3x3;

architecture Behavioral of convolution_3x3 is
    
    -- 3x3 pixel shift register
    signal shift_reg : std_logic_vector(9*DATA_WIDTH-1 downto 0) := (others => '0');
    signal valid_count : integer range 0 to 9 := 0;
    signal window_ready : std_logic := '0';
    
begin

    -- Shift register process for 3x3 window
    shift_process : process(clk, reset)
    begin
        if reset = '1' then
            shift_reg <= (others => '0');
            valid_count <= 0;
            window_ready <= '0';
        elsif rising_edge(clk) then
            if enable = '1' and pixel_valid = '1' then
                -- Shift the register and insert new pixel
                shift_reg <= shift_reg(8*DATA_WIDTH-1 downto 0) & pixel_in;
                
                -- Count valid pixels until we have a full 3x3 window
                if valid_count < 8 then
                    valid_count <= valid_count + 1;
                    window_ready <= '0';
                else
                    window_ready <= '1';
                end if;
            elsif enable = '0' then
                window_ready <= '0';
            end if;
        end if;
    end process;
    
    -- Extract 3x3 window from shift register
    -- Window layout:
    -- p11 p12 p13
    -- p21 p22 p23  
    -- p31 p32 p33
    
    p11 <= shift_reg(9*DATA_WIDTH-1 downto 8*DATA_WIDTH);
    p12 <= shift_reg(8*DATA_WIDTH-1 downto 7*DATA_WIDTH);
    p13 <= shift_reg(7*DATA_WIDTH-1 downto 6*DATA_WIDTH);
    p21 <= shift_reg(6*DATA_WIDTH-1 downto 5*DATA_WIDTH);
    p22 <= shift_reg(5*DATA_WIDTH-1 downto 4*DATA_WIDTH);
    p23 <= shift_reg(4*DATA_WIDTH-1 downto 3*DATA_WIDTH);
    p31 <= shift_reg(3*DATA_WIDTH-1 downto 2*DATA_WIDTH);
    p32 <= shift_reg(2*DATA_WIDTH-1 downto 1*DATA_WIDTH);
    p33 <= shift_reg(1*DATA_WIDTH-1 downto 0*DATA_WIDTH);
    
    window_valid <= window_ready;
    
end Behavioral;