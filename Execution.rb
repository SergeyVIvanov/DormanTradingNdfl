require_relative "RubyClassPatches"

class Execution
  attr_reader :base_commission, :date, :instrument, :instrument_kind, :instrument_precision, :price
  attr_accessor :multiplier, :quantity

  def initialize(date, instrument, instrument_kind, price, quantity, is_long, base_commission, instrument_precision)
    @date = date
    @instrument = instrument
    @instrument_kind = instrument_kind
    @price = price
    @quantity = quantity
    @is_long = is_long
    @base_commission = base_commission
    @instrument_precision = instrument_precision
  end

  def <=>(other)
    res = @instrument <=> other.instrument
    res = (date <=> other.date) if res == 0
    # res = @instrument_date <=> other.instrument_date if res == 0
    res = @price <=> other.price if res == 0
    if res == 0 && (@is_long != other.long?)
      res = (@is_long ? -1 : 1)
    end
    res
  end

  def amount
    @price * @multiplier * signed_quantity
  end

  def can_merge(other)
    (self <=> other) == 0
  end

  def get_amount(signed_quantity)
    @price * @multiplier * signed_quantity
  end

  def long?
    @is_long
  end

  def merge(other)
    @quantity += other.quantity
  end

  def to_s
    @date.to_s + ', ' + @instrument + ', ' + (long? ? 'buy' : 'sell') + ', ' + @quantity.to_s + ', ' + @price.to_money_string
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
