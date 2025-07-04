library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity edge_detection_top is
    generic (
        IMAGE_WIDTH  : integer := 640;
        IMAGE_HEIGHT : integer := 480;
        DATA_WIDTH   : integer := 8;
        ADDR_WIDTH   : integer := 19  -- log2(640*480)
    );
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;
        enable          : in  std_logic;
        
        -- Input image interface
        pixel_in        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        pixel_valid_in  : in  std_logic;
        pixel_ready_out : out std_logic;
        
        -- Output edge image interface
        edge_out        : out std_logic_vector(DATA_WIDTH-1 downto 0);
        edge_valid_out  : out std_logic;
        edge_ready_in   : in  std_logic;
        
        -- Configuration interface
        sobel_threshold : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        canny_low_th    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        canny_high_th   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        hybrid_mode     : in  std_logic_vector(1 downto 0); -- 00: Sobel, 01: Canny, 10: Hybrid
        
        -- Status outputs
        processing_done : out std_logic;
        frame_count     : out std_logic_vector(15 downto 0)
    );
end edge_detection_top;

architecture Behavioral of edge_detection_top is
    
    -- Component declarations
    component sobel_operator is
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
    end component;
    
    component canny_detector is
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
    end component;
    
    component line_buffer is
        generic (
            IMAGE_WIDTH : integer := 640;
            DATA_WIDTH  : integer := 8
        );
        port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            enable      : in  std_logic;
            pixel_in    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            pixel_valid : in  std_logic;
            line1_out   : out std_logic_vector(DATA_WIDTH-1 downto 0);
            line2_out   : out std_logic_vector(DATA_WIDTH-1 downto 0);
            line3_out   : out std_logic_vector(DATA_WIDTH-1 downto 0);
            data_valid  : out std_logic
        );
    end component;
    
    -- Internal signals
    signal line1_data, line2_data, line3_data : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal line_data_valid : std_logic;
    
    signal sobel_result : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal sobel_valid  : std_logic;
    signal gradient_magnitude : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal gradient_direction : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal canny_result : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal canny_valid  : std_logic;
    
    signal hybrid_result : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal hybrid_valid  : std_logic;
    
    signal frame_counter : std_logic_vector(15 downto 0) := (others => '0');
    signal pixel_counter : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal processing_active : std_logic := '0';
    
begin
    
    -- Line buffer for 3x3 convolution window
    line_buf_inst : line_buffer
        generic map (
            IMAGE_WIDTH => IMAGE_WIDTH,
            DATA_WIDTH  => DATA_WIDTH
        )
        port map (
            clk         => clk,
            reset       => reset,
            enable      => enable,
            pixel_in    => pixel_in,
            pixel_valid => pixel_valid_in,
            line1_out   => line1_data,
            line2_out   => line2_data,
            line3_out   => line3_data,
            data_valid  => line_data_valid
        );
    
    -- Sobel edge detection operator
    sobel_inst : sobel_operator
        generic map (
            IMAGE_WIDTH  => IMAGE_WIDTH,
            IMAGE_HEIGHT => IMAGE_HEIGHT,
            DATA_WIDTH   => DATA_WIDTH
        )
        port map (
            clk           => clk,
            reset         => reset,
            enable        => enable,
            pixel_in      => line2_data,  -- Center pixel
            pixel_valid   => line_data_valid,
            threshold     => sobel_threshold,
            sobel_out     => sobel_result,
            sobel_valid   => sobel_valid,
            gradient_mag  => gradient_magnitude,
            gradient_dir  => gradient_direction
        );
    
    -- Canny edge detector
    canny_inst : canny_detector
        generic map (
            IMAGE_WIDTH  => IMAGE_WIDTH,
            IMAGE_HEIGHT => IMAGE_HEIGHT,
            DATA_WIDTH   => DATA_WIDTH
        )
        port map (
            clk           => clk,
            reset         => reset,
            enable        => enable,
            gradient_mag  => gradient_magnitude,
            gradient_dir  => gradient_direction,
            gradient_valid=> sobel_valid,
            low_threshold => canny_low_th,
            high_threshold=> canny_high_th,
            canny_out     => canny_result,
            canny_valid   => canny_valid
        );
    
    -- Hybrid algorithm selector
    process(clk, reset)
    begin
        if reset = '1' then
            hybrid_result <= (others => '0');
            hybrid_valid <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                case hybrid_mode is
                    when "00" =>  -- Pure Sobel
                        hybrid_result <= sobel_result;
                        hybrid_valid <= sobel_valid;
                    when "01" =>  -- Pure Canny
                        hybrid_result <= canny_result;
                        hybrid_valid <= canny_valid;
                    when "10" =>  -- Hybrid: Sobel for fast detection, Canny for refinement
                        if sobel_result > sobel_threshold then
                            hybrid_result <= canny_result;
                        else
                            hybrid_result <= (others => '0');
                        end if;
                        hybrid_valid <= canny_valid;
                    when others =>
                        hybrid_result <= sobel_result;
                        hybrid_valid <= sobel_valid;
                end case;
            else
                hybrid_valid <= '0';
            end if;
        end if;
    end process;
    
    -- Frame and pixel counting
    process(clk, reset)
    begin
        if reset = '1' then
            frame_counter <= (others => '0');
            pixel_counter <= (others => '0');
            processing_active <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                if pixel_valid_in = '1' then
                    if pixel_counter = IMAGE_WIDTH * IMAGE_HEIGHT - 1 then
                        pixel_counter <= (others => '0');
                        frame_counter <= frame_counter + 1;
                        processing_active <= '0';
                    else
                        pixel_counter <= pixel_counter + 1;
                        processing_active <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- Output assignments
    edge_out <= hybrid_result;
    edge_valid_out <= hybrid_valid;
    pixel_ready_out <= edge_ready_in and enable;
    processing_done <= not processing_active;
    frame_count <= frame_counter;
    
end Behavioral;