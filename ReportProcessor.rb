require "bigdecimal"
require "date"

require_relative "RubyClassPatches"

HEADER_COMMON_INFO = '** US DOLLARS **'
TABLE_HEADER_CONFIRMATION = 'TRADE SETTL AT BUY SELL CONTRACT DESCRIPTION EX PRICE CC DEBIT/CREDIT'
TABLE_HEADER_OPEN_POSITIONS = 'TRADE CARD AT LONG SHORT CONTRACT DESCRIPTION EX PRICE CC DEBIT/CREDIT'
TABLE_HEADER_PURCHASE_AND_SALE = 'TRADE SETTL AT LONG SHORT CONTRACT DESCRIPTION EX PRICE CC DEBIT/CREDIT'
TABLE_HEADER_JOURNAL = 'TRADE SETTL AT LONG SHORT JOURNAL DESCRIPTION EX TRADE PRICE CC DEBIT/CREDIT'

JOURNAL_ACTIONS = {
  'DATA FEE' => :ActionKind_MarketDataFee,
  'WT CREDIT' => :ActionKind_Deposit,
  'WT DEBIT' => :ActionKind_Withdrawal,
  'WT FEE' => :ActionKind_WithdrawalFee
}

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
        @width = a[3].to_f
    end
  end

  def width
    raise unless @kind == :Text
    @width
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

def process_tables_confirmation(text_infos)
  
end

def process_tables_journal(text_infos)
  action_infos = []

  text_infos.each do |text_info|
    text, block_indexes = text_info

    i = text.index('STATEMENT DATE')
    i = text.index("\n", i + 'STATEMENT DATE'.size)
    year = text[i - 4, 4].to_i

    lines = read_table(text, block_indexes, TABLE_HEADER_JOURNAL)
    next if lines.empty?
    lines.reject! { |line| line[0,7].strip.empty? }

    lines.each do |line|
      s = line[0,7]
      date = Date.new(year,  s[0,2].to_i,  s[3,2].to_i)
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

def read_table(text, block_indexes, table_header)
  lines = []

  index = 0
  while index = text.index(table_header, index)
    index += table_header.size + 1
    i = block_indexes[index]
    left = $blocks[i].x
    char_width = $blocks[i].width / $blocks[i].text.size
    i += 1 while $blocks[i].text.start_with?('-')
    block = $blocks[i - 1]
    w = ((block.x + block.width - left) / char_width).round
    loop do
      line = ' ' * w
      y = $blocks[i].y
      begin
        pos = (($blocks[i].x - left) / char_width).round
        raise (($blocks[i].x - left) / char_width).to_s if pos + $blocks[i].text.size > w
        line[pos, $blocks[i].text.size] = $blocks[i].text
        i += 1
      end while $blocks[i].kind == :Text && $blocks[i].y == y
      lines << line
      break if $blocks[i].kind != :Text || $blocks[i].text == '**' || $blocks[i].text == '*' && $blocks[i + 1].text == '*'
    end
  end

  lines
end

$blocks = File.readlines('D:/Trading/Reports_2021/a.txt').map { |line| PdfBlock.new(line) }
text_infos = get_text_infos($blocks)

i = text_infos[0][0].index('BEGINNING BALANCE ')
raise unless i
i += 'BEGINNING BALANCE '.size
puts 'Beginning balance: ' + $blocks[text_infos[0][1][i]].text

text_infos.each do |text_info|
  text, block_indexes = text_info
  read_table(text, block_indexes, TABLE_HEADER_CONFIRMATION)
end

action_infos = process_tables_journal(text_infos)
puts action_infos.map { |action_info| "#{action_info[0]}, #{action_info[1]}, #{action_info[2].to_money_string}" }
abort
