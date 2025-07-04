library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity magnitude_window_3x3 is
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
end magnitude_window_3x3;

architecture Behavioral of magnitude_window_3x3 is

    -- Line buffers for 3 lines of magnitude data
    type line_buffer_type is array (0 to IMAGE_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal line1_mag_buffer : line_buffer_type := (others => (others => '0'));
    signal line2_mag_buffer : line_buffer_type := (others => (others => '0'));
    signal line1_dir_buffer : line_buffer_type := (others => (others => '0'));
    signal line2_dir_buffer : line_buffer_type := (others => (others => '0'));

    -- 3x3 shift registers for magnitude
    signal mag_shift_line1 : std_logic_vector(3*DATA_WIDTH-1 downto 0) := (others => '0');
    signal mag_shift_line2 : std_logic_vector(3*DATA_WIDTH-1 downto 0) := (others => '0');
    signal mag_shift_line3 : std_logic_vector(3*DATA_WIDTH-1 downto 0) := (others => '0');
    
    -- Direction shift register for center pixel
    signal dir_shift_line2 : std_logic_vector(3*DATA_WIDTH-1 downto 0) := (others => '0');

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
            line1_mag_buffer <= (others => (others => '0'));
            line2_mag_buffer <= (others => (others => '0'));
            line1_dir_buffer <= (others => (others => '0'));
            line2_dir_buffer <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if enable = '1' and data_valid = '1' then
                -- Shift line buffers
                line1_mag_buffer(write_addr) <= line2_mag_buffer(write_addr);
                line2_mag_buffer(write_addr) <= mag_in;
                line1_dir_buffer(write_addr) <= line2_dir_buffer(write_addr);
                line2_dir_buffer(write_addr) <= dir_in;
                
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
            mag_shift_line1 <= (others => '0');
            mag_shift_line2 <= (others => '0');
            mag_shift_line3 <= (others => '0');
            dir_shift_line2 <= (others => '0');
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
                mag_shift_line1 <= mag_shift_line1(2*DATA_WIDTH-1 downto 0) & line1_mag_buffer(read_addr);
                mag_shift_line2 <= mag_shift_line2(2*DATA_WIDTH-1 downto 0) & line2_mag_buffer(read_addr);
                mag_shift_line3 <= mag_shift_line3(2*DATA_WIDTH-1 downto 0) & mag_in;
                
                -- Shift direction for center pixel
                dir_shift_line2 <= dir_shift_line2(2*DATA_WIDTH-1 downto 0) & line2_dir_buffer(read_addr);
                
                -- Output is valid when we have enough data
                data_valid_reg <= window_ready;
            else
                data_valid_reg <= '0';
            end if;
        end if;
    end process;

    -- Extract 3x3 magnitude window
    -- Window layout:
    -- m11 m12 m13
    -- m21 m22 m23  
    -- m31 m32 m33
    
    m11 <= mag_shift_line1(3*DATA_WIDTH-1 downto 2*DATA_WIDTH);
    m12 <= mag_shift_line1(2*DATA_WIDTH-1 downto 1*DATA_WIDTH);
    m13 <= mag_shift_line1(1*DATA_WIDTH-1 downto 0*DATA_WIDTH);
    
    m21 <= mag_shift_line2(3*DATA_WIDTH-1 downto 2*DATA_WIDTH);
    m22 <= mag_shift_line2(2*DATA_WIDTH-1 downto 1*DATA_WIDTH);
    m23 <= mag_shift_line2(1*DATA_WIDTH-1 downto 0*DATA_WIDTH);
    
    m31 <= mag_shift_line3(3*DATA_WIDTH-1 downto 2*DATA_WIDTH);
    m32 <= mag_shift_line3(2*DATA_WIDTH-1 downto 1*DATA_WIDTH);
    m33 <= mag_shift_line3(1*DATA_WIDTH-1 downto 0*DATA_WIDTH);
    
    -- Center direction
    center_dir <= dir_shift_line2(2*DATA_WIDTH-1 downto 1*DATA_WIDTH);
    
    window_valid <= data_valid_reg;

end Behavioral;