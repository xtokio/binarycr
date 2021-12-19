module Store
  extend self

  def file(file_name,data)
    File.open(file_name, "a") do |file|
      file.puts data
    end
  end
end