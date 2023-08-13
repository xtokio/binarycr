class Trade
  property token : String, app_id : String, status : String

  def initialize(token,app_id,trade_amount,duration,wanted_profit,stop_loss,contract_type,alternate,show_notification)
    @token = token
    @app_id = app_id
    @status = ""
    
    # Clear console
    print "\33c\e[3J"

    auth = { "authorize": token }

    # Configuration
    martingale    = trade_amount

    # Trade information
    tick              = 0
    total_won         = 0
    total_lost        = 0
    consecutive_loses = 0
    track_profit  = 0
    balance           = ""
    contract_id       = ""
    entry_tick_value  = ""
    entry_tick_time   = ""
    exit_tick_value   = ""
    exit_tick_time    = ""

    # Accumulate results
    results = [] of Array(String)

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

    # Open websocket connection
    ws = HTTP::WebSocket.new(URI.parse("wss://ws.binaryws.com/websockets/v3?app_id=#{app_id}"))
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
        ws.send(contract.to_json)

      when "tick"
        tick = data["tick"]["quote"]
      when "balance"
        balance = data["balance"]["balance"]
      when "buy"
        if data["buy"]? != nil
          contract_id = data["buy"]["contract_id"].to_s
        else
          # Websocket was closed
          Store.file("trade_history.txt","Websocket closed.")

          balance_display = "$#{balance}"
          websocket_closed_totals = [] of Array(String)
          websocket_closed_totals.push([balance_display,track_profit.to_s.to_f.format(decimal_places: 2).gsub(",","")])
          websocket_closed_file = Tablo::Table.new(websocket_closed_totals,connectors: Tablo::CONNECTORS_SINGLE_ROUNDED) do |t|
            t.add_column("Balance") {|n| n[0] }
            t.add_column("Profit") {|n| n[1] }
          end
          Store.file("trade_history.txt",websocket_closed_file)

          @status = "websocket_closed"
          puts "Websocket closed.".colorize(:red)
          ws.close
          exit
        end
      when "proposal_open_contract"
        if data["proposal_open_contract"]["is_sold"].to_s.to_i == 1

          entry_tick_value = data["proposal_open_contract"]["entry_tick_display_value"].to_s
          entry_tick_time  = Time.unix(data["proposal_open_contract"]["entry_tick_time"].to_s.to_i).to_local.to_s
          exit_tick_value  = data["proposal_open_contract"]["exit_tick_display_value"].to_s
          exit_tick_time   = Time.unix(data["proposal_open_contract"]["exit_tick_time"].to_s.to_i).to_local.to_s
          buy_price        = data["proposal_open_contract"]["buy_price"].to_s
          profit           = data["proposal_open_contract"]["profit"].to_s.to_f.format(decimal_places: 2)

          track_profit = track_profit + profit.to_f
          martingale = buy_price

          # Accumulate results
          results.push([contract_id,contract_type,entry_tick_value,exit_tick_value,entry_tick_time,exit_tick_time,buy_price,profit.gsub(",","")])
          
          if data["proposal_open_contract"]["status"] == "lost"
            total_lost = total_lost + 1
            consecutive_loses = consecutive_loses + 1

            # Switch Contract Type if alternate is true
            if alternate
              contract_type = invert_contract_type(contract_type)             
            end

            # Force contract type to Invert
            if consecutive_loses == 3 || consecutive_loses == 5
              contract_type = invert_contract_type(contract_type)
            end

            # Apply Martingale
            martingale = (martingale.to_f * 2).to_s
          end
  
          if data["proposal_open_contract"]["status"] == "won"
            total_won = total_won + 1
            consecutive_loses = 0
            martingale = trade_amount

            if !alternate
              contract_type = "DIGITEVEN"
            end
          end

          # Clear console
          print "\33c\e[3J"

          # Print table
          table = Tablo::Table.new(results, connectors: Tablo::CONNECTORS_SINGLE_ROUNDED) do |t|
            t.add_column("Contract ID") { |n| n[0] }
            t.add_column("Contract Type", width: 16) { |n| n[1] }
            t.add_column("Entry Price") { |n| n[2] }
            t.add_column("Exit Price") { |n| n[3] }
            t.add_column("Entry Time", width: 30) { |n| n[4] }
            t.add_column("Exit Time", width: 30) { |n| n[5] }
            t.add_column("Amount",
              styler: ->(s : Tablo::CellType) { s.to_s.to_f >= (trade_amount.to_f*2*2) ? "#{s.colorize(:red)}" : "#{s.colorize(:white)}" }) { |n| n[6] }
            t.add_column("Profit",
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
          results_totals.push([balance_display,total_won.to_s,total_lost.to_s,track_profit.to_s.to_f.format(decimal_places: 2).gsub(",","")])
          table_totals = Tablo::Table.new(results_totals,connectors: Tablo::CONNECTORS_SINGLE_ROUNDED) do |t|
            t.add_column("Balance",
              styler: ->(s : Tablo::CellType) { "#{s.colorize(:green)}" }) {|n| n[0] }
            t.add_column("Won",
              styler: ->(s : Tablo::CellType) { "#{s.colorize(:green)}" }) {|n| n[1] }
            t.add_column("Lost",
              styler: ->(s : Tablo::CellType) { "#{s.colorize(:red)}" }) {|n| n[2] }
            t.add_column("Profit",
              styler: ->(s : Tablo::CellType) { s.to_s.to_f > 0 ? "#{s.colorize(:green)}" : "#{s.colorize(:red)}" }) {|n| n[3] }
          end
          table_totals.each_with_index do |row, i|
            puts table_totals.horizontal_rule(Tablo::TLine::Mid) if i > 0 && table_totals.style =~ /ML/i
            puts row
          end
          puts table_totals.horizontal_rule(Tablo::TLine::Bot) if table_totals.style =~ /BL/i
          puts "\n"
          
          if consecutive_loses < stop_loss
            if track_profit > wanted_profit
              if show_notification
                display_notification("BinaryCR","Notification","Wanted profit reached at $ #{track_profit.format(decimal_places: 2)}","won")
              end

              puts "Wanted profit reached at $#{track_profit.format(decimal_places: 2)}".colorize(:green)
              puts "\n"

              # Save results to a file
              table_file = Tablo::Table.new(results, connectors: Tablo::CONNECTORS_SINGLE_ROUNDED) do |t|
                t.add_column("Contract ID") { |n| n[0] }
                t.add_column("Contract Type", width: 16) { |n| n[1] }
                t.add_column("Entry Price") { |n| n[2] }
                t.add_column("Exit Price") { |n| n[3] }
                t.add_column("Entry Time", width: 30) { |n| n[4] }
                t.add_column("Exit Time", width: 30) { |n| n[5] }
                t.add_column("Amount") { |n| n[6] }
                t.add_column("Profit") { |n| n[7] }
              end
              Store.file("trade_history.txt",table_file)

              table_totals_file = Tablo::Table.new(results_totals,connectors: Tablo::CONNECTORS_SINGLE_ROUNDED) do |t|
                t.add_column("Balance") {|n| n[0] }
                t.add_column("Won") {|n| n[1] }
                t.add_column("Lost") {|n| n[2] }
                t.add_column("Profit") {|n| n[3] }
              end
              Store.file("trade_history.txt",table_totals_file)

              @status = "won"
              ws.close
              exit
            else              
              # Contract
              contract = {
                "buy"=> 1,
                "subscribe"=> 1,
                "price"=> martingale.to_s,
                "parameters"=> { 
                  "amount"=> martingale.to_s, 
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
            if show_notification
              display_notification("BinaryCR","Notification","Stop loss reached at $ #{track_profit.format(decimal_places: 2)}","lost")
            end
            
            puts "Stop loss reached at $#{track_profit.format(decimal_places: 2)}".colorize(:red)
            puts "\n"

            # Save results to a file
            table_file = Tablo::Table.new(results, connectors: Tablo::CONNECTORS_SINGLE_ROUNDED) do |t|
              t.add_column("Contract ID") { |n| n[0] }
              t.add_column("Contract Type", width: 16) { |n| n[1] }
              t.add_column("Entry Price") { |n| n[2] }
              t.add_column("Exit Price") { |n| n[3] }
              t.add_column("Entry Time", width: 30) { |n| n[4] }
              t.add_column("Exit Time", width: 30) { |n| n[5] }
              t.add_column("Amount") { |n| n[6] }
              t.add_column("Profit") { |n| n[7] }
            end
            Store.file("trade_history.txt",table_file)

            table_totals_file = Tablo::Table.new(results_totals,connectors: Tablo::CONNECTORS_SINGLE_ROUNDED) do |t|
              t.add_column("Balance") {|n| n[0] }
              t.add_column("Won") {|n| n[1] }
              t.add_column("Lost") {|n| n[2] }
              t.add_column("Profit") {|n| n[3] }
            end
            Store.file("trade_history.txt",table_totals_file)

            @status = "lost"
            ws.close
            exit
          end

        end      

      end

    end

    # Start infinite loop
    ws.run

  end

  def invert_contract_type(contract_type)
    if contract_type == "DIGITEVEN"
      contract_type = "DIGITODD"
    else
      contract_type = "DIGITEVEN"
    end
    return contract_type
  end

  def display_notification(notification="BinaryCR",title="Notification",subtitle="Crystal system notification",sound="won")
    # MacOS
    # system "osascript -e 'display notification \"#{notification}\" with title \"#{title}\" subtitle \"#{subtitle}\" sound name \"#{sound}\"'"

    # Windows WSL -- https://github.com/stuartleeks/wsl-notify-send
    system "wsl-notify-send.exe --appId \"#{notification} \" --category \"#{title}\" \"#{subtitle}\""
  end

end