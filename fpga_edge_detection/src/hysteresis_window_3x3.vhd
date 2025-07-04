library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity hysteresis_window_3x3 is
    generic (
        IMAGE_WIDTH : integer := 640;
        DATA_WIDTH  : integer := 8
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        enable      : in  std_logic;
        pixel_in    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data_valid  : in  std_logic;
        h11, h12, h13 : out std_logic_vector(DATA_WIDTH-1 downto 0);
        h21, h22, h23 : out std_logic_vector(DATA_WIDTH-1 downto 0);
        h31, h32, h33 : out std_logic_vector(DATA_WIDTH-1 downto 0);
        window_valid  : out std_logic
    );
end hysteresis_window_3x3;

architecture Behavioral of hysteresis_window_3x3 is

    -- Line buffers for 2 lines of magnitude data
    type line_buffer_type is array (0 to IMAGE_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal line1_buffer : line_buffer_type := (others => (others => '0'));
    signal line2_buffer : line_buffer_type := (others => (others => '0'));

    -- 3x3 shift registers
    signal shift_line1 : std_logic_vector(3*DATA_WIDTH-1 downto 0) := (others => '0');
    signal shift_line2 : std_logic_vector(3*DATA_WIDTH-1 downto 0) := (others => '0');
    signal shift_line3 : std_logic_vector(3*DATA_WIDTH-1 downto 0) := (others => '0');

    -- Address and control signals
    signal write_addr : integer range 0 to IMAGE_WIDTH-1 := 0;
    signal pixel_count : integer range 0 to IMAGE_WIDTH*3 := 0;
    signal window_ready : std_logic := '0';
    signal data_valid_reg : std_logic := '0';

begin

    -- Line buffer management
    line_buffer_proc : process(clk, reset)
    begin
        if reset = '1' then
            write_addr <= 0;
            pixel_count <= 0;
            window_ready <= '0';
            line1_buffer <= (others => (others => '0'));
            line2_buffer <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if enable = '1' and data_valid = '1' then
                -- Shift line buffers
                line1_buffer(write_addr) <= line2_buffer(write_addr);
                line2_buffer(write_addr) <= pixel_in;
                
                -- Update write address
                if write_addr = IMAGE_WIDTH-1 then
                    write_addr <= 0;
                else
                    write_addr <= write_addr + 1;
                end if;
                
                -- Count pixels to determine when window is ready
                if pixel_count < IMAGE_WIDTH*2 + 2 then
                    pixel_count <= pixel_count + 1;
                else
                    window_ready <= '1';
                end if;
            end if;
        end if;
    end process;

    -- Generate 3x3 windows
    window_gen_proc : process(clk, reset)
        variable read_addr : integer range 0 to IMAGE_WIDTH-1;
    begin
        if reset = '1' then
            shift_line1 <= (others => '0');
            shift_line2 <= (others => '0');
            shift_line3 <= (others => '0');
            data_valid_reg <= '0';
        elsif rising_edge(clk) then
            if enable = '1' and data_valid = '1' then
                -- Calculate read address (2 pixels behind write address)
                if write_addr >= 2 then
                    read_addr := write_addr - 2;
                else
                    read_addr := write_addr + IMAGE_WIDTH - 2;
                end if;
                
                -- Shift 3x3 windows
                shift_line1 <= shift_line1(2*DATA_WIDTH-1 downto 0) & line1_buffer(read_addr);
                shift_line2 <= shift_line2(2*DATA_WIDTH-1 downto 0) & line2_buffer(read_addr);
                shift_line3 <= shift_line3(2*DATA_WIDTH-1 downto 0) & pixel_in;
                
                -- Output is valid when we have enough data
                data_valid_reg <= window_ready;
            else
                data_valid_reg <= '0';
            end if;
        end if;
    end process;

    -- Extract 3x3 window
    -- Window layout:
    -- h11 h12 h13
    -- h21 h22 h23  
    -- h31 h32 h33
    
    h11 <= shift_line1(3*DATA_WIDTH-1 downto 2*DATA_WIDTH);
    h12 <= shift_line1(2*DATA_WIDTH-1 downto 1*DATA_WIDTH);
    h13 <= shift_line1(1*DATA_WIDTH-1 downto 0*DATA_WIDTH);
    
    h21 <= shift_line2(3*DATA_WIDTH-1 downto 2*DATA_WIDTH);
    h22 <= shift_line2(2*DATA_WIDTH-1 downto 1*DATA_WIDTH);
    h23 <= shift_line2(1*DATA_WIDTH-1 downto 0*DATA_WIDTH);
    
    h31 <= shift_line3(3*DATA_WIDTH-1 downto 2*DATA_WIDTH);
    h32 <= shift_line3(2*DATA_WIDTH-1 downto 1*DATA_WIDTH);
    h33 <= shift_line3(1*DATA_WIDTH-1 downto 0*DATA_WIDTH);
    
    window_valid <= data_valid_reg;

end Behavioral;