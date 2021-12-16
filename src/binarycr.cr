require "http/web_socket"
require "json"
require "colorize"
require "tablo"

# Clear console
print "\33c\e[3J"

# Credentials
token  = "WFPdisB9aImNwPO"
app_id = "30681"

# Configuration
trade_amount  = 1
martingale    = 1
duration      = 1
contract_type = "DIGITEVEN"
track_profit  = 0
wanted_profit = 10
stop_loss     = 256

# Trade information
contract_id = 0
tick             = 0
balance          = ""
entry_tick_value = ""
entry_tick_time  = ""
exit_tick_value  = ""
exit_tick_time   = ""

# Contract
contract = {
  "buy"=> 1,
  "subscribe"=> 1,
  "price"=> trade_amount,
  "parameters"=> { "amount"=> trade_amount, "basis"=> "stake", "contract_type"=> contract_type, "currency"=> "USD", "duration"=> duration, "duration_unit"=> "t", "symbol"=> "R_100" }
}

# Accumulate results
results = [] of Array(Int32 | String)

module Binarycr
  VERSION = "0.1.0"

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

        # Print table
        table = Tablo::Table.new(results, connectors: Tablo::CONNECTORS_LIGHT_HEAVY) do |t|
          t.add_column("Contract ID") { |n| n[0] }
          t.add_column("Contract Type", width: 16) { |n| n[1] }
          t.add_column("Entry Price") { |n| n[2] }
          t.add_column("Exit Price") { |n| n[3] }
          t.add_column("Entry Time", width: 30) { |n| n[4] }
          t.add_column("Exit Time", width: 30) { |n| n[5] }
          t.add_column("Amount") { |n| n[6] }
          t.add_column("Profit",
          formatter: ->(x : Tablo::CellType) { "%.2f" % x },
          styler: ->(s : Tablo::CellType) { s.to_s.to_f > 0 ? "#{s.colorize(:green)}" : "#{s.colorize(:red)}" }) { |n| n[7] }
        end
        puts table
        puts "Total Balance: $#{balance}"
        puts "Total Profit:  $#{track_profit.format(decimal_places: 2)}".colorize(:blue)

        if (track_profit + stop_loss) > 0
          if track_profit > wanted_profit
            puts "Wanted profit reached at $#{track_profit.format(decimal_places: 2)}".colorize(:green)
            exit
          else

            if data["proposal_open_contract"]["status"] == "lost"              
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
              martingale = trade_amount
            end

            # Contract
            contract = {
              "buy"=> 1,
              "subscribe"=> 1,
              "price"=> martingale,
              "parameters"=> { "amount"=> martingale, "basis"=> "stake", "contract_type"=> contract_type, "currency"=> "USD", "duration"=> duration, "duration_unit"=> "t", "symbol"=> "R_100" }
            }
            
            # Buy contract
            ws.send(contract.to_json)
          end
        else
          puts "Stop loss reached at $#{track_profit.format(decimal_places: 2)}".colorize(:red)
          exit
        end

      end      

    end

  end

  # Start infinite loop
  ws.run
end
