library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity hysteresis_threshold is
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
end hysteresis_threshold;

architecture Behavioral of hysteresis_threshold is

    -- 3x3 window for edge linking
    component hysteresis_window_3x3 is
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
    end component;

    -- 3x3 window signals
    signal h11, h12, h13 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal h21, h22, h23 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal h31, h32, h33 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal window_valid : std_logic;

    -- Intermediate classification signals
    signal center_mag : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal strong_edge : std_logic;
    signal weak_edge : std_logic;
    signal connected_to_strong : std_logic;
    
    -- Edge classification states
    type edge_state_type is (BACKGROUND, WEAK_EDGE, STRONG_EDGE);
    signal edge_state : edge_state_type;
    
    -- Output registers
    signal hyst_result : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal hyst_valid_out : std_logic;

begin

    -- 3x3 window for hysteresis processing
    hyst_window : hysteresis_window_3x3
        generic map (
            IMAGE_WIDTH => IMAGE_WIDTH,
            DATA_WIDTH  => DATA_WIDTH
        )
        port map (
            clk         => clk,
            reset       => reset,
            enable      => enable,
            pixel_in    => mag_in,
            data_valid  => data_valid,
            h11 => h11, h12 => h12, h13 => h13,
            h21 => h21, h22 => h22, h23 => h23,
            h31 => h31, h32 => h32, h33 => h33,
            window_valid => window_valid
        );

    center_mag <= h22; -- Center pixel magnitude

    -- Classify center pixel
    edge_classification : process(clk, reset)
    begin
        if reset = '1' then
            strong_edge <= '0';
            weak_edge <= '0';
            edge_state <= BACKGROUND;
        elsif rising_edge(clk) then
            if enable = '1' and window_valid = '1' then
                -- Strong edge: above high threshold
                if unsigned(center_mag) >= unsigned(high_th) then
                    strong_edge <= '1';
                    weak_edge <= '0';
                    edge_state <= STRONG_EDGE;
                -- Weak edge: between low and high thresholds
                elsif unsigned(center_mag) >= unsigned(low_th) and unsigned(center_mag) < unsigned(high_th) then
                    strong_edge <= '0';
                    weak_edge <= '1';
                    edge_state <= WEAK_EDGE;
                -- Background: below low threshold
                else
                    strong_edge <= '0';
                    weak_edge <= '0';
                    edge_state <= BACKGROUND;
                end if;
            else
                strong_edge <= '0';
                weak_edge <= '0';
                edge_state <= BACKGROUND;
            end if;
        end if;
    end process;

    -- Check if weak edge is connected to strong edge
    edge_connectivity : process(clk, reset)
    begin
        if reset = '1' then
            connected_to_strong <= '0';
        elsif rising_edge(clk) then
            if enable = '1' and window_valid = '1' then
                -- Check if any neighbor is a strong edge (above high threshold)
                if (unsigned(h11) >= unsigned(high_th)) or
                   (unsigned(h12) >= unsigned(high_th)) or
                   (unsigned(h13) >= unsigned(high_th)) or
                   (unsigned(h21) >= unsigned(high_th)) or
                   (unsigned(h23) >= unsigned(high_th)) or
                   (unsigned(h31) >= unsigned(high_th)) or
                   (unsigned(h32) >= unsigned(high_th)) or
                   (unsigned(h33) >= unsigned(high_th)) then
                    connected_to_strong <= '1';
                else
                    connected_to_strong <= '0';
                end if;
            else
                connected_to_strong <= '0';
            end if;
        end if;
    end process;

    -- Hysteresis decision logic
    hysteresis_decision : process(clk, reset)
    begin
        if reset = '1' then
            hyst_result <= (others => '0');
            hyst_valid_out <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                hyst_valid_out <= window_valid;
                
                if window_valid = '1' then
                    case edge_state is
                        when STRONG_EDGE =>
                            -- Strong edges are always kept
                            hyst_result <= (others => '1'); -- White pixel (edge)
                            
                        when WEAK_EDGE =>
                            -- Weak edges are kept only if connected to strong edges
                            if connected_to_strong = '1' then
                                hyst_result <= (others => '1'); -- White pixel (edge)
                            else
                                hyst_result <= (others => '0'); -- Black pixel (suppressed)
                            end if;
                            
                        when BACKGROUND =>
                            -- Background pixels are always suppressed
                            hyst_result <= (others => '0'); -- Black pixel (no edge)
                            
                        when others =>
                            hyst_result <= (others => '0');
                    end case;
                else
                    hyst_result <= (others => '0');
                end if;
            else
                hyst_valid_out <= '0';
            end if;
        end if;
    end process;

    -- Output assignments
    edge_out <= hyst_result;
    hyst_valid <= hyst_valid_out;

end Behavioral;