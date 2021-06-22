require "bigdecimal"
require "date"

require_relative "RubyClassPatches"

require_relative "CommandLineParser"
require_relative "Consts"
require_relative "Execution"
require_relative "ExcelReport"
require_relative "PdfTextReader"

class PdfBlock
  def initialize(s)
    a = s.chomp.split('|')
    @text = ''
    case a[0]
      when 'DOCUMENT_START'
        @kind = :DocumentStart
      when 'DOCUMENT_FINISH'
        @kind = :DocumentFinish
      when 'PAGE_START'
        @kind = :PageStart
      when 'PAGE_FINISH'
        @kind = :PageFinish
      else
        @kind = :Text
        @text = a[0]
        @x = a[1].to_f
        @y = a[2].to_f
    end
  end

  def x
    raise unless @kind == :Text
    @x
  end

  def y
    raise unless @kind == :Text
    @y
  end

  attr_reader :kind, :text
end

def get_date(line, document_year)
  s = line[0, 7]
  return nil if s.strip.empty?
  year = s[6].to_i
  document_year -= 10 if year > (document_year % 10)
  year = document_year / 10 * 10 + year
  begin
    Date.new(year, s[0, 2].to_i, s[3, 2].to_i)
  rescue
    raise line.inspect
  end
end

def get_year(text)
  i = text.index('STATEMENT DATE')
  i = text.index("\n", i + 'STATEMENT DATE'.size)
  text[i - 4, 4].to_i
end

def get_text_infos(blocks)
  text_infos = []

  i = 0
  while i < blocks.size
    i += 2
    text = ''
    block_indexes = []
    loop do
      y = blocks[i].y
      text << "\n" unless text.empty?
      block_indexes[text.size] = i
      text << blocks[i].text
      i += 1
      loop do
        block = blocks[i]
        break if block.kind == :PageFinish || block.y != y
        text << ' '
        block_indexes[text.size] = i
        text << blocks[i].text
        i += 1
      end

      if blocks[i].kind == :PageFinish
        i += 1
        if blocks[i].kind == :DocumentFinish
          text_infos << [text, block_indexes]
          i += 1
          break
        end
        i += 1
      end
    end
  end

  text_infos
end

def process_table_confirmation(text_info, instrument_commissions)
  temp_instrument_commissions = {}

  text, block_indexes = text_info
  year = get_year(text)
  lines = read_table(text, block_indexes, TABLE_HEADER_CONFIRMATION)
  date = nil
  i = 0
  while i < lines.size
    line = lines[i]
    date = get_date(line, year) unless date
    instrument = line[49..78].strip
    begin
      i += 1
      line = lines[i]
    end until line[0,7].strip.empty?
    a = line.split
    count = a[1][0..-2].to_i + a[2][0..-2].to_i
    commission = BigDecimal('0')
    begin
      commission += BigDecimal(a.last[0..-3])
      i += 1
      break if i == lines.size
      line = lines[i]
      a = line.split
    end while line[0,7].strip.empty?
    commission /= count
    temp_instrument_commissions[instrument] = commission
  end

  instrument_commissions[date] = temp_instrument_commissions
end

def process_tables_journal(text_infos)
  action_infos = []

  text_infos.each do |text_info|
    text, block_indexes = text_info

    year = get_year(text)

    lines = read_table(text, block_indexes, TABLE_HEADER_JOURNAL)
    next if lines.empty?
    lines.reject! { |line| line[0, 7].strip.empty? }

    lines.each do |line|
      date = get_date(line, year)
      s = line.strip
      s = s[s.rindex(' ') + 1..-1].gsub(',', '')
      s = s[0..-3] if s.end_with?('DR')
      amount = BigDecimal(s)
      action_kind = nil
      JOURNAL_ACTIONS.each do | pattern, action_kind_temp |
        if line.index(pattern)
          action_kind = action_kind_temp
          break
        end
      end
      raise unless action_kind
      action_infos << [date, action_kind, amount]
    end
  end

  action_infos
end

def process_table_open_positions(text_info, instrument_commissions)
  executions = []

  text, block_indexes = text_info
  year = get_year(text)

  lines = read_table(text, block_indexes, TABLE_HEADER_OPEN_POSITIONS)
  i = 0
  while i < lines.size
    loop do
      line = lines[i]

      date = get_date(line, year)
      break unless date

      s = line[19..32].strip
      is_long = !s.empty?
      if is_long 
        quantity = s.to_i
      else
        quantity = line[34..47].strip.to_i
      end

      instrument = line[49..78].strip

      s = line[83..93].strip
      if index = s.index('.')
        instrument_precision = s.size - index - 1
      else
        instrument_precision = 0
      end
      price = BigDecimal(s)

      instrument_commission = instrument_commissions[date][instrument]
      raise unless instrument_commission

      executions << Execution.new(date, instrument, price, quantity, is_long, instrument_commission, instrument_precision)

      i += 1
    end
    begin
      i += 1
      break if i == lines.size
      line = lines[i]
    end until get_date(line, year)
  end

  executions
end

def process_table_purchase_and_sale(text_info, instrument_commissions)
  executions = []

  text, block_indexes = text_info
  year = get_year(text)

  lines = read_table(text, block_indexes, TABLE_HEADER_PURCHASE_AND_SALE)
  i = 0
  while i < lines.size
    temp_executions = []
    sum = BigDecimal('0')
    loop do
      line = lines[i]

      date = get_date(line, year)
      break unless date
      
      s = line[19..32].strip
      is_long = !s.empty?
      if is_long 
        quantity = s.to_i
      else
        quantity = line[34..47].strip.to_i
      end

      instrument = line[49..78].strip

      s = line[83..93].strip
      if index = s.index('.')
        instrument_precision = s.size - index - 1
      else
        instrument_precision = 0
      end
      price = BigDecimal(s)

      instrument_commission = instrument_commissions[date][instrument]
      raise unless instrument_commission

      temp_executions << Execution.new(date, instrument, price, quantity, is_long, instrument_commission, instrument_precision)

      sum += price * quantity * (is_long ? -1 : 1)

      i += 1
    end

    profit = lines[i].split.last
    is_loss = profit.end_with?('DR')
    profit = profit[0..-3] if is_loss
    multiplier = BigDecimal(profit.gsub(',', '')) * (is_loss ? -1 : 1) / sum
    temp_executions.each { |execution| execution.multiplier = multiplier }
    executions += temp_executions

    begin
      i += 1
      break if i == lines.size
      line = lines[i]
    end until get_date(line, year)
  end

  executions
end

def read_table(text, block_indexes, table_header)
  lines = []

  index = 0
  while index = text.index(table_header, index)
    index += table_header.size + 1
    i = block_indexes[index]
    left = $blocks[i].x
    i += 1 while $blocks[i].text.start_with?('-')
    block = $blocks[i - 1]
    char_width = 4.2 # (block.x - left) / 99
    w = 118 # ((block.x + block.width - left) / char_width).round
    loop do
      break if $blocks[i].kind != :Text || $blocks[i].text == 'THE' || $blocks[i].text == '**' || $blocks[i].text == '*' && $blocks[i + 1].text == '*'
      line = ' ' * w
      y = $blocks[i].y
      begin
        pos = (($blocks[i].x - left) / char_width).round
        raise (($blocks[i].x - left) / char_width).to_s if pos + $blocks[i].text.size > w
        line[pos, $blocks[i].text.size] = $blocks[i].text
        i += 1
      end while $blocks[i].kind == :Text && $blocks[i].y == y
      lines << line
    end
  end

  lines
end

$options = parse_command_line

$blocks = get_pdf_text_infos($options.dir_path).map { |line| PdfBlock.new(line) }
text_infos = get_text_infos($blocks)

i = text_infos[0][0].index('BEGINNING BALANCE ')
raise unless i
i += 'BEGINNING BALANCE '.size
balance = BigDecimal($blocks[text_infos[0][1][i]].text.gsub(',', ''))
puts "Beginning balance: #{balance.to_money_string}"

executions = []
instrument_commissions = {}
text_infos.each do |text_info|
  process_table_confirmation(text_info, instrument_commissions)
  executions += process_table_purchase_and_sale(text_info, instrument_commissions)
end

open_position_executions = process_table_open_positions(text_infos.last, instrument_commissions)

action_infos = process_tables_journal(text_infos)

#################################################################################################################
investments = BigDecimal("0")
withdrawals = BigDecimal("0")
profit = BigDecimal("0")

action_index = 0
while action_index < action_infos.size
  action_info = action_infos[action_index]

  case action_info[1]
  when :ActionKind_Deposit
    balance += action_info[2]
    investments += action_info[2]
  when :ActionKind_MarketDataFee
    balance -= action_info[2]
    profit -= action_info[2]
  when :ActionKind_Withdrawal
    balance -= action_info[2]
    withdrawals += action_info[2]
    #profit -= action_info[2]
  when :ActionKind_WithdrawalFee
    balance -= action_info[2]
    profit -= action_info[2]
  else
    raise
  end

  action_index += 1
end

execution_index = 0
while execution_index < executions.size
  execution = executions[execution_index]

  delta = execution.amount - execution.commission
  balance += delta
  profit += delta

  execution_index += 1
end

open_position_executions.each do |execution|
  balance -= execution.commission
  profit -= execution.commission
end

puts "Ending balance: #{balance.to_money_string}"
puts "Total profit: #{profit.to_money_string}"
puts "Investments: #{investments.to_money_string}, #{(investments - withdrawals).to_money_string} (after withdrawals)"
puts "Withdrawals: #{withdrawals.to_money_string}"

executions.sort!
ExcelReportGenerator.generate(executions, open_position_executions, action_infos)
