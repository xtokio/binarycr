require "option_parser"
require "http/web_socket"
require "json"
require "colorize"
require "tablo"

require "./balance.cr"
require "./tick.cr"
require "./trade.cr"
require "./store.cr"

# Credentials
token  = ""
app_id = ""
show_balance = false
show_ticks   = false
num_ticks    = 0
alternate    = true

# Configuration
contract_type = "DIGITEVEN"
trade_amount  = 1
duration      = 1
wanted_profit = 10
stop_loss     = 256

module Binarycr
  VERSION = "0.1.0"

  # Parameters
  OptionParser.parse do |parser|
    parser.banner = "Binary trading bot"

    parser.on "--version", "Show version" do
      puts "version 1.0"
      exit
    end
    parser.on "--help", "Show help" do
      puts parser
      exit
    end

    parser.on "--token=TOKEN", "Set token from binary.com" do |input_token|
      token = input_token
    end

    parser.on "--application=APP", "Set Application ID from binary.com" do |input_app|
      app_id = input_app
    end

    parser.on "--balance", "Show current balance from binary.com" do
      show_balance = true
    end

    parser.on "--ticks=TICKS", "Show first 100 ticks from binary.com" do |input_ticks|
      show_ticks = true
      num_ticks = input_ticks.to_i
    end

    parser.on "--trade_amount=AMOUNT", "Set Amount to start trading" do |input_amount|
      trade_amount = input_amount.to_f.format(decimal_places: 2)
      martingale = input_amount.to_f.format(decimal_places: 2)
    end

    parser.on "--duration=TICK_DURATION", "Set Tick Duration" do |input_tick_duration|
      duration = input_tick_duration.to_i
    end

    parser.on "--wanted_profit=WANTED_PROFIT", "Set Wanted Profit" do |input_wanted_profit|
      wanted_profit = input_wanted_profit.to_i
    end

    parser.on "--stop_loss=STOP_LOSS", "Set Stop Loss to stop trading, number of consecutive losses" do |input_stop_loss|
      stop_loss = input_stop_loss.to_i
    end

    parser.on "--contract=CONTRACT", "Set contract type to even or odd" do |input_contract_type|
      if input_contract_type.upcase == "BOTH"
        contract_type = "DIGITEVEN"
      end
      if input_contract_type.upcase == "EVEN"
        contract_type = "DIGITEVEN"
        alternate = false
      end
      if input_contract_type.upcase == "ODD"
        contract_type = "DIGITODD"
        alternate = false
      end
    end
  end

  # Start Trading only if we have a Token and an App ID
  if !token.blank? && !app_id.blank?

    # Show balance option
    if show_balance
      Balance.new(token,app_id)    
    elsif show_ticks
      Tick.new(token,app_id,num_ticks)
    else
      trade = Trade.new(token,app_id,trade_amount,duration,wanted_profit,stop_loss,contract_type,alternate)
      status = trade.status
      sleep 5
      
      while status == "won"
        trade = Trade.new(token,app_id,trade_amount,duration,wanted_profit,stop_loss,contract_type,alternate)
        status = trade.status
        sleep 5
      end

    end
  
  else
    puts "To connect to your binary.com trading account you need your Token and App ID.".colorize(:red)
  end
end