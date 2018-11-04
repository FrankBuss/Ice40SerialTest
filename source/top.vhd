library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ice40up;
use ice40up.components.all;

entity top is
  port(
    clk: in std_logic;
    rxd: out std_logic;
    txd: in std_logic;
    led_blue: out std_logic;
    led_green: out std_logic;
    led_red: out std_logic);
end entity top;

architecture rtl of top is
  constant system_speed: natural := 12e6;
  constant baudrate: natural := 115200;

  signal rs232_receiver_ack: std_logic := '0';
  signal rs232_receiver_dat: unsigned(7 downto 0) := (others => '0');
  signal rs232_receiver_stb: std_logic := '0';

  signal rs232_sender_ack: std_logic := '0';
  signal rs232_sender_dat: unsigned(7 downto 0);
  signal rs232_sender_stb: std_logic := '0';

  signal led_latch_blue: std_logic := '0';
  signal led_latch_green: std_logic := '0';
  signal led_latch_red: std_logic := '0';
  signal counter: natural range 0 to (system_speed / 2) := 0;

  type state_type is (
    wait_for_command,
    wait_for_strobe,
    send_data,
    wait_for_data_send_start);

  signal state: state_type := wait_for_command;
  
begin

  my_rgb: RGB
    generic map (RGB0_CURRENT => "0b000001" ,RGB1_CURRENT => "0b000001" ,RGB2_CURRENT => "0b000001" )
    port map(
      CURREN => '1',
      RGB0PWM => led_latch_blue,
      RGB1PWM => led_latch_green,
      RGB2PWM => led_latch_red,
      RGBLEDEN => '1', 
      RGB0 => led_blue,
      RGB1 => led_green,
      RGB2 => led_red);
	
  sender: entity rs232_sender
    generic map(system_speed, baudrate)
    port map(
      ack_o => rs232_sender_ack,
      clk_i => clk,
      dat_i => rs232_sender_dat,
      rst_i => '0',
      stb_i => rs232_sender_stb,
      tx => rxd);

  receiver: entity rs232_receiver
    generic map(system_speed, baudrate)
    port map(
      ack_i => rs232_receiver_ack,
      clk_i => clk,
      dat_o => rs232_receiver_dat,
      rst_i => '0',
      stb_o => rs232_receiver_stb,
      rx => txd);

  process(clk)
  begin
    if rising_edge(clk) then
      case state is
        -- read char from RS232 port
        when wait_for_command =>
          if rs232_receiver_stb = '1' then
            state <= wait_for_strobe;
            rs232_receiver_ack <= '1';
          end if;
        when wait_for_strobe =>
          if rs232_receiver_stb <= '0' then
            rs232_receiver_ack <= '0';
            state <= send_data;
          end if;

        -- send echo to RS232 port
        when send_data =>
          if rs232_sender_ack = '0' then
            rs232_sender_stb <= '1';
            rs232_sender_dat <= rs232_receiver_dat + 1;
            rs232_sender_stb <= '1';
            state <= wait_for_data_send_start;
          end if;
        when wait_for_data_send_start =>
          if rs232_sender_ack = '1' then
            rs232_sender_stb <= '0';
            state <= wait_for_command;
            case rs232_receiver_dat is
              when x"30" =>  -- "0": LED off
                led_latch_blue <= '0';
              when x"31" =>  -- "1": LED on
                led_latch_blue <= '1';
              when others =>
            end case;
          end if;
      end case;
  
      -- green LED blinks with 1 Hz
      if counter = 0 then
        led_latch_green <= not led_latch_green;
        counter <= system_speed / 2;
      else
        counter <= counter - 1;
      end if;
    end if;
  end process;
  
end architecture rtl;
