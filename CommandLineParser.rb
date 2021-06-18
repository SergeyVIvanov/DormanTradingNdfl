require "bigdecimal"
require_relative "Utils"

def out_usage
  abort(<<-EOS)
Usage: #{File.basename($0)} options
Options:
    [-showFullInfo] =
    EOS
end

def parse_command_line
  # out_usage if ARGV.empty?

  if ARGV.any? { |item| item.strip.empty? }
    abort("There is an empty argument in the command line.") end

  options = CommandLineParser.parse(ARGV) do
    opt :extendedReport, :optional, :flag
  end

  create_options(
    extended_report: options[:extendedReport]
  )
end
