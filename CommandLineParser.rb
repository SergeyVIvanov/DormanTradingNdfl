require "bigdecimal"

require_relative "RubyClassPatches"
require_relative "Utils"

def out_usage
  abort(<<-EOS)
Usage: #{File.basename($0)} options (dailyReportDir|ntcExecutionFilePath)
Options:
    [-showFullInfo] =
    EOS
end

def parse_command_line
  out_usage if ARGV.empty?

  if ARGV.any? { |item| item.strip.empty? }
    abort("There is an empty argument in the command line.") end

  options = CommandLineParser.parse(ARGV[0..-2]) do
    opt :extendedReport, :optional, :flag
    opt :ntc, :optional, :flag
  end

  path = ARGV.last
  if options[:ntc]
    abort("File #{path.q} not found.") unless File.exist?(path)
  else
    abort("Directory #{path.q} not found.") unless Dir.exist?(path)
  end
  path = File.realpath(path).encode('utf-8')

  create_options(
    extended_report: options[:extendedReport],
    ntc: options[:ntc],
    path: path
  )
end
