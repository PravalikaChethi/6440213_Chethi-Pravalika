library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity line_buffer is
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
end line_buffer;

architecture Behavioral of line_buffer is
    
    -- Line buffer memory
    type line_buffer_type is array (0 to IMAGE_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal line1_buffer : line_buffer_type := (others => (others => '0'));
    signal line2_buffer : line_buffer_type := (others => (others => '0'));
    
    -- Shift registers for 3x3 window
    signal line1_shift : std_logic_vector(2*DATA_WIDTH-1 downto 0) := (others => '0');
    signal line2_shift : std_logic_vector(2*DATA_WIDTH-1 downto 0) := (others => '0');
    signal line3_shift : std_logic_vector(2*DATA_WIDTH-1 downto 0) := (others => '0');
    
    -- Address counters
    signal write_addr : integer range 0 to IMAGE_WIDTH-1 := 0;
    signal read_addr  : integer range 0 to IMAGE_WIDTH-1 := 0;
    signal col_count  : integer range 0 to IMAGE_WIDTH-1 := 0;
    signal row_count  : integer range 0 to IMAGE_WIDTH*3 := 0;
    
    signal data_valid_int : std_logic := '0';
    signal line_buffer_full : std_logic := '0';
    
begin

    -- Write process: Store incoming pixels in line buffers
    write_process : process(clk, reset)
    begin
        if reset = '1' then
            write_addr <= 0;
            col_count <= 0;
            row_count <= 0;
            line_buffer_full <= '0';
            line1_buffer <= (others => (others => '0'));
            line2_buffer <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if enable = '1' and pixel_valid = '1' then
                -- Shift line buffers down
                line1_buffer(write_addr) <= line2_buffer(write_addr);
                line2_buffer(write_addr) <= pixel_in;
                
                -- Update write address
                if write_addr = IMAGE_WIDTH-1 then
                    write_addr <= 0;
                    if row_count < IMAGE_WIDTH*2 then
                        row_count <= row_count + IMAGE_WIDTH;
                    else
                        line_buffer_full <= '1';
                    end if;
                else
                    write_addr <= write_addr + 1;
                end if;
                
                -- Update column count
                if col_count = IMAGE_WIDTH-1 then
                    col_count <= 0;
                else
                    col_count <= col_count + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Read process: Generate 3x3 windows
    read_process : process(clk, reset)
    begin
        if reset = '1' then
            read_addr <= 0;
            line1_shift <= (others => '0');
            line2_shift <= (others => '0');
            line3_shift <= (others => '0');
            data_valid_int <= '0';
        elsif rising_edge(clk) then
            if enable = '1' and pixel_valid = '1' then
                -- Shift the 3-pixel windows
                line1_shift <= line1_shift(DATA_WIDTH-1 downto 0) & line1_buffer(read_addr);
                line2_shift <= line2_shift(DATA_WIDTH-1 downto 0) & line2_buffer(read_addr);
                line3_shift <= line3_shift(DATA_WIDTH-1 downto 0) & pixel_in;
                
                -- Update read address
                if read_addr = IMAGE_WIDTH-1 then
                    read_addr <= 0;
                else
                    read_addr <= read_addr + 1;
                end if;
                
                -- Data is valid when we have at least 2 full lines and 2 pixels in current line
                if line_buffer_full = '1' and col_count >= 2 then
                    data_valid_int <= '1';
                else
                    data_valid_int <= '0';
                end if;
            else
                data_valid_int <= '0';
            end if;
        end if;
    end process;
    
    -- Output the center pixels of each line for 3x3 convolution
    line1_out <= line1_shift(DATA_WIDTH+DATA_WIDTH/2-1 downto DATA_WIDTH/2) when data_valid_int = '1' else (others => '0');
    line2_out <= line2_shift(DATA_WIDTH+DATA_WIDTH/2-1 downto DATA_WIDTH/2) when data_valid_int = '1' else (others => '0');
    line3_out <= line3_shift(DATA_WIDTH+DATA_WIDTH/2-1 downto DATA_WIDTH/2) when data_valid_int = '1' else (others => '0');
    
    data_valid <= data_valid_int;
    
end Behavioral;