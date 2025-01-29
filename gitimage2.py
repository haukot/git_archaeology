#!/usr/bin/env python3

import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
import numpy as np
import git
from git import Repo
import datetime

def generate_git_heatmap(repo_path):
    repo = Repo(repo_path)

    files_data = {}
    all_dates = set()
    authors = set()

    # Process commits from newest to oldest
    for commit in repo.iter_commits(all=True):
        author = commit.author.name
        commit_date = commit.authored_datetime.date()
        all_dates.add(commit_date)

        # Track files modified in the commit
        files_in_commit = commit.stats.files.keys()

        for file_path in files_in_commit:
            if file_path not in files_data:
                files_data[file_path] = {}
            # Only record the newest commit's author for each file-date pair
            if commit_date not in files_data[file_path]:
                files_data[file_path][commit_date] = author
                authors.add(author)

    # Generate continuous date range from earliest to latest commit
    dates = sorted(all_dates)
    if not dates:
        print("No commits found.")
        return
    min_date = dates[0]
    max_date = dates[-1]
    all_dates_range = [min_date + datetime.timedelta(days=i) for i in range((max_date - min_date).days + 1)]

    # Map dates to columns
    date_to_column = {date: idx for idx, date in enumerate(all_dates_range)}

    # Prepare authors and color mapping
    authors = sorted(authors)
    author_to_index = {author: idx + 1 for idx, author in enumerate(authors)}
    num_authors = len(authors)

    # Initialize matrix with default (0) for no contribution
    files = sorted(files_data.keys())
    num_files = len(files)
    num_days = len(all_dates_range)
    matrix = np.zeros((num_files, num_days), dtype=int)

    # Populate matrix with author indices
    for file_idx, file_path in enumerate(files):
        file_dates = files_data.get(file_path, {})
        for date, author in file_dates.items():
            col_idx = date_to_column.get(date, -1)
            if col_idx != -1:
                matrix[file_idx, col_idx] = author_to_index[author]

    # Create custom colormap (white for 0, then author colors)
    default_color = (1, 1, 1, 1)  # White
    cmap = plt.cm.get_cmap('tab20', num_authors)
    colors = [default_color]
    for i in range(num_authors):
        colors.append(cmap(i))
    custom_cmap = ListedColormap(colors)

    # Plot the heatmap
    plt.figure(figsize=(15, 10))
    img = plt.imshow(matrix, cmap=custom_cmap, aspect='auto', interpolation='nearest')

    # Configure axes
    plt.xticks(
        np.linspace(0, num_days - 1, num=min(10, num_days), dtype=int),
        [all_dates_range[i].strftime('%Y-%m-%d') for i in np.linspace(0, num_days - 1, num=min(10, num_days), dtype=int)],
        rotation=45
    )
    plt.yticks([])  # Hide file names due to space constraints

    # Add color bar
    cbar = plt.colorbar(img, boundaries=np.arange(num_authors + 2) - 0.5)
    cbar.set_ticks(np.arange(num_authors + 1))
    cbar.set_ticklabels(['No Contributor'] + authors)
    cbar.ax.tick_params(labelsize=8)

    plt.title('Git Contributions Over Time by File and Contributor')
    plt.xlabel('Date')
    plt.ylabel('Files')
    plt.tight_layout()
    plt.savefig('git_contributions.png')
    plt.show()

if __name__ == '__main__':
    generate_git_heatmap('/home/haukot/programming/projects/slurm/slurm')
