library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity canny_detector is
    generic (
        IMAGE_WIDTH  : integer := 640;
        IMAGE_HEIGHT : integer := 480;
        DATA_WIDTH   : integer := 8
    );
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;
        enable        : in  std_logic;
        gradient_mag  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        gradient_dir  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        gradient_valid: in  std_logic;
        low_threshold : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        high_threshold: in  std_logic_vector(DATA_WIDTH-1 downto 0);
        canny_out     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        canny_valid   : out std_logic
    );
end canny_detector;

architecture Behavioral of canny_detector is

    -- Non-maximum suppression component
    component non_max_suppression is
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
    end component;

    -- Hysteresis thresholding component
    component hysteresis_threshold is
        generic (
            IMAGE_WIDTH : integer := 640;
            DATA_WIDTH  : integer := 8
        );
        port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            enable      : in  std_logic;
            mag_in      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            data_valid  : in  std_logic;
            low_th      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            high_th     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            edge_out    : out std_logic_vector(DATA_WIDTH-1 downto 0);
            hyst_valid  : out std_logic
        );
    end component;

    -- Internal signals
    signal nms_magnitude : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal nms_valid : std_logic;
    signal hyst_result : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal hyst_valid : std_logic;

begin

    -- Non-maximum suppression to thin edges
    nms_inst : non_max_suppression
        generic map (
            IMAGE_WIDTH => IMAGE_WIDTH,
            DATA_WIDTH  => DATA_WIDTH
        )
        port map (
            clk        => clk,
            reset      => reset,
            enable     => enable,
            mag_in     => gradient_mag,
            dir_in     => gradient_dir,
            data_valid => gradient_valid,
            mag_out    => nms_magnitude,
            nms_valid  => nms_valid
        );

    -- Hysteresis thresholding for edge linking
    hyst_inst : hysteresis_threshold
        generic map (
            IMAGE_WIDTH => IMAGE_WIDTH,
            DATA_WIDTH  => DATA_WIDTH
        )
        port map (
            clk        => clk,
            reset      => reset,
            enable     => enable,
            mag_in     => nms_magnitude,
            data_valid => nms_valid,
            low_th     => low_threshold,
            high_th    => high_threshold,
            edge_out   => hyst_result,
            hyst_valid => hyst_valid
        );

    -- Output assignments
    canny_out <= hyst_result;
    canny_valid <= hyst_valid;

end Behavioral;