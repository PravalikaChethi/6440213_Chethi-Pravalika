library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

entity edge_detection_tb is
end edge_detection_tb;

architecture Behavioral of edge_detection_tb is

    -- Component declaration
    component edge_detection_top is
        generic (
            IMAGE_WIDTH  : integer := 640;
            IMAGE_HEIGHT : integer := 480;
            DATA_WIDTH   : integer := 8;
            ADDR_WIDTH   : integer := 19
        );
        port (
            clk             : in  std_logic;
            reset           : in  std_logic;
            enable          : in  std_logic;
            pixel_in        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            pixel_valid_in  : in  std_logic;
            pixel_ready_out : out std_logic;
            edge_out        : out std_logic_vector(DATA_WIDTH-1 downto 0);
            edge_valid_out  : out std_logic;
            edge_ready_in   : in  std_logic;
            sobel_threshold : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            canny_low_th    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            canny_high_th   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            hybrid_mode     : in  std_logic_vector(1 downto 0);
            processing_done : out std_logic;
            frame_count     : out std_logic_vector(15 downto 0)
        );
    end component;

    -- Test parameters
    constant CLOCK_PERIOD : time := 10 ns; -- 100 MHz
    constant TEST_WIDTH   : integer := 64;  -- Smaller test image
    constant TEST_HEIGHT  : integer := 48;
    constant DATA_WIDTH   : integer := 8;
    constant ADDR_WIDTH   : integer := 12; -- log2(64*48)

    -- Test signals
    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal enable : std_logic := '0';
    signal pixel_in : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal pixel_valid_in : std_logic := '0';
    signal pixel_ready_out : std_logic;
    signal edge_out : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal edge_valid_out : std_logic;
    signal edge_ready_in : std_logic := '1';
    signal sobel_threshold : std_logic_vector(DATA_WIDTH-1 downto 0) := x"30";
    signal canny_low_th : std_logic_vector(DATA_WIDTH-1 downto 0) := x"20";
    signal canny_high_th : std_logic_vector(DATA_WIDTH-1 downto 0) := x"60";
    signal hybrid_mode : std_logic_vector(1 downto 0) := "10"; -- Hybrid mode
    signal processing_done : std_logic;
    signal frame_count : std_logic_vector(15 downto 0);

    -- Test image data
    type test_image_type is array (0 to TEST_WIDTH*TEST_HEIGHT-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal test_image : test_image_type;
    
    -- Test control signals
    signal test_running : boolean := false;
    signal pixel_index : integer := 0;
    signal frame_complete : boolean := false;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut : edge_detection_top
        generic map (
            IMAGE_WIDTH  => TEST_WIDTH,
            IMAGE_HEIGHT => TEST_HEIGHT,
            DATA_WIDTH   => DATA_WIDTH,
            ADDR_WIDTH   => ADDR_WIDTH
        )
        port map (
            clk             => clk,
            reset           => reset,
            enable          => enable,
            pixel_in        => pixel_in,
            pixel_valid_in  => pixel_valid_in,
            pixel_ready_out => pixel_ready_out,
            edge_out        => edge_out,
            edge_valid_out  => edge_valid_out,
            edge_ready_in   => edge_ready_in,
            sobel_threshold => sobel_threshold,
            canny_low_th    => canny_low_th,
            canny_high_th   => canny_high_th,
            hybrid_mode     => hybrid_mode,
            processing_done => processing_done,
            frame_count     => frame_count
        );

    -- Clock generation
    clk_process : process
    begin
        clk <= '0';
        wait for CLOCK_PERIOD/2;
        clk <= '1';
        wait for CLOCK_PERIOD/2;
    end process;

    -- Generate test image with various edge patterns
    test_image_gen : process
        variable row, col : integer;
        variable pixel_val : integer;
    begin
        -- Initialize test image with gradient and edge patterns
        for i in 0 to TEST_WIDTH*TEST_HEIGHT-1 loop
            row := i / TEST_WIDTH;
            col := i mod TEST_WIDTH;
            
            -- Create different patterns in different regions
            if row < TEST_HEIGHT/4 then
                -- Horizontal gradient
                pixel_val := (col * 255) / TEST_WIDTH;
            elsif row < TEST_HEIGHT/2 then
                -- Vertical gradient
                pixel_val := ((row - TEST_HEIGHT/4) * 255) / (TEST_HEIGHT/4);
            elsif row < 3*TEST_HEIGHT/4 then
                -- Checkerboard pattern
                if ((row/4) mod 2) = ((col/4) mod 2) then
                    pixel_val := 200;
                else
                    pixel_val := 50;
                end if;
            else
                -- Diagonal pattern
                if (row + col) mod 8 < 4 then
                    pixel_val := 255;
                else
                    pixel_val := 0;
                end if;
            end if;
            
            test_image(i) <= std_logic_vector(to_unsigned(pixel_val, DATA_WIDTH));
        end loop;
        wait;
    end process;

    -- Stimulus process
    stimulus : process
    begin
        -- Initialize
        reset <= '1';
        enable <= '0';
        pixel_valid_in <= '0';
        edge_ready_in <= '1';
        wait for 100 ns;
        
        -- Release reset
        reset <= '0';
        wait for 50 ns;
        
        -- Enable system
        enable <= '1';
        wait for 20 ns;
        
        -- Test Sobel mode
        report "Testing Sobel edge detection mode";
        hybrid_mode <= "00"; -- Pure Sobel
        sobel_threshold <= x"40";
        test_running <= true;
        
        -- Send test image
        for i in 0 to TEST_WIDTH*TEST_HEIGHT-1 loop
            pixel_in <= test_image(i);
            pixel_valid_in <= '1';
            pixel_index <= i;
            wait for CLOCK_PERIOD;
            
            -- Add some gaps to test flow control
            if i mod 10 = 0 then
                pixel_valid_in <= '0';
                wait for CLOCK_PERIOD * 2;
            end if;
        end loop;
        
        pixel_valid_in <= '0';
        wait for 1000 ns;
        
        -- Test Canny mode
        report "Testing Canny edge detection mode";
        hybrid_mode <= "01"; -- Pure Canny
        canny_low_th <= x"20";
        canny_high_th <= x"60";
        
        -- Send test image again
        for i in 0 to TEST_WIDTH*TEST_HEIGHT-1 loop
            pixel_in <= test_image(i);
            pixel_valid_in <= '1';
            wait for CLOCK_PERIOD;
        end loop;
        
        pixel_valid_in <= '0';
        wait for 1000 ns;
        
        -- Test Hybrid mode
        report "Testing Hybrid edge detection mode";
        hybrid_mode <= "10"; -- Hybrid
        
        -- Send test image again
        for i in 0 to TEST_WIDTH*TEST_HEIGHT-1 loop
            pixel_in <= test_image(i);
            pixel_valid_in <= '1';
            wait for CLOCK_PERIOD;
        end loop;
        
        pixel_valid_in <= '0';
        wait for 2000 ns;
        
        test_running <= false;
        report "Test completed successfully";
        wait;
    end process;

    -- Monitor output edges
    output_monitor : process(clk)
        file output_file : text;
        variable output_line : line;
        variable pixel_count : integer := 0;
    begin
        if rising_edge(clk) then
            if edge_valid_out = '1' then
                -- Log edge pixels for analysis
                if pixel_count = 0 then
                    report "First edge output received";
                end if;
                pixel_count := pixel_count + 1;
                
                -- Every 100th edge pixel, report progress
                if pixel_count mod 100 = 0 then
                    report "Processed " & integer'image(pixel_count) & " edge pixels";
                end if;
            end if;
        end if;
    end process;

    -- Performance monitor
    performance_monitor : process(clk)
        variable start_time : time;
        variable end_time : time;
        variable processing_started : boolean := false;
    begin
        if rising_edge(clk) then
            if pixel_valid_in = '1' and not processing_started then
                start_time := now;
                processing_started := true;
                report "Edge detection processing started at " & time'image(start_time);
            end if;
            
            if processing_done = '1' and processing_started then
                end_time := now;
                report "Edge detection completed at " & time'image(end_time);
                report "Total processing time: " & time'image(end_time - start_time);
                report "Frames processed: " & integer'image(to_integer(unsigned(frame_count)));
                processing_started := false;
            end if;
        end if;
    end process;

end Behavioral;