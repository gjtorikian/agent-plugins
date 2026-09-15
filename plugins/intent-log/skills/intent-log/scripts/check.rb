#!/usr/bin/env ruby
# frozen_string_literal: true

# Assert the invariants a global intent log must hold. Run after every write.
# --fix rewraps the file instead of complaining about it.
#
# The log is one person's, lives outside any repository, and tags PRs from
# every repository they touch, so a tag carries its repository:
# `owner/repo#26`. Why the log is shaped that way is in SKILL.md.

require "json"
require "date"
require "optparse"
require "open3"

def default_log
  home = ENV["INTENT_LOG_HOME"]
  home = File.join(Dir.home, ".intent-log") if home.nil? || home.empty?
  File.join(home, "intent-log.md")
end

options = {log: default_log, year: Date.today.year, max_words: 400,
           max_bullet: 20, width: 79, fix: false, author: "@me", owners: [],
           since: nil, prs_json: nil, limit: 500}
parser = OptionParser.new do |opts|
  opts.banner = "usage: check.rb [~/.intent-log/intent-log.md] [options]"
  opts.on("--year YEAR", Integer, "year the headings belong to") { options[:year] = _1 }
  opts.on("--max-words N", Integer, "longest a day may run (default: 400)") { options[:max_words] = _1 }
  opts.on("--max-bullet N", Integer, "longest a bullet may run (default: 20)") { options[:max_bullet] = _1 }
  opts.on("--width N", Integer, "wrap width (default: 79)") { options[:width] = _1 }
  opts.on("--author LOGIN", "whose PRs to fetch live (default: @me)") { options[:author] = _1 }
  opts.on("--owner OWNER", "only PRs under this owner; repeatable") { options[:owners] << _1 }
  opts.on("--since DATE", "only PRs created on or after DATE (default: first entry)") { options[:since] = _1 }
  opts.on("--prs-json PATH", "verified PR snapshot instead of live gh access") { options[:prs_json] = _1 }
  opts.on("--limit N", Integer, "live PR fetch limit (default: 500; refuses a full result)") { options[:limit] = _1 }
  opts.on("--fix", "rewrap the file rather than report on it") { options[:fix] = true }
end
parser.parse!
options[:log] = ARGV.shift if ARGV.any?
abort "--limit must be positive" unless options[:limit].positive?

# A line that opens its own unit: a bullet, a **why:** sub-line under one, an
# italic tail, or a section label.
OPENER = /\A(?:- |\s*\*\*|\*|[A-Z][A-Za-z ]*:\s*\z)/

# A sub-line reasons under the bullet above it and is indented to say so.
SUBLINE = /\A\s*\*\*/

# A PR tag names its repository so the same number in two repositories stays
# two PRs: `owner/repo#26`, `owner/repo#61 open`, `owner/repo#7 dropped`.
REPO = %r{[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+}
TAG = /`(#{REPO})#(\d+)(?: (dropped|open))?`/

# What a tag must say about each verified state.
STATES = {"merged" => nil, "closed" => "dropped", "open" => "open"}.freeze

# A backticked span is one token: `owner/repo#7 dropped` must never break
# across lines.
def wrap(text, width)
  text.split.join(" ").scan(/`[^`]*`\S*|\S+/).each_with_object([+""]) do |word, lines|
    if lines.last.empty? then lines[-1] = +word
    elsif lines.last.length + 1 + word.length <= width then lines.last << " " << word
    else lines << +word
    end
  end.join("\n")
end

# Wrapping a block by paragraph would glue its bullets into one.
def units(block)
  block.each_line.with_object([]) do |line, list|
    line = line.rstrip
    next if line.empty?
    if list.empty? || line.match?(OPENER) then list << +line
    else list.last << " " << line.strip
    end
  end
end

def rewrap_units(block, width)
  units(block).map do |unit|
    next "- " + wrap(unit.delete_prefix("- "), width - 2).gsub("\n", "\n  ") if unit.start_with?("- ")
    next "  " + wrap(unit.strip, width - 2).gsub("\n", "\n  ") if unit.match?(SUBLINE)

    wrap(unit, width)
  end.join("\n")
end

def rewrap(source, width)
  source.split("\n\n").filter_map do |block|
    block = block.strip
    next if block.empty?
    next block if block.start_with?("#", "---", "```")
    next rewrap_units(block, width) if block.lines.any? { _1.match?(OPENER) }

    wrap(block, width)
  end.join("\n\n") + "\n"
end

# `gh search prs` reports a repository as {name, nameWithOwner}; a hand-written
# snapshot may say "owner/name" directly. Either becomes "owner/name".
def repository_name(value)
  value = value["nameWithOwner"] if value.is_a?(Hash)
  value if value.is_a?(String) && value.match?(/\A#{REPO}\z/)
end

def pull_requests(options, since)
  raw = if options[:prs_json]
    File.read(options[:prs_json])
  else
    command = ["gh", "search", "prs", "--author", options[:author],
               "--limit", options[:limit].to_s,
               "--json", "number,repository,state,title,createdAt"]
    command.concat(["--created", ">=#{since.iso8601}"]) if since
    options[:owners].each { command.concat(["--owner", _1]) }
    output, error, status = Open3.capture3(*command)
    abort "gh search prs failed: #{error.strip}" unless status.success?
    output
  end

  prs = JSON.parse(raw)
  abort "PR evidence must be a JSON array" unless prs.is_a?(Array)
  records = prs.map do |pr|
    repo = pr.is_a?(Hash) ? repository_name(pr["repository"]) : nil
    state = pr["state"].to_s.downcase if pr.is_a?(Hash)
    unless repo && pr["number"].is_a?(Integer) && pr["number"].positive? &&
        STATES.key?(state) && pr["title"].is_a?(String)
      abort "PR evidence must be an array of repository (owner/name), number, " \
        "state (open, closed, or merged), and title records"
    end
    {key: "#{repo.downcase}##{pr["number"]}", name: "#{repo}##{pr["number"]}",
     state: state, title: pr["title"]}
  end
  keys = records.map { _1[:key] }
  abort "PR evidence contains duplicate pull requests" unless keys.uniq.size == keys.size
  if !options[:prs_json] && records.size >= options[:limit]
    abort "PR results may be truncated at #{options[:limit]}; increase --limit, " \
      "narrow --since or --owner, or provide complete --prs-json evidence"
  end
  records.to_h { [_1[:key], _1] }
rescue JSON::ParserError => error
  abort "invalid PR JSON: #{error.message}"
rescue Errno::ENOENT => error
  abort "cannot read PR evidence: #{error.message}; install gh or provide --prs-json"
end

def entries(body)
  body.split(/^## +(.+)$/)[1..].to_a.each_slice(2).map { |heading, text| [heading.strip, text.to_s] }
end

def heading_date(heading, year)
  match = heading.match(/([A-Z][a-z]{2}) +(\d{1,2})/)
  month = Date::ABBR_MONTHNAMES.index(match[1]) if match
  Date.new(year, month, match[2].to_i) if month
end

# A heading names a weekday and a date but rarely a year, so the year is
# carried forward from the last heading that named one. Without an anchor a
# log read in January dates its whole first year to the new one.
def carry_years(headings, fallback)
  year = nil
  headings.map do |heading|
    named = heading[/\b(20\d{2})\b/, 1]&.to_i
    year = named || year || fallback
    [heading, year, named]
  end
end

# Every "Wed Jul 15" in a heading, so a range heading is checked at both ends.
def heading_days(heading, year)
  heading.scan(/([A-Z][a-z]{2}) +([A-Z][a-z]{2}) +(\d{1,2})/).filter_map do |weekday, name, day|
    month = Date::ABBR_MONTHNAMES.index(name)
    [weekday, Date.new(year, month, day.to_i)] if month
  end
end

# Bullets, reassembled from their continuation lines.
def bullets(text)
  text.split("\n\n").flat_map { units(_1) }.filter_map { _1.delete_prefix("- ") if _1.start_with?("- ") }
end

begin
  source = File.read(options[:log])
rescue Errno::ENOENT
  abort "no log at #{options[:log]}; write the first entry there, or pass its path"
end

if options[:fix]
  File.write(options[:log], rewrap(source, options[:width]))
  puts "rewrapped #{options[:log]} at #{options[:width]}"
  exit
end

# the header may show example tags; only entries count
body = source.include?("\n## ") ? source[source.index("\n## ")..] : source
failures = []

# entries run oldest first, hold lists rather than prose, and stay short
found = entries(body).select { heading_date(_1.first, options[:year]) }
carried = carry_years(found.map(&:first), options[:year])
dated = found.zip(carried).map do |(heading, text), (_, year, named)|
  [heading, text, heading_date(heading, year), year, named]
end

# PR coverage starts where the log does: a PR opened before the first entry
# was never something this log promised to account for.
since = if options[:since]
  begin
    Date.parse(options[:since])
  rescue ArgumentError
    abort "--since must be a date such as 2026-09-10"
  end
elsif dated.any?
  dated.map { _1[2] }.min
end
if since.nil? && !options[:prs_json]
  abort "#{options[:log]} has no dated entries; pass --since DATE or --prs-json PATH to scope PR evidence"
end

known = pull_requests(options, since)

tagged = Hash.new { |h, k| h[k] = [] }
names = {}
body.scan(TAG) do |repo, number, marker|
  key = "#{repo.downcase}##{number}"
  names[key] ||= "#{repo}##{number}"
  tagged[key] << marker
end

known.sort_by { |key, _| key }.each do |key, pr|
  markers = tagged[key]
  if markers.empty?
    failures << "`#{pr[:name]}` (#{pr[:state]}) is in no entry: #{pr[:title]}"
    next
  end

  want = STATES.fetch(pr[:state])
  markers.reject { _1 == want }.each do |got|
    shown = got ? "`#{pr[:name]} #{got}`" : "a bare `#{pr[:name]}`"
    wanted = want ? "`#{pr[:name]} #{want}`" : "a bare `#{pr[:name]}`"
    failures << "#{shown} marks a #{pr[:state]} PR; expected #{wanted}"
  end
  failures << "`#{pr[:name]}` is tagged #{markers.size} times; tag it on one bullet" if markers.size > 1
end
(tagged.keys - known.keys).sort.each do |key|
  failures << if options[:prs_json]
    "`#{names[key]}` is tagged but is not in the PR snapshot"
  else
    "`#{names[key]}` is tagged but is not among #{options[:author]}'s PRs created since " \
      "#{since}; widen --since or --owner, or supply --prs-json"
  end
end

# lines stay wrapped, so a hand edit cannot leave a 200-char line behind
body.lines.each.with_index(1) do |line, number|
  line = line.chomp
  next unless line.length > options[:width] && line[0, options[:width]].include?(" ")

  failures << "line #{number} is #{line.length} chars; rerun with --fix"
end

if dated.any? && dated.first[4].nil?
  failures << "'#{dated.first[0]}' names no year; write it as " \
    "'#{dated.first[0]}, #{dated.first[3]}' so the log still sorts next January"
end

dated.each_cons(2) do |(_, _, earlier, _, _), (heading, _, later, _, named)|
  next if later >= earlier

  failures << if named
    "'#{heading}' comes after #{earlier}; entries run oldest first"
  else
    "'#{heading}' goes back before #{earlier}; name its year, as " \
      "'#{heading}, #{earlier.year + 1}', or put the entry in order"
  end
end

dated.each do |heading, text, _, year, _|
  words = text.gsub(/^[-*#]\s*/, "").split.size
  if words > options[:max_words]
    failures << "'#{heading}' is #{words} words; keep a day under #{options[:max_words]}"
  end

  failures << "'#{heading}' is prose, not a list" if bullets(text).empty?

  heading_days(heading, year).each do |weekday, date|
    real = date.strftime("%a")
    failures << "'#{heading}' calls #{date} #{weekday}; it was a #{real}" unless weekday == real
  end

  bullets(text).each do |bullet|
    size = bullet.split.size
    next unless size > options[:max_bullet]

    failures << "'#{heading}' has a #{size}-word bullet; keep one under #{options[:max_bullet]}: #{bullet[0, 60]}..."
  end
end

if failures.any?
  puts "#{failures.size} problem(s):"
  failures.each { puts "  - #{_1}" }
  exit 1
end

puts "ok: #{known.size} PRs accounted for across #{dated.size} entries"
