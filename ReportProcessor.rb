require "bigdecimal"
require "date"

require_relative "RubyClassPatches"

require_relative "CommandLineParser"
require_relative "Consts"
require_relative "DormanDailyReportProcessor"
require_relative "Execution"
require_relative "ExcelReport"

def parse_date(s)
  raise unless s =~ /\A\d{4}\-\d{2}\-\d{2}\z/
  Date.new(s[0,4].to_i, s[5,2].to_i, s[8,2].to_i)
end

def parse_instrument_kind(s)
  case s
  when 'FOP'
    'Опцион на фьючерс'
  when 'FUT'
    'Фьючерс'
  else
    raise
  end
end

def process_executions(executions, open_executions)
  temp_open_executions = {}
  open_executions.each do |execution|
    temp_open_executions[execution.instrument] = [] unless temp_open_executions.has_key?(execution.instrument)
    temp_open_executions[execution.instrument] << execution
  end

  execution_index = 0
  while execution_index < executions.size
    execution = executions[execution_index]

    temp_open_executions[execution.instrument] = [] unless temp_open_executions.has_key?(execution.instrument)
    temp_executions = temp_open_executions[execution.instrument]
    i = 0
    while i < temp_executions.size
      temp_execution = temp_executions[i]
      if temp_execution.long? != execution.long?
        quantity = [temp_execution.quantity, execution.quantity].min
        commission = execution.base_commission * quantity
        commission += temp_execution.base_commission * quantity if temp_execution.date.year == execution.date.year
        profit = (execution.price - temp_execution.price) * execution.multiplier * quantity
        profit = -profit unless temp_execution.long?

        yield execution.instrument,
              execution.instrument_kind,
              temp_execution.date,
              temp_execution.price,
              execution.date,
              execution.price,
              quantity * (temp_execution.long? ? 1 : -1),
              commission,
              profit,
              execution.multiplier,
              execution.instrument_precision

        case temp_execution.quantity <=> execution.quantity
        when -1
          execution = execution.clone
          execution.quantity -= temp_execution.quantity
          temp_executions.delete_at(i)
        when 0
          execution = nil
          temp_executions.delete_at(i)
          break
        when 1
          temp_execution = temp_execution.clone
          temp_execution.quantity -= execution.quantity
          temp_executions[i] = temp_execution
          execution = nil
          break
        end
      else
        i += 1
      end
    end
    temp_executions << execution unless execution.nil?

    execution_index += 1
  end

  temp_open_executions.values.flatten
end

t = Time.now

$options = parse_command_line

if $options.ntc
  executions = []
  lines = File.readlines($options.path)
  company_name = lines[0].chomp
  beginning_balance = BigDecimal(lines[1].chomp)
  i = 2
  while i < lines.size
    line = lines[i].chomp
    break if line.empty?
    a = line.split(',')

    execution = Execution.new(parse_date(a[0]), a[1], parse_instrument_kind(a[2]), BigDecimal(a[3]), a[4].to_i, a[5] == 'true', BigDecimal(a[6]), a[7].to_i)
    execution.multiplier = BigDecimal(a[8])
    executions << execution

    i += 1
  end

  action_infos = []
  i += 1
  while i < lines.size
    a = lines[i].chomp.split(',')
    action_infos << [parse_date(a[0]), a[1].to_sym, BigDecimal(a[2])]
    i += 1
  end

  open_position_executions = []
else
  company_name = 'Dorman Trading LLC'
  beginning_balance, executions, open_position_executions, action_infos = DormanDailyReportProcessor.process($options.path)
end

puts "Beginning balance: #{beginning_balance.to_money_string}"

balance = beginning_balance
income = BigDecimal("0")
investments = BigDecimal("0")
outcome = BigDecimal("0")
profit = BigDecimal("0")
withdrawals = BigDecimal("0")

action_infos.each do |action_info|
  amount = action_info[2]

  case action_info[1]
  when :ActionKind_Deposit
    balance += amount
    income += amount
    investments += amount
  when :ActionKind_MarketDataFee
    balance -= amount
    outcome += amount
    profit -= amount
  when :ActionKind_Withdrawal
    balance -= amount
    outcome += amount
    withdrawals += amount
  when :ActionKind_TransferToNTC
    balance -= amount
    outcome += amount
    withdrawals += amount
  when :ActionKind_WithdrawalFee
    balance -= amount
    outcome += amount
    profit -= amount
  else
    raise
  end
end

open_executions = process_executions(executions, []) do |instrument, instrument_kind, date_open, price_open, date_close, price_close, quantity, commission, temp_profit, instrument_multiplier, instrument_precision|
  balance += temp_profit - commission
  outcome += commission
  if temp_profit > 0
    income += temp_profit
  else
    outcome -= temp_profit
  end
  profit += temp_profit - commission
end
p open_executions

open_position_executions.each do |execution|
  balance -= execution.commission
  outcome -= execution.commission
  profit -= execution.commission
end

open_executions.each do |execution|
  commission = execution.base_commission * execution.quantity
  balance -= commission
  outcome -= commission
  profit -= commission
end

puts "Income: #{income.to_money_string}"
puts "Outcome: #{outcome.to_money_string}"
puts "Ending balance: #{balance.to_money_string}"
puts "Total profit: #{profit.to_money_string}"
puts "Investments: #{investments.to_money_string}, #{(investments - withdrawals).to_money_string} (after withdrawals)"
puts "Withdrawals: #{withdrawals.to_money_string}"

ExcelReportGenerator.generate_money_movement_report(company_name, beginning_balance, executions, open_executions, action_infos)
# executions.sort!
# ExcelReportGenerator.generate(executions, open_position_executions, action_infos)

puts Time.now - t
