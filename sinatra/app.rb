require 'sinatra'
require 'sinatra/reloader' if development?
require 'rugged'
require 'json'

class GitVisualizer
  attr_accessor :repo, :folder_depth, :files_data, :all_dates_range, :files_or_groups, :author_to_index, :authors, :min_date

  def initialize(repo_path, initial_depth=0)
    @repo = Rugged::Repository.new(repo_path)
    @folder_depth = initial_depth
    @files_data = {}
    @all_dates_range = []
    @files_or_groups = []
    @author_to_index = {}
    @authors = []
    @min_date = nil
    setup_data
  end

  def get_group_key(file_path)
    parts = file_path.split('/')
    if parts.size <= @folder_depth || @folder_depth == 0
      file_path
    else
      parts[0..@folder_depth-1].join('/') + '/*'
    end
  end

  def setup_data
    @files_data = Hash.new { |hash, key| hash[key] = {} }
    all_dates = Set.new
    authors = Set.new

    @repo.walk(@repo.head.target) do |commit|
      author = commit.author[:name]
      commit_date = commit.author[:time].to_date
      all_dates.add(commit_date)

      commit.diff.each_patch do |patch|
        file_path = patch.delta.new_file[:path]
        group_key = get_group_key(file_path)
        @files_data[group_key][commit_date] ||= author
        authors.add(author)
      end
    end

    dates = all_dates.sort
    raise "No commits found" if dates.empty?

    @min_date = dates.first
    max_date = dates.last
    @all_dates_range = (@min_date..max_date).to_a

    @authors = authors.sort
    @author_to_index = @authors.each_with_index.to_h
    update_matrix
  end

  def update_matrix
    @files_or_groups = @files_data.keys.sort
    num_days = @all_dates_range.size
    @original_matrix = Array.new(@files_or_groups.size) { Array.new(num_days, 0) }

    @files_or_groups.each_with_index do |group, row_idx|
      group_dates = @files_data[group]
      group_dates.each do |date, author|
        col_idx = (date - @min_date).to_i
        @original_matrix[row_idx][col_idx] = @author_to_index[author] + 1
      end
    end
  end

  def to_json
    {
      authors: @authors,
      dates: @all_dates_range.map(&:to_s),
      files_or_groups: @files_or_groups,
      matrix: @original_matrix
    }.to_json
  end

  def to_json_for_path(path)
    filtered_files = @files_or_groups.select { |file| file.start_with?(path) }
    filtered_indices = filtered_files.map { |file| @files_or_groups.index(file) }
    filtered_matrix = filtered_indices.map { |idx| @original_matrix[idx] }

    {
      authors: @authors,
      dates: @all_dates_range.map(&:to_s),
      files_or_groups: filtered_files,
      matrix: filtered_matrix,
      current_path: path
    }
  end
end

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

get '/data' do
  content_type :json
  path = params[:path] || ''
  depth = params[:depth].to_i
  visualizer = GitVisualizer.new('/home/haukot/temp/git-truck', depth)
  
  if path.empty?
    visualizer.to_json
  else
    # Filter data for specific path
    filtered_data = visualizer.to_json_for_path(path)
    filtered_data.to_json
  end
end
