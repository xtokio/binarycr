class Balance
  property token : String, app_id : String, balance : Float64

  def initialize(token,app_id)
    @token = token
    @app_id = app_id
    @balance = 0

    # Clear console
    print "\33c\e[3J"

    auth = { "authorize": token }

    # Open websocket connection
    ws = HTTP::WebSocket.new(URI.parse("wss://ws.binaryws.com/websockets/v3?app_id=#{app_id}"))
    ws.send(auth.to_json)

    # Set callback
    ws.on_message do |msg|
      data = JSON.parse(msg)

      case data["msg_type"]
      when "authorize"
        ws.send({ "balance": 1, "subscribe": 1 }.to_json)
      when "balance"
        @balance = data["balance"]["balance"].to_s.to_f
        # Totals table
        balance_display = "$#{@balance}"

        result_balance = [] of Array(String)
        result_balance.push([balance_display])
        table_balance = Tablo::Table.new(result_balance,connectors: Tablo::CONNECTORS_SINGLE_ROUNDED) do |t|
          t.add_column("Balance",
            styler: ->(s : Tablo::CellType) { "#{s.colorize(:green)}" }) {|n| n[0] }
        end
        table_balance.each_with_index do |row, i|
          puts table_balance.horizontal_rule(Tablo::TLine::Mid) if i > 0 && table_balance.style =~ /ML/i
          puts row
        end
        puts table_balance.horizontal_rule(Tablo::TLine::Bot) if table_balance.style =~ /BL/i
        puts "\n"

        exit
      end
    end
    
    # Start infinite loop
    ws.run
  end

end