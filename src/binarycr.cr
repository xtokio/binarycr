require "option_parser"
require "http/web_socket"
require "json"
require "colorize"
require "tablo"

# Credentials
token  = ""
app_id = ""

# Configuration
trade_amount  = 1
martingale    = 1
duration      = 1
contract_type = "DIGITEVEN"
track_profit  = 0
wanted_profit = 10
stop_loss     = 256

# Trade information
contract_id       = 0
tick              = 0
total_won         = 0
total_lost        = 0
consecutive_loses = 0
balance           = ""
entry_tick_value  = ""
entry_tick_time   = ""
exit_tick_value   = ""
exit_tick_time    = ""

# Contract
contract = {
  "buy"=> 1,
  "subscribe"=> 1,
  "price"=> trade_amount,
  "parameters"=> { 
    "amount"=> trade_amount, 
    "basis"=> "stake", 
    "contract_type"=> contract_type, 
    "currency"=> "USD", 
    "duration"=> duration, 
    "duration_unit"=> "t", 
    "symbol"=> "R_100" }
}

# Accumulate results
results = [] of Array(Int32 | String)

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

    parser.on "--trade_amount=AMOUNT", "Set Amount to start trading" do |input_amount|
      trade_amount = input_amount.to_i
      martingale = input_amount.to_i
    end

    parser.on "--wanted_profit=WANTED_PROFIT", "Set Wanted Profit" do |input_wanted_profit|
      wanted_profit = input_wanted_profit.to_i
    end

    parser.on "--stop_loss=STOP_LOSS", "Set Stop Loss to stop trading" do |input_stop_loss|
      stop_loss = input_stop_loss.to_i
    end
  end

  # Start program only if we have a Token and an App ID
  if !token.blank? && !app_id.blank?

    # Clear console
    print "\33c\e[3J"

    # Open websocket connection
    ws = HTTP::WebSocket.new(URI.parse("wss://ws.binaryws.com/websockets/v3?app_id=#{app_id}"))
    auth = { "authorize": token }
    ws.send(auth.to_json)

    # Set callback
    ws.on_message do |msg|
      data = JSON.parse(msg)

      case data["msg_type"]
      when "authorize"
        ws.send({ "ticks": "R_100" }.to_json)
        ws.send({ "balance": 1, "subscribe": 1 }.to_json)

        # Buy contract
        contract = {
          "buy"=> 1,
          "subscribe"=> 1,
          "price"=> trade_amount,
          "parameters"=> { 
            "amount"=> trade_amount, 
            "basis"=> "stake", 
            "contract_type"=> contract_type, 
            "currency"=> "USD", 
            "duration"=> duration, 
            "duration_unit"=> "t", 
            "symbol"=> "R_100" }
        }
        ws.send(contract.to_json)

      when "tick"
        tick = data["tick"]["quote"]
      when "balance"
        balance = data["balance"]["balance"]
      when "buy"
        contract_id = data["buy"]["contract_id"].to_s

        # puts "Buy was successful #{Time.unix(data["buy"]["purchase_time"].to_s.to_i).to_local}"
        # puts "Contract ID #{data["buy"]["contract_id"]}"
      when "proposal_open_contract"
        if data["proposal_open_contract"]["is_sold"].to_s.to_i == 1

          entry_tick_value = data["proposal_open_contract"]["entry_tick_display_value"].to_s
          entry_tick_time  = Time.unix(data["proposal_open_contract"]["entry_tick_time"].to_s.to_i).to_local
          exit_tick_value  = data["proposal_open_contract"]["exit_tick_display_value"].to_s
          exit_tick_time   = Time.unix(data["proposal_open_contract"]["exit_tick_time"].to_s.to_i).to_local
          martingale       = data["proposal_open_contract"]["buy_price"].to_s.to_i
          profit           = data["proposal_open_contract"]["profit"].to_s.to_f.format(decimal_places: 2)

          track_profit = track_profit + profit.to_f
          buy_price = martingale

          # Clear console
          print "\33c\e[3J"

          # Accumulate results
          results.push([contract_id,contract_type,entry_tick_value,exit_tick_value,entry_tick_time.to_s,exit_tick_time.to_s,buy_price.to_s,profit.to_s])
          
          if data["proposal_open_contract"]["status"] == "lost"
            total_lost = total_lost + 1
            consecutive_loses = consecutive_loses + 1

            # Switch Contract Type
            if contract_type == "DIGITEVEN"
              contract_type = "DIGITODD"
            else
              contract_type = "DIGITEVEN"
            end
            # Apply Martingale
            martingale = martingale * 2
          end
  
          if data["proposal_open_contract"]["status"] == "won"
            total_won = total_won + 1
            consecutive_loses = 0
            martingale = trade_amount
          end

          # Print table
          table = Tablo::Table.new(results, connectors: Tablo::CONNECTORS_SINGLE_ROUNDED) do |t|
            t.add_column("Contract ID") { |n| n[0] }
            t.add_column("Contract Type", width: 16) { |n| n[1] }
            t.add_column("Entry Price") { |n| n[2] }
            t.add_column("Exit Price") { |n| n[3] }
            t.add_column("Entry Time", width: 30) { |n| n[4] }
            t.add_column("Exit Time", width: 30) { |n| n[5] }
            t.add_column("Amount",
              styler: ->(s : Tablo::CellType) { s.to_s.to_f >= (trade_amount*2*2) ? "#{s.colorize(:red)}" : "#{s.colorize(:white)}" }) { |n| n[6] }
            t.add_column("Profit",
              formatter: ->(x : Tablo::CellType) { "%.2f" % x },
              styler: ->(s : Tablo::CellType) { s.to_s.to_f > 0 ? "#{s.colorize(:green)}" : "#{s.colorize(:red)}" }) { |n| n[7] }
          end
          # puts table
          table.each_with_index do |row, i|
            puts table.horizontal_rule(Tablo::TLine::Mid) if i > 0 && table.style =~ /ML/i
            puts row
          end
          puts table.horizontal_rule(Tablo::TLine::Bot) if table.style =~ /BL/i

          # Totals table
          balance_display = "$#{balance}"

          results_totals = [] of Array(String)
          results_totals.push([total_won.to_s,total_lost.to_s,balance_display,track_profit.to_s])
          table_totals = Tablo::Table.new(results_totals,connectors: Tablo::CONNECTORS_SINGLE_ROUNDED) do |t|
            t.add_column("Won",
              styler: ->(s : Tablo::CellType) { "#{s.colorize(:green)}" }) {|n| n[0] }
            t.add_column("Lost",
              styler: ->(s : Tablo::CellType) { "#{s.colorize(:red)}" }) {|n| n[1] }
            t.add_column("Balance",
              styler: ->(s : Tablo::CellType) { "#{s.colorize(:green)}" }) {|n| n[2] }
            t.add_column("Profit",
              formatter: ->(x : Tablo::CellType) { "%.2f" % x },
              styler: ->(s : Tablo::CellType) { s.to_s.to_f > 0 ? "#{s.colorize(:green)}" : "#{s.colorize(:red)}" }) {|n| n[3] }
          end
          table_totals.each_with_index do |row, i|
            puts table_totals.horizontal_rule(Tablo::TLine::Mid) if i > 0 && table_totals.style =~ /ML/i
            puts row
          end
          puts table_totals.horizontal_rule(Tablo::TLine::Bot) if table_totals.style =~ /BL/i
          puts "\n"
          
          if (track_profit + stop_loss) > 0
            if track_profit > wanted_profit
              puts "Wanted profit reached.".colorize(:green)
              puts "\n"

              exit
            else              
              # Contract
              contract = {
                "buy"=> 1,
                "subscribe"=> 1,
                "price"=> martingale,
                "parameters"=> { 
                  "amount"=> martingale, 
                  "basis"=> "stake", 
                  "contract_type"=> contract_type, 
                  "currency"=> "USD", 
                  "duration"=> duration, 
                  "duration_unit"=> "t", 
                  "symbol"=> "R_100" }
              }
              
              # Buy contract
              ws.send(contract.to_json)
            end
          else
            puts "Stop loss reached at $#{track_profit.format(decimal_places: 2)}".colorize(:red)
            puts "\n"

            exit
          end

        end      

      end

    end

    # Start infinite loop
    ws.run
  
  else
    puts "To start trading you need your Token and App ID."
  end
end