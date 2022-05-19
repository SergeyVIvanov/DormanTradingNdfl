require "fast_excel"
require_relative "Consts"
require_relative "USDRates"

COLUMNS = {
  InstrumentCaption:       { Letter: "A", Header: "Фьючерсный контракт" },
  Date:                    { Letter: "B", Header: "Дата", Format: "dd.mm.yyyy" },
  USDRate:                 { Letter: "C", Header: "Курс USD ЦБ РФ", Format: "0.0000" },
  Quantity:                { Letter: "D", Header: "Кол-во", Format: "0" },
  Price:                   { Letter: "E", Header: "Цена фьючерса" },
  CommissionUSD:           { Letter: "F", Header: "Комиссия, USD", Format: "0.00" },
  AmountWithCommissionUSD: { Letter: "G", Header: "Сумма сделки, USD", Format: "0.00" },
  AmountWithCommissionRUR: { Letter: "H", Header: "Сумма сделки, руб.", Format: "0.00" },
}

class Hash
  def get_cell_range_ref(row_number_from, row_number_to)
    "#{self[:Letter]}#{row_number_from + 1}:#{self[:Letter]}#{row_number_to + 1}"
  end

  def get_cell_ref(row_number)
    "#{self[:Letter]}#{row_number + 1}"
  end

  def set_format(format)
    self[:Worksheet].set_column(col_index, col_index, nil, self[:Workbook].number_format(format))
  end

  def write(row_number, value, format = nil)
    self[:Worksheet].write_value(row_number, col_index, value, format)
  end

  def write_formula(row_number, value, format = nil)
    self[:Worksheet].write_value(row_number, col_index, FastExcel::Formula.new(value), format)
  end

private

  def col_index
    self[:Letter].ord - "A".ord
  end
end

class ExcelReportGenerator
  class << self
    def generate(executions, open_position_executions, action_infos)
      File.delete(FILE_NAME_REPORT) if File.exists?(FILE_NAME_REPORT)

      @workbook = FastExcel.open(FILE_NAME_REPORT)
      @worksheet = @workbook.add_worksheet("Отчёт")
      @worksheet.auto_width = true
      COLUMNS.each_value do
        _1[:Workbook] = @workbook
        _1[:Worksheet] = @worksheet
      end

      # col_Total = COLUMNS[:Total]
      col_InstrumentCaption = COLUMNS[:InstrumentCaption]
      col_Date = COLUMNS[:Date]
      col_USDRate = COLUMNS[:USDRate]
      col_Quantity = COLUMNS[:Quantity]
      col_Price = COLUMNS[:Price]
      # col_AmountUSD = COLUMNS[:AmountUSD]
      col_CommissionUSD = COLUMNS[:CommissionUSD]
      col_AmountWithCommissionUSD = COLUMNS[:AmountWithCommissionUSD]
      col_AmountWithCommissionRUR = COLUMNS[:AmountWithCommissionRUR]

      tax_base_cells = []

      apply_column_formats

      update_usd_rates(executions, open_position_executions, action_infos)

      instruments = get_instruments(executions)
      instruments.each do |instrument|
        temp_executions = executions.select { |execution| execution.instrument_base_name == instrument }
        next if temp_executions.empty?

        append_table_header("#4BACC6")

        row_number = @worksheet.last_row_number + 1
        instrument_first_row_number = row_number
        col_InstrumentCaption.write(row_number, instrument)

        i = 0
        while i < temp_executions.size
          execution = temp_executions[i]
          date = execution.date

          col_Date.write(row_number, date.to_time + 86400)
          col_USDRate.write(row_number, USDRates.get_rate(date))
          col_Quantity.write(row_number, -execution.signed_quantity)
          col_Price.write(row_number, execution.price, get_format_price(execution))
          
          v = (execution.signed_quantity * execution.price * execution.multiplier).to_s('F')
          if index = v.index('.')
            raise if v.size - index - 1 > 2
          end
          # col_AmountUSD.write_formula(row_number, "-#{col_Quantity.get_cell_ref(row_number)} * #{col_Price.get_cell_ref(row_number)} * #{execution.multiplier}", get_format_amount_usd(execution))

          col_CommissionUSD.write(row_number, -execution.commission)
          col_AmountWithCommissionUSD.write_formula(row_number, "-#{col_Quantity.get_cell_ref(row_number)} * #{col_Price.get_cell_ref(row_number)} * #{execution.multiplier} + #{col_CommissionUSD.get_cell_ref(row_number)}", get_format_amount_with_commission_usd(execution))
          col_AmountWithCommissionRUR.write_formula(row_number, "ROUND(#{col_AmountWithCommissionUSD.get_cell_ref(row_number)} * #{col_USDRate.get_cell_ref(row_number)}, 2)")
          i += 1
          row_number += 1
        end

        append_table_header("#4BACC6")

        row_number = @worksheet.last_row_number + 1
        col_InstrumentCaption.write(row_number, "Сумма:", @workbook.add_format(bg_color: "#C6EFCE"))
        col_Quantity.write_formula(row_number, "SUM(#{col_Quantity.get_cell_range_ref(instrument_first_row_number, row_number - 2)})", @workbook.add_format(bg_color: "#C6EFCE"))
        # col_AmountUSD.write_formula(row_number, "SUM(#{col_AmountUSD.get_cell_range_ref(instrument_first_row_number, row_number - 2)})")
        # col_CommissionUSD.write_formula(row_number, "SUM(#{col_CommissionUSD.get_cell_range_ref(instrument_first_row_number, row_number - 2)})")
        # col_AmountWithCommissionUSD.write_formula(row_number, "SUM(#{col_AmountWithCommissionUSD.get_cell_range_ref(instrument_first_row_number, row_number - 2)})")
        col_AmountWithCommissionRUR.write_formula(row_number, "SUM(#{col_AmountWithCommissionRUR.get_cell_range_ref(instrument_first_row_number, row_number - 2)})", @workbook.add_format(bg_color: "#C6EFCE"))

        tax_base_cells << col_AmountWithCommissionRUR.get_cell_ref(row_number)

        col_InstrumentCaption.write(row_number + 1, "")
      end

      # row_number = @worksheet.last_row_number + 1
      # market_data_fee_first_row_number = row_number + 1
      # col_InstrumentCaption.write(row_number, "Прочие комиссии")
      # col_Date.write(row_number, col_Date[:Header])
      # col_USDRate.write(row_number, col_USDRate[:Header])
      # col_AmountWithCommissionUSD.write(row_number, "Сумма, USD")
      # col_AmountWithCommissionRUR.write(row_number, "Сумма, руб.")
      # (action_infos.select { %i[ActionKind_MarketDataFee ActionKind_WithdrawalFee].include?(_1[1]) }).each do |info|
      #   row_number += 1
      #   col_InstrumentCaption.write(row_number, info[1] == :ActionKind_MarketDataFee ? "Плата за рыночные данные" : "Комиссия за вывод денежных средств")
      #   col_Date.write(row_number, info[0].to_time + 86400)
      #   col_USDRate.write(row_number, USDRates.get_rate(info[0]))
      #   col_AmountWithCommissionUSD.write(row_number, -info[2])
      #   col_AmountWithCommissionRUR.write_formula(row_number, "#{col_AmountWithCommissionUSD.get_cell_ref(row_number)} * #{col_USDRate.get_cell_ref(row_number)}")
      # end
      # row_number += 1
      # col_Total.write(row_number, "Сумма:")
      # col_AmountWithCommissionUSD.write_formula(row_number, "SUM(#{col_AmountWithCommissionUSD.get_cell_range_ref(market_data_fee_first_row_number, row_number - 1)})")
      # col_AmountWithCommissionRUR.write_formula(row_number, "ROUNDDOWN(SUM(#{col_AmountWithCommissionRUR.get_cell_range_ref(market_data_fee_first_row_number, row_number - 1)}), 2)")
      # tax_base_cells << col_AmountWithCommissionRUR.get_cell_ref(row_number)

      row_number = @worksheet.last_row_number + 2
      f1 = @workbook.add_format(bold: true, font_size: 14)
      f2 = @workbook.add_format(font_size: 14)
      col_InstrumentCaption.write(row_number, "Налоговая база:", f1)
      col_AmountWithCommissionRUR.write_formula(row_number, tax_base_cells.join(" + "), f2)
      col_InstrumentCaption.write(row_number + 1, "Налог:", f1)
      col_AmountWithCommissionRUR.write_formula(row_number + 1, "ROUNDUP(#{col_AmountWithCommissionRUR.get_cell_ref(row_number)} * 0.13, 2)", @workbook.add_format(bg_color: "#FFCC99", font_size: 14))

      @workbook.close
    end

  private

    def append_table_header(color)
      f = @workbook.add_format(bg_color: color)

      row_number = @worksheet.last_row_number + 1
      COLUMNS.each_value { _1.write(row_number, _1[:Header], f) if _1[:Header] }
    end

    def apply_column_formats
      COLUMNS.each_value { _1.set_format(_1[:Format]) if _1[:Format] }
    end

    def get_format_amount_usd(execution)
      get_number_format(get_precision_amount_usd(execution))
    end

    def get_format_amount_with_commission_usd(execution)
      get_number_format(get_precision_amount_usd(execution))
    end

    def get_format_price(execution)
      get_number_format(execution.instrument_precision)
    end

    def get_instruments(executions)
      instruments = executions.map { _1.instrument_base_name }
      instruments.sort!
      instruments.uniq
    end

    def get_number_format(precision)
      format = '0'
      format += '.' + '0' * precision if precision != 0
      @workbook.number_format(format)
    end

    def get_precision_amount_usd(execution)
      2
    end

    def update_usd_rates(executions, open_position_executions, action_infos)
      dates = (executions.map { _1.date }) + (open_position_executions.map { _1.date }) + (action_infos.map { _1[0] })
      min_date, max_date = dates.minmax
      USDRates.update_rates(min_date, max_date)
    end
  end
end
