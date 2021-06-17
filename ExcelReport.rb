require "fast_excel"
require_relative "Consts"
require_relative "USDRates"

COLUMNS = {
  Total:                   { Letter: "A" },
  InstrumentCaption:       { Letter: "B", Header: "Фьючерсный контракт" },
  Date:                    { Letter: "C", Header: "Дата", Format: "dd.mm.yyyy" },
  USDRate:                 { Letter: "D", Header: "Курс USD ЦБ РФ", Format: "0.0000" },
  Quantity:                { Letter: "E", Header: "Кол-во", Format: "0" },
  Price:                   { Letter: "F", Header: "Цена фьючерса", Format: "0.00" },
  AmountUSD:               { Letter: "G", Header: "Сумма сделки, USD", Format: "0.00" },
  CommissionUSD:           { Letter: "H", Header: "Комиссия, USD", Format: "0.00" },
  AmountWithCommissionUSD: { Letter: "I", Header: "Сумма сделки с учётом комиссии, USD", Format: "0.00" },
  AmountWithCommissionRUR: { Letter: "J", Header: "Сумма сделки с учётом комиссии, руб.", Format: "0.00000000" },
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
      COLUMNS.each_value do
        _1[:Workbook] = @workbook
        _1[:Worksheet] = @worksheet
      end

      col_Total = COLUMNS[:Total]
      col_InstrumentCaption = COLUMNS[:InstrumentCaption]
      col_Date = COLUMNS[:Date]
      col_USDRate = COLUMNS[:USDRate]
      col_Quantity = COLUMNS[:Quantity]
      col_Price = COLUMNS[:Price]
      col_AmountUSD = COLUMNS[:AmountUSD]
      col_CommissionUSD = COLUMNS[:CommissionUSD]
      col_AmountWithCommissionUSD = COLUMNS[:AmountWithCommissionUSD]
      col_AmountWithCommissionRUR = COLUMNS[:AmountWithCommissionRUR]

      tax_base_cells = []

      apply_column_formats

      update_usd_rates(executions, open_position_executions, action_infos)

      instruments = get_instruments(executions)
      instruments.each do |instrument|
        temp_executions = executions.select { |execution| execution.instrument == instrument }
        next if temp_executions.empty?

        append_table_header

        row_number = @worksheet.last_row_number + 1
        instrument_first_row_number = row_number
        col_InstrumentCaption.write(row_number, instrument)

        i = 0
        while i < temp_executions.size
          date = temp_executions[i].date

          col_Date.write(row_number, date.to_time + 86400)
          col_USDRate.write(row_number, USDRates.get_rate(date))
          usd_rate_row_number = row_number

          while i < temp_executions.size && temp_executions[i].date == date
            execution = temp_executions[i]

            col_Quantity.write(row_number, execution.signed_quantity)
            col_Price.write(row_number, execution.price)
            col_AmountUSD.write_formula(row_number, "#{col_Quantity.get_cell_ref(row_number)} * #{col_Price.get_cell_ref(row_number)} * #{execution.multiplier}")
            col_CommissionUSD.write(row_number, -execution.commission)
            col_AmountWithCommissionUSD.write_formula(row_number, "#{col_AmountUSD.get_cell_ref(row_number)} + #{col_CommissionUSD.get_cell_ref(row_number)}")
            col_AmountWithCommissionRUR.write_formula(row_number, "#{col_AmountWithCommissionUSD.get_cell_ref(row_number)} * #{col_USDRate.get_cell_ref(usd_rate_row_number)}")
            i += 1
            row_number += 1
          end
        end

        append_table_header

        row_number = @worksheet.last_row_number + 1
        col_Total.write(row_number, "Сумма:")
        col_Quantity.write_formula(row_number, "SUM(#{col_Quantity.get_cell_range_ref(instrument_first_row_number, row_number - 2)})")
        col_AmountUSD.write_formula(row_number, "SUM(#{col_AmountUSD.get_cell_range_ref(instrument_first_row_number, row_number - 2)})")
        col_CommissionUSD.write_formula(row_number, "SUM(#{col_CommissionUSD.get_cell_range_ref(instrument_first_row_number, row_number - 2)})")
        col_AmountWithCommissionUSD.write_formula(row_number, "SUM(#{col_AmountWithCommissionUSD.get_cell_range_ref(instrument_first_row_number, row_number - 2)})")
        col_AmountWithCommissionRUR.write_formula(row_number, "ROUNDUP(SUM(#{col_AmountWithCommissionRUR.get_cell_range_ref(instrument_first_row_number, row_number - 2)}), 2)")

        tax_base_cells << col_AmountWithCommissionRUR.get_cell_ref(row_number)

        col_Total.write(row_number + 1, "")
      end

      row_number = @worksheet.last_row_number + 1
      market_data_fee_first_row_number = row_number + 1
      col_InstrumentCaption.write(row_number, "Прочие комиссии")
      col_Date.write(row_number, col_Date[:Header])
      col_USDRate.write(row_number, col_USDRate[:Header])
      col_AmountWithCommissionUSD.write(row_number, "Сумма, USD")
      col_AmountWithCommissionRUR.write(row_number, "Сумма, руб.")
      (action_infos.select { %i[ActionKind_MarketDataFee ActionKind_WithdrawalFee].include?(_1[1]) }).each do |info|
        row_number += 1
        col_InstrumentCaption.write(row_number, info[1] == :ActionKind_MarketDataFee ? "Плата за рыночные данные" : "Комиссия за вывод денежных средств")
        col_Date.write(row_number, info[0].to_time + 86400)
        col_USDRate.write(row_number, USDRates.get_rate(info[0]))
        col_AmountWithCommissionUSD.write(row_number, -info[2])
        col_AmountWithCommissionRUR.write_formula(row_number, "#{col_AmountWithCommissionUSD.get_cell_ref(row_number)} * #{col_USDRate.get_cell_ref(row_number)}")
      end
      row_number += 1
      col_Total.write(row_number, "Сумма:")
      col_AmountWithCommissionUSD.write_formula(row_number, "SUM(#{col_AmountWithCommissionUSD.get_cell_range_ref(market_data_fee_first_row_number, row_number - 1)})")
      col_AmountWithCommissionRUR.write_formula(row_number, "ROUNDDOWN(SUM(#{col_AmountWithCommissionRUR.get_cell_range_ref(market_data_fee_first_row_number, row_number - 1)}), 2)")
      tax_base_cells << col_AmountWithCommissionRUR.get_cell_ref(row_number)

      row_number = @worksheet.last_row_number + 2
      col_Total.write(row_number, "Налоговая база:")
      col_AmountWithCommissionRUR.write_formula(row_number, tax_base_cells.join(" + "))
      col_Total.write(row_number + 1, "Налог:")
      col_AmountWithCommissionRUR.write_formula(row_number + 1, "ROUNDUP(#{col_AmountWithCommissionRUR.get_cell_ref(row_number)} * 0.13, 2)", @workbook.add_format(bg_color: "#D7E4BC"))

      @workbook.close
    end

  private

    def append_table_header
      f = @workbook.add_format(bg_color: "#4BACC6")

      row_number = @worksheet.last_row_number + 1
      COLUMNS.each_value { _1.write(row_number, _1[:Header], f) if _1[:Header] }
    end

    def apply_column_formats
      COLUMNS.each_value { _1.set_format(_1[:Format]) if _1[:Format] }
    end

    def get_instruments(executions)
      instruments = executions.map { _1.instrument }
      instruments.sort! do
        is_formalized1 = _1 =~ FORMALIZED_INSTRUMENT
        is_formalized2 = _2 =~ FORMALIZED_INSTRUMENT
        if is_formalized1 && is_formalized2
          instrument1 = _1[7..-1].strip
          instrument2 = _2[7..-1].strip
          res = instrument1 <=> instrument2
          res = _1[4, 2].to_i <=> _2[4, 2].to_i if res == 0
          res = MONTH_SHORTS.index(_1[0, 3]) <=> MONTH_SHORTS.index(_2[0, 3]) if res == 0
          res
        elsif is_formalized1
          -1
        elsif is_formalized2
          1
        else
          _1 <=> _2
        end
      end
      instruments.uniq
    end

    def update_usd_rates(executions, open_position_executions, action_infos)
      dates = (executions.map { _1.date }) + (open_position_executions.map { _1.date }) + (action_infos.map { _1[0] })
      min_date = dates.min
      max_date = dates.max
      USDRates.update_rates(min_date, max_date)
    end
  end
end
