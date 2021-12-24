class Tick
  property token : String, app_id : String

  def initialize(token,app_id,num_ticks)
    @token = token
    @app_id = app_id

    ticks_array = [] of Array(String)

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
        ws.send({ "ticks": "R_100" }.to_json)
      when "tick"
        tick      = data["tick"]["quote"].to_s
        date_time = Time.unix(data["tick"]["epoch"].to_s.to_i).to_local
        seconds   = date_time.second

        if [0,4,8,12,16,20,24,28,32,36,40,44,48,52,56].includes? seconds
          number = 0
          number_array = tick.split(".")
          if number_array.size == 2
            number = number_array[1].to_i
            if number_array[1].size == 1
              number = number * 10
            end
          end

          # Even or Odd
          contract = ""
          if number%2 == 0
            contract = "DIGITEVEN"
          else
            contract = "DIGITODD"
          end

          ticks_array.push([tick,date_time.to_s,contract])
          # Clear console
          print "\33c\e[3J"

          table_ticks = Tablo::Table.new(ticks_array,connectors: Tablo::CONNECTORS_SINGLE_ROUNDED) do |t|
            t.add_column("Tick",
              styler: ->(s : Tablo::CellType) { "#{s.colorize(:white)}" }) {|n| n[0] }
            t.add_column("Date", width: 30) {|n| n[1]}
            t.add_column("Contract",
            styler: ->(s : Tablo::CellType) { s.to_s == "DIGITODD" ? "#{s.colorize(:red)}" : "#{s.colorize(:green)}" }) {|n| n[2]}
          end
          table_ticks.each_with_index do |row, i|
            puts table_ticks.horizontal_rule(Tablo::TLine::Mid) if i > 0 && table_ticks.style =~ /ML/i
            puts row
          end
          puts table_ticks.horizontal_rule(Tablo::TLine::Bot) if table_ticks.style =~ /BL/i
          puts "\n"

        end

        if ticks_array.size == num_ticks
          exit
        end
      end
    end
    
    # Start infinite loop
    ws.run
  end

end