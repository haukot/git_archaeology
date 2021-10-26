# coding: utf-8

# get dates
# git log --no-merges --format="%cd" --date=short | sort -u -r

# get commits between date
# GIT_PAGER=cat git log --no-merges --format=" * %s" --since=$DATE --until=$NEXT

# этот вариант юзали в случае, чтобы сегодняшние коммиты захватить https://stackoverflow.com/a/4712213/11736429
# GIT_PAGER=cat git log --no-merges --format=" * %s" --since="$DATE 00:00:00" --until="$DATE 24:00:00"



# изменения в файлах
git log --oneline --name-status HEAD -1

dates = `git log --no-merges --format="%cd" --date=format:%Y-%m | sort -u -r`.split("\n")
dates.reduce do |cur, nxt|
  puts "#{nxt}-#{cur}"
  #  --format="" без коммитов
  # --pretty=format:"" тоже?
  #  --stat рисует +- как в difc
  # --dirstat=lines рисует процент измененных линий по папкам
  # like 2014-03-01
  files = `git log --oneline --numstat --since="#{nxt}-31 24:00:00" --until="#{cur}-31 24:00:00"`
  puts files

  puts
  puts
  puts
  puts
  puts

  nxt
end




require 'date'
require 'json'
require 'pathname'



format = {
  hash: "%h",
  date: "%cd",
  author: "%an %ae",
}.to_json.gsub('"', "'")
# commits_str = `git log --no-merges --since=2014-02-01 --until=2021-11-31 --pretty=format:"--commit--#{format}--commit-title--%s--commit-data--" --numstat --date=short`
commits_str = `git log --no-merges  --pretty=format:"--commit--#{format}--commit-title--%s--commit-data--" --numstat --date=short`

raw_commits = commits_str.split('--commit--').reject(&:empty?).map do |c|
  info, files_str = c.split("--commit-data--\n")
  data_json, title = info.split("--commit-title--")

  data = JSON.parse(data_json.gsub("'", '"'))
  hash = data['hash']
  date = data['date']
  author = data['author']

  # like commit de8d27073 in serviceguru-web, without any files(how is this possible btw?)
  files = (files_str || "").split("\n").map do |f|
    file = f.split("\t")
    { added: file[0].to_i, deleted: file[1].to_i, name: file[2] }
  end

  {title: title, hash: hash, date: Date.parse(date), files: files, author: author}
end

threshold = 10 # days
author_threshold = 90 # days

commits = raw_commits.map(&:dup) # шоб изменения не втыкались в исходные

# ушедшие с проекта
authors_gone = {}
commits = raw_commits.map do |commit|
  author = commit[:author]
  if authors_gone[author].nil?
    commit[:author_really_gone] = true
  end
  if authors_gone[author].nil? || authors_gone[author][:last_activity] - commit[:date] > author_threshold
    commit[:author_gone_here] = true
  end
  authors_gone[author] = { last_activity: commit[:date] }

  commit
end

# определяем последовательность прохода
commits = commits.reverse

# пришедшие на проект
new_authors = {}
commits = commits.map do |commit|
  author = commit[:author]
  if new_authors[author].nil?
    commit[:really_new_author] = true
  end
  if new_authors[author].nil? || commit[:date] - new_authors[author][:last_activity] > author_threshold
    commit[:new_author] = true
  end
  new_authors[author] = { last_activity: commit[:date] }

  commit
end


def build_stat(stat={})
  default_stat = {
    from_date: nil,
    to_date: nil,
    added: 0,
    deleted: 0,
    days_diff: 0,
    commits_count: 0,
    new_author: nil,
    authors: {},
    files: {}
  }

  { **default_stat, **stat }
end

last_date = commits.first[:date]
stats = [build_stat(from_date: last_date, to_date: last_date)]
authors = {}

commits.each do |commit|
  stat = stats.last

  # слои по датам(от нового к старому; первый вариант)
  # # if (stat[:to_date] - commit[:date]) > threshold
  # #  stat[:days_diff] = (stat[:to_date] - commit[:date]).to_i


  # слои по датам(от старого к новому; reversed)
  # if (commit[:date] - stat[:to_date]) > threshold
  #   stat[:days_diff] = (commit[:date] - stat[:to_date]).to_i
  #   stat = build_stat(from_date: commit[:date])
  #   stats.push(stat)
  # end

  if commit[:new_author]
    stat[:days_diff] = (commit[:date] - stat[:from_date]).to_i
    stat = build_stat(from_date: last_date)
    stat[:new_author] = commit[:author]
    stat[:really_new] = true if commit[:really_new_author]
    stats.push(stat)
  end

  stat[:commits_count] += 1
  stat[:authors][commit[:author]] ||= 0
  stat[:authors][commit[:author]] += 1

  stat[:added] += commit[:files].sum{|f| f[:added] }
  stat[:deleted] += commit[:files].sum{|f| f[:deleted] }

  commit[:files].each do |file|
    # Вообще в разных директориях нас интересует как правило разный уровень
    # вложенности. Это вероятно должно настраиваться

    # [0..-2] strips last part - so path will be without filename
    # stripped = Pathname(file[:name]).each_filename.to_a[0..-2].join('/')
    stripped = Pathname(file[:name]).each_filename.to_a[0..-2].first(2).join('/') # two starting slashes
    stripped = './' if stripped.empty?
    stat[:files][stripped] ||= { added: 0, deleted: 0 }
    stat[:files][stripped][:added] += file[:added]
    stat[:files][stripped][:deleted] += file[:deleted]
  end

  last_date = commit[:date]
  stat[:to_date] = last_date

  if commit[:author_gone_here]
    stat[:days_diff] = (commit[:date] - stat[:from_date]).to_i
    stat = build_stat(from_date: last_date)
    stat[:gone_author] = commit[:author]
    stat[:really_gone] = true if commit[:author_really_gone]
    stats.push(stat)
  end
end

stats.map do |stat|
  stat[:dates] = "#{stat[:from_date]} - #{stat[:to_date]}"
  stat[:files] = stat[:files].to_a
                   .sort_by{|(k, v)| v[:added] + v[:deleted]}
                   .reverse
                   .map{|(name, v)| "#{name} +#{v[:added]} -#{v[:deleted]}"}
                   .join("\n")
  stat[:authors] = stat[:authors]
                     .sort_by{|(k, v)| v}
                     .reverse
                     .to_h
  stat.delete(:from_date)
  stat.delete(:to_date)
  stat
end

puts "\n\n\n"

stats.map do |x|
  # TODO: change to .except in ruby 3.0
  dup = x.dup
  dates = dup.delete(:dates)
  files = dup.delete(:files)
  days_diff = dup.delete(:days_diff)
  new_author = dup.delete(:new_author)
  gone_author = dup.delete(:gone_author)
  really_gone = dup.delete(:really_gone)
  really_new = dup.delete(:really_new)
  puts "#{dates} | #{days_diff} | new#{really_new && "(really)"}: #{new_author} | gone#{really_gone && "(really)"}: #{gone_author} | #{dup}"
  puts files
end
