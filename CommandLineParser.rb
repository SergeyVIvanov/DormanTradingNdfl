require "bigdecimal"

require_relative "RubyClassPatches"
require_relative "Utils"

def out_usage
  abort(<<-EOS)
Usage: #{File.basename($0)} options dailyReportDir
Options:
    [-showFullInfo] =
    EOS
end

def parse_command_line
  out_usage if ARGV.empty?

  if ARGV.any? { |item| item.strip.empty? }
    abort("There is an empty argument in the command line.") end

  dir_path = ARGV.last
  abort("The directory #{dir_path.q} does not exist.") unless Dir.exist?(dir_path)
  dir_path = File.realpath(dir_path).encode('utf-8')

  options = CommandLineParser.parse(ARGV[0..-2]) do
    opt :extendedReport, :optional, :flag
  end

  create_options(
    dir_path: dir_path,
    extended_report: options[:extendedReport]
  )
end
