library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity non_max_suppression is
    generic (
        IMAGE_WIDTH : integer := 640;
        DATA_WIDTH  : integer := 8
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        enable      : in  std_logic;
        mag_in      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        dir_in      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data_valid  : in  std_logic;
        mag_out     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        nms_valid   : out std_logic
    );
end non_max_suppression;

architecture Behavioral of non_max_suppression is

    -- 3x3 window buffer for magnitude values
    component magnitude_window_3x3 is
        generic (
            IMAGE_WIDTH : integer := 640;
            DATA_WIDTH  : integer := 8
        );
        port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            enable      : in  std_logic;
            mag_in      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            dir_in      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            data_valid  : in  std_logic;
            m11, m12, m13 : out std_logic_vector(DATA_WIDTH-1 downto 0);
            m21, m22, m23 : out std_logic_vector(DATA_WIDTH-1 downto 0);
            m31, m32, m33 : out std_logic_vector(DATA_WIDTH-1 downto 0);
            center_dir    : out std_logic_vector(DATA_WIDTH-1 downto 0);
            window_valid  : out std_logic
        );
    end component;

    -- 3x3 magnitude window
    signal m11, m12, m13 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal m21, m22, m23 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal m31, m32, m33 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal center_direction : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal window_valid : std_logic;

    -- Direction categories
    signal dir_category : integer range 0 to 3;
    signal neighbor1, neighbor2 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal center_mag : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Output registers
    signal nms_result : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal nms_valid_out : std_logic;

begin

    -- Magnitude window generator
    mag_window : magnitude_window_3x3
        generic map (
            IMAGE_WIDTH => IMAGE_WIDTH,
            DATA_WIDTH  => DATA_WIDTH
        )
        port map (
            clk         => clk,
            reset       => reset,
            enable      => enable,
            mag_in      => mag_in,
            dir_in      => dir_in,
            data_valid  => data_valid,
            m11 => m11, m12 => m12, m13 => m13,
            m21 => m21, m22 => m22, m23 => m23,
            m31 => m31, m32 => m32, m33 => m33,
            center_dir  => center_direction,
            window_valid => window_valid
        );

    center_mag <= m22; -- Center pixel magnitude

    -- Direction categorization and neighbor selection
    direction_decode : process(clk, reset)
    begin
        if reset = '1' then
            dir_category <= 0;
            neighbor1 <= (others => '0');
            neighbor2 <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '1' and window_valid = '1' then
                -- Quantize gradient direction to 4 categories (0, 45, 90, 135 degrees)
                if unsigned(center_direction) < 23 or unsigned(center_direction) >= 337 then
                    -- 0 degrees (horizontal)
                    dir_category <= 0;
                    neighbor1 <= m21; -- Left neighbor
                    neighbor2 <= m23; -- Right neighbor
                elsif unsigned(center_direction) >= 23 and unsigned(center_direction) < 68 then
                    -- 45 degrees (diagonal)
                    dir_category <= 1;
                    neighbor1 <= m31; -- Bottom-left neighbor
                    neighbor2 <= m13; -- Top-right neighbor
                elsif unsigned(center_direction) >= 68 and unsigned(center_direction) < 113 then
                    -- 90 degrees (vertical)
                    dir_category <= 2;
                    neighbor1 <= m12; -- Top neighbor
                    neighbor2 <= m32; -- Bottom neighbor
                else
                    -- 135 degrees (diagonal)
                    dir_category <= 3;
                    neighbor1 <= m11; -- Top-left neighbor
                    neighbor2 <= m33; -- Bottom-right neighbor
                end if;
            else
                neighbor1 <= (others => '0');
                neighbor2 <= (others => '0');
            end if;
        end if;
    end process;

    -- Non-maximum suppression logic
    nms_logic : process(clk, reset)
    begin
        if reset = '1' then
            nms_result <= (others => '0');
            nms_valid_out <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                nms_valid_out <= window_valid;
                
                if window_valid = '1' then
                    -- Suppress if center magnitude is not maximum among its gradient direction neighbors
                    if (unsigned(center_mag) >= unsigned(neighbor1)) and (unsigned(center_mag) >= unsigned(neighbor2)) then
                        nms_result <= center_mag; -- Keep edge pixel
                    else
                        nms_result <= (others => '0'); -- Suppress pixel
                    end if;
                else
                    nms_result <= (others => '0');
                end if;
            else
                nms_valid_out <= '0';
            end if;
        end if;
    end process;

    -- Output assignments
    mag_out <= nms_result;
    nms_valid <= nms_valid_out;

end Behavioral;