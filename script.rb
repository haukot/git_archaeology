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


format = {
  hash: "%h",
  date: "%cd",
  title: "%s",
  author: "%an %ae",

}
commits_str = `git log --no-merges --since=2014-02-01 --until=2021-11-31 --pretty=format:"--commit--%h--commit-hash--%s--commit-date--%cd--commit-title--" --numstat --date=short`

commits = commits_str.split('--commit--').reject(&:empty?).map do |c|
  title_str, files_str = c.split("--commit-title--\n")
  hash, title_str2 = title_str.split('--commit-hash--')
  title, date = title_str2.split('--commit-date--')

  # like commit de8d27073 in serviceguru-web, without any files(how is this possible btw?)
  files = (files_str || "").split("\n").map do |f|
    file = f.split("\t")
    { added: file[0].to_i, deleted: file[1].to_i, name: file[2] }
  end

  {title: title, hash: hash, date: Date.parse(date), files: files}
end



threshold = 7 # days

default_stat = {
  from_date: nil,
  to_date: nil,
  added: 0,
  deleted: 0,
  days_diff: 0,
  commits_count: 0,
  authors: {}, # TODO add author
  files: {}
}
last_date = commits.first[:date]
stats = [{ **default_stat, from_date: last_date, to_date: last_date }]
commits.each do |commit|
  stat = stats.last
  if (stat[:to_date] - commit[:date]) > threshold
    stat[:days_diff] = (stat[:to_date] - commit[:date]).to_i
    stat = { **default_stat, from_date: commit[:date] }
    stats.push(stat)
  end

  stat[:commits_count] += 1
  stat[:added] += commit[:files].sum{|f| f[:added] }
  stat[:deleted] += commit[:files].sum{|f| f[:deleted] }
  last_date = commit[:date]
  stat[:to_date] = last_date
end

stats.map do |stat|
  stat[:dates] = "#{stat[:from_date]} - #{stat[:to_date]}"
  stat.delete(:from_date)
  stat.delete(:to_date)
  stat
end

stats.map{ |x| puts "#{x[:dates]} | #{x[:days_diff]} | #{x}" }
