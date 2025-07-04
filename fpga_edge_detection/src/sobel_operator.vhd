library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

entity sobel_operator is
    generic (
        IMAGE_WIDTH  : integer := 640;
        IMAGE_HEIGHT : integer := 480;
        DATA_WIDTH   : integer := 8
    );
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;
        enable        : in  std_logic;
        pixel_in      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        pixel_valid   : in  std_logic;
        threshold     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        sobel_out     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        sobel_valid   : out std_logic;
        gradient_mag  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        gradient_dir  : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end sobel_operator;

architecture Behavioral of sobel_operator is

    -- 3x3 convolution window
    component convolution_3x3 is
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
    end component;

    -- 3x3 pixel window
    signal p11, p12, p13 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal p21, p22, p23 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal p31, p32, p33 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal window_valid : std_logic;
    
    -- Sobel kernels
    -- Gx = [-1  0  1]    Gy = [-1 -2 -1]
    --      [-2  0  2]         [ 0  0  0]
    --      [-1  0  1]         [ 1  2  1]
    
    -- Intermediate calculation signals
    signal gx_calc : signed(DATA_WIDTH+3 downto 0);
    signal gy_calc : signed(DATA_WIDTH+3 downto 0);
    signal gx_abs  : unsigned(DATA_WIDTH+2 downto 0);
    signal gy_abs  : unsigned(DATA_WIDTH+2 downto 0);
    signal gradient_magnitude : unsigned(DATA_WIDTH+3 downto 0);
    signal gradient_angle : unsigned(DATA_WIDTH-1 downto 0);
    
    -- Pipeline registers
    signal gx_reg1, gy_reg1 : signed(DATA_WIDTH+3 downto 0);
    signal gx_reg2, gy_reg2 : signed(DATA_WIDTH+3 downto 0);
    signal mag_reg1, mag_reg2 : unsigned(DATA_WIDTH+3 downto 0);
    signal dir_reg1, dir_reg2 : unsigned(DATA_WIDTH-1 downto 0);
    signal valid_reg1, valid_reg2, valid_reg3 : std_logic;
    
    -- Output registers
    signal sobel_result : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal sobel_valid_out : std_logic;
    signal magnitude_out : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal direction_out : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

    -- 3x3 convolution window generator
    conv_window : convolution_3x3
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk         => clk,
            reset       => reset,
            enable      => enable,
            pixel_in    => pixel_in,
            pixel_valid => pixel_valid,
            p11 => p11, p12 => p12, p13 => p13,
            p21 => p21, p22 => p22, p23 => p23,
            p31 => p31, p32 => p32, p33 => p33,
            window_valid => window_valid
        );

    -- Sobel gradient calculation (Stage 1)
    sobel_calc : process(clk, reset)
    begin
        if reset = '1' then
            gx_calc <= (others => '0');
            gy_calc <= (others => '0');
            valid_reg1 <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                valid_reg1 <= window_valid;
                
                if window_valid = '1' then
                    -- Gx calculation: horizontal gradient
                    gx_calc <= signed('0' & p13) + signed('0' & p23 & '0') + signed('0' & p33) 
                             - signed('0' & p11) - signed('0' & p21 & '0') - signed('0' & p31);
                    
                    -- Gy calculation: vertical gradient  
                    gy_calc <= signed('0' & p31) + signed('0' & p32 & '0') + signed('0' & p33)
                             - signed('0' & p11) - signed('0' & p12 & '0') - signed('0' & p13);
                else
                    gx_calc <= (others => '0');
                    gy_calc <= (others => '0');
                end if;
            else
                valid_reg1 <= '0';
            end if;
        end if;
    end process;

    -- Absolute value and magnitude calculation (Stage 2)
    mag_calc : process(clk, reset)
    begin
        if reset = '1' then
            gx_reg1 <= (others => '0');
            gy_reg1 <= (others => '0');
            gx_abs <= (others => '0');
            gy_abs <= (others => '0');
            valid_reg2 <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                valid_reg2 <= valid_reg1;
                gx_reg1 <= gx_calc;
                gy_reg1 <= gy_calc;
                
                if valid_reg1 = '1' then
                    -- Calculate absolute values
                    if gx_calc < 0 then
                        gx_abs <= unsigned(-gx_calc);
                    else
                        gx_abs <= unsigned(gx_calc);
                    end if;
                    
                    if gy_calc < 0 then
                        gy_abs <= unsigned(-gy_calc);
                    else
                        gy_abs <= unsigned(gy_calc);
                    end if;
                else
                    gx_abs <= (others => '0');
                    gy_abs <= (others => '0');
                end if;
            else
                valid_reg2 <= '0';
            end if;
        end if;
    end process;

    -- Gradient magnitude and direction calculation (Stage 3)
    final_calc : process(clk, reset)
    begin
        if reset = '1' then
            gradient_magnitude <= (others => '0');
            gradient_angle <= (others => '0');
            mag_reg1 <= (others => '0');
            dir_reg1 <= (others => '0');
            valid_reg3 <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                valid_reg3 <= valid_reg2;
                
                if valid_reg2 = '1' then
                    -- Approximate magnitude using: |Gx| + |Gy| (Manhattan distance)
                    -- This is faster than sqrt(Gx^2 + Gy^2) and close enough for edge detection
                    gradient_magnitude <= ('0' & gx_abs) + ('0' & gy_abs);
                    
                    -- Approximate gradient direction (8 directions: 0, 45, 90, 135 degrees)
                    if gx_abs > gy_abs then
                        if gx_reg1 >= 0 then
                            gradient_angle <= to_unsigned(0, DATA_WIDTH);   -- 0 degrees
                        else
                            gradient_angle <= to_unsigned(180, DATA_WIDTH); -- 180 degrees
                        end if;
                    else
                        if gy_reg1 >= 0 then
                            gradient_angle <= to_unsigned(90, DATA_WIDTH);  -- 90 degrees
                        else
                            gradient_angle <= to_unsigned(270, DATA_WIDTH); -- 270 degrees
                        end if;
                    end if;
                    
                    mag_reg1 <= gradient_magnitude;
                    dir_reg1 <= gradient_angle;
                else
                    gradient_magnitude <= (others => '0');
                    gradient_angle <= (others => '0');
                    mag_reg1 <= (others => '0');
                    dir_reg1 <= (others => '0');
                end if;
            else
                valid_reg3 <= '0';
            end if;
        end if;
    end process;

    -- Output assignment and thresholding
    output_proc : process(clk, reset)
    begin
        if reset = '1' then
            sobel_result <= (others => '0');
            sobel_valid_out <= '0';
            magnitude_out <= (others => '0');
            direction_out <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '1' then
                sobel_valid_out <= valid_reg3;
                
                if valid_reg3 = '1' then
                    -- Clamp magnitude to DATA_WIDTH range
                    if gradient_magnitude > 2**DATA_WIDTH - 1 then
                        magnitude_out <= (others => '1');
                    else
                        magnitude_out <= std_logic_vector(gradient_magnitude(DATA_WIDTH-1 downto 0));
                    end if;
                    
                    direction_out <= std_logic_vector(gradient_angle);
                    
                    -- Apply threshold for binary edge detection
                    if gradient_magnitude > unsigned(threshold) then
                        sobel_result <= (others => '1'); -- White pixel (edge)
                    else
                        sobel_result <= (others => '0'); -- Black pixel (no edge)
                    end if;
                else
                    sobel_result <= (others => '0');
                    magnitude_out <= (others => '0');
                    direction_out <= (others => '0');
                end if;
            else
                sobel_valid_out <= '0';
            end if;
        end if;
    end process;

    -- Output assignments
    sobel_out <= sobel_result;
    sobel_valid <= sobel_valid_out;
    gradient_mag <= magnitude_out;
    gradient_dir <= direction_out;

end Behavioral;