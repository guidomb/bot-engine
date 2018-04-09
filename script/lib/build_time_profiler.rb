require 'ostruct'
require_relative 'build_time_log_parser'

class BuildTimeProfiler

  attr_reader :outliers_deviation
  attr_reader :warn_threshold
  attr_reader :fail_threshold
  attr_reader :build_log_file
  attr_reader :filter_block

  def initialize(outliers_deviation:, warn_threshold:, fail_threshold:, build_log_file:, &filter_block)
    @outliers_deviation = outliers_deviation
    @warn_threshold = warn_threshold
    @fail_threshold = fail_threshold
    @build_log_file = build_log_file
    @filter_block = filter_block
  end

  def build_time_outliers
    @build_time_outliers ||= begin
      parser = BuildTimeLogParser.new(build_log_file)
      result = parser.outliers(deviation: outliers_deviation, build_time_threshold: warn_threshold)
      result = result.select(&filter_block) if filter_block
      result
    end
  end

  def build_time_outliers_count
    @build_time_outliers_count ||= begin
      initial = OpenStruct.new({over_threshold: 0, within_threshold: 0})
      build_time_outliers.reduce(initial) do |counters, outlier|
        if outlier.time >= fail_threshold
          counters.over_threshold += 1
        else
          counters.within_threshold += 1
        end
        counters
      end
    end
  end

  def outliers_markdown_table(current_git_branch)
    table_header = <<EOS
## Compilation time outliers

Time | File | Line | Function |
-----|------|------|----------|
EOS
    table_body = build_time_outliers.map { |outlier| table_row_for(outlier, current_git_branch) }
    table_header + table_body.join("\n")
  end

  def analysis_output(current_git_branch)
    output = []
    outliers = build_time_outliers_count
    if outliers.over_threshold > 0
      output << [:fail, "There are #{outliers.over_threshold} functions over #{fail_threshold}ms build time threshold"]
    end
    if outliers.within_threshold > 0
      output << [:warn, "There are #{outliers.within_threshold} functions within #{warn_threshold}ms to #{fail_threshold}ms build time threshold"]
    end
    unless build_time_outliers.empty?
      output << [:markdown, outliers_markdown_table(current_git_branch)]
    end
    output
  end

  private

    def table_row_for(outlier, current_git_branch)
      filename = File.basename(outlier.file_path)
      github_location = outlier.file_path.gsub(Dir.pwd, "/guidomb/Portal/tree/#{current_git_branch}")
      github_location += "#L#{outlier.line_number}"
      "#{outlier.time}ms | [#{filename}](#{github_location}) | #{outlier.line_number} | `#{outlier.function_signature}`"
    end

end

if __FILE__== $0
  profiler = BuildTimeProfiler.new(
    outliers_deviation: 3,
    warn_threshold: 100.0,
    fail_threshold: 500.0,
    build_log_file: ARGV[0]
  )
  profiler.analysis_output('fake_git_branch').each do |type, message|
    puts message
  end
end
