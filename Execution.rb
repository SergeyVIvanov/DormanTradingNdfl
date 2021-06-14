require_relative "Instruments"

class Execution
  attr_reader :date, :instrument, :instrument_commission, :instrument_date, :is_long, :price
  attr_accessor :quantity

  # def self.parse(s)
  #   # 2020-05-28 11:34:30:546|1|8|Execution='329409888512' Instrument='ES 06-20' Account='Y7840' Exchange=Globex Price=3034.75 Quantity=1 Market position=Long Operation=Operation_Add Order='1189882789' Time='05/28/2020 11:34:29'
  #   h = parse_internal(s)
  #   instrument_info = parse_field_instrument(h["Instrument"])

  #   Execution.new(
  #     h["Account"],
  #     h["Order"],
  #     parse_field_time(h["Time"]),
  #     instrument_info[0],
  #     instrument_info[1],
  #     h["Price"].to_f,
  #     h["Quantity"].to_i,
  #     h["Market position"] == "Long"
  #   )
  # end

  def initialize(date, instrument, instrument_date, price, quantity, is_long, instrument_commission)
    raise unless INSTRUMENTS.has_key?(instrument)

    @date = date
    @instrument = instrument
    @instrument_date = instrument_date
    @price = price
    @quantity = quantity
    @is_long = is_long
    @instrument_commission = instrument_commission
  end

  def <=>(other)
    res = (date <=> other.date)
    res = @instrument <=> other.instrument if res == 0
    res = @instrument_date <=> other.instrument_date if res == 0
    res = @price <=> other.price if res == 0
    if res == 0 && (@is_long != other.long?)
      res = (@is_long ? -1 : 1)
    end
    res
  end

  def amount
    @price * INSTRUMENTS[@instrument] * signed_quantity
  end

  def can_merge(other)
    (self <=> other) == 0
  end

  def commission
    @instrument_commission * @quantity
  end

  def get_amount(signed_quantity)
    @price * INSTRUMENTS[@instrument] * signed_quantity
  end

  def get_commission(quantity)
    @instrument_commission * quantity
  end

  def long?
    @is_long
  end

  def merge(other)
    @quantity += other.quantity
  end

  def to_s
    @date.to_s + ', ' + @instrument + ', ' + (long? ? 'buy' : 'sell') + ', ' + @quantity.to_s + ', ' + @price.to_s
  end

  def signed_quantity
    @quantity * (@is_long ? -1 : 1)
  end
end

def optimize_executions(executions)
  executions.sort!

  i = 0
  while i < executions.size
    e1 = executions[i]
    j = i + 1
    while j < executions.size
      e2 = executions[j]
      if e1.can_merge(e2)
        e1.merge(e2)
        executions.delete_at(j)
      else
        break
      end
    end
    i = j
  end
end
