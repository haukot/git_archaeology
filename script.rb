# coding: utf-8

# get dates
git log --no-merges --format="%cd" --date=short | sort -u -r

# get commits between date
GIT_PAGER=cat git log --no-merges --format=" * %s" --since=$DATE --until=$NEXT

# этот вариант юзали в случае, чтобы сегодняшние коммиты захватить https://stackoverflow.com/a/4712213/11736429
# GIT_PAGER=cat git log --no-merges --format=" * %s" --since="$DATE 00:00:00" --until="$DATE 24:00:00"



# изменения в файлах
git log --oneline --name-status HEAD -1

dates = `git log --no-merges --format="%cd" --date=format:%Y-%m | sort -u -r`.split("\n")
dates.reduce do |cur, nxt|
  puts "#{nxt}-#{cur}"
  # like 2014-03-01
  files = `git log --oneline --name-status --since="#{nxt}-31 24:00:00" --until="#{cur}-31 24:00:00"`
  puts files

  puts
  puts
  puts
  puts
  puts

  nxt
end
