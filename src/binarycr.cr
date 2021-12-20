require "option_parser"
require "http/web_socket"
require "json"
require "colorize"
require "tablo"

require "./balance.cr"
require "./trade.cr"
require "./store.cr"

# Credentials
token  = ""
app_id = ""
show_balance = false
alternate    = true

# Configuration
contract_type = "DIGITEVEN"
trade_amount  = 1
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

    parser.on "--trade_amount=AMOUNT", "Set Amount to start trading" do |input_amount|
      trade_amount = input_amount.to_f.format(decimal_places: 2)
      martingale = input_amount.to_f.format(decimal_places: 2)
    end

    parser.on "--wanted_profit=WANTED_PROFIT", "Set Wanted Profit" do |input_wanted_profit|
      wanted_profit = input_wanted_profit.to_i
    end

    parser.on "--stop_loss=STOP_LOSS", "Set Stop Loss to stop trading" do |input_stop_loss|
      stop_loss = input_stop_loss.to_i
    end

    parser.on "--contract=CONTRACT", "Set contract type to even or odd" do |input_contract_type|
      if input_contract_type.upcase == "EVEN"
        contract_type = "DIGITEVEN"
      else
        contract_type = "DIGITODD"
      end
      alternate = false
    end
  end

  # Start Trading only if we have a Token and an App ID
  if !token.blank? && !app_id.blank?

    # Show balance option
    if show_balance
      Balance.new(token,app_id)    
    else
      Trade.new(token,app_id,trade_amount,wanted_profit,stop_loss,contract_type,alternate)
    end
  
  else
    puts "To connect to your binary.com trading account you need your Token and App ID.".colorize(:red)
  end
end