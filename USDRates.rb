require "bigdecimal"
require "date"
require "rexml/document"
require "net/http"
require_relative "Consts"

include REXML

module USDRates
  USD_RATES = []

  @@are_rates_loaded = false
  @@first_date = nil
  @@last_date = nil

  def self.get_rate(date)
    load_rates

    index = (date - @@first_date).to_i
    index -= 1 while index >= 0 && !USD_RATES[index]
    raise(date.to_s + ', ' + @@first_date.to_s) if index < 0
    USD_RATES[index]
  end

  def self.load_rates
    return if @@are_rates_loaded
    @@are_rates_loaded = true

    if File.exists?(FILE_NAME_USD_RATES)
      lines = File.readlines(FILE_NAME_USD_RATES)
      lines.each do | line |
        a = line.split
        date = parse_date(a[0])
        @@first_date = date unless @@first_date
        raise if @@last_date && date <= @@last_date
        @@last_date = date
        index = (date - @@first_date).to_i
        raise if index < 0 || USD_RATES[index]
        USD_RATES[index] = BigDecimal(a[1])
      end
    end
  end

  def self.parse_date(s)
    Date.new(s[6,4].to_i, s[3,2].to_i, s[0,2].to_i)
  end

  def self.update_rates(first_date, last_date)
    return if @@first_date && first_date >= @@first_date && last_date <= @@last_date
    first_date -= 10

    uri = URI("http://www.cbr.ru/scripts/XML_dynamic.asp?date_req1=#{uri_encode_date_param_value(first_date)}&date_req2=#{uri_encode_date_param_value(last_date)}&VAL_NM_RQ=R01235")
    # puts uri.to_s
    res = Net::HTTP.get_response(uri)
    # p res
    abort("Cannot update USD rates".red + "\n" + uri.to_s + "\n" + res.class.to_s) unless res.is_a?(Net::HTTPSuccess)

    USD_RATES.clear
    @@first_date = nil
    @@last_date = nil
    @@are_rates_loaded = true
    File.open(FILE_NAME_USD_RATES, "a") do |file|
      doc = Document.new(res.body)
      doc.elements.each('//Record') do |record|
        date = parse_date(record["Date"])
        @@first_date = date unless @@first_date
        @@last_date = date
        rate = record.elements["Value"].text.gsub(",", ".")
        USD_RATES[date - @@first_date] = BigDecimal(rate)
        file.puts "#{date.strftime("%d.%m.%Y")}\t#{rate}"
      end
    end
  end

  def self.uri_encode_date_param_value(date)
    date.strftime("%d/%m/%Y")
  end

  private_constant :USD_RATES
  private_class_method :load_rates, :parse_date, :uri_encode_date_param_value
end
