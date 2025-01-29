#!/usr/bin/env python3

import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
from matplotlib.widgets import Button, TextBox
import numpy as np
import git
from git import Repo
import datetime
import os
from collections import defaultdict

class GitVisualizer:
    def __init__(self, repo_path, initial_depth=0):
        self.repo = Repo(repo_path)
        self.folder_depth = initial_depth
        self.original_matrix = None
        self.all_dates_range = []
        self.files_or_groups = []
        self.author_to_index = {}
        self.authors = []
        self.date_to_column = {}
        self.hidden_patterns = set()

        # Create figure with extra space for controls
        self.fig = plt.figure(figsize=(15, 12))
        self.ax = self.fig.add_axes([0.1, 0.2, 0.8, 0.7])  # Main plot
        self.setup_data()
        self.setup_plot()
        self.setup_controls()

    def get_group_key(self, file_path):
        """Group files by specified folder depth"""
        parts = file_path.split(os.sep)
        if len(parts) <= self.folder_depth or self.folder_depth == 0:
            return file_path
        return os.sep.join(parts[:self.folder_depth]) + '/*'

    def setup_data(self):
        """Process repository and organize data"""
        self.files_data = defaultdict(dict)
        all_dates = set()
        authors = set()

        # Process commits from newest to oldest
        for commit in self.repo.iter_commits(all=True):
            author = commit.author.name
            commit_date = commit.authored_datetime.date()
            all_dates.add(commit_date)

            for file_path in commit.stats.files:
                group_key = self.get_group_key(file_path)

                if commit_date not in self.files_data[group_key]:
                    self.files_data[group_key][commit_date] = author
                    authors.add(author)

        # Generate continuous date range
        dates = sorted(all_dates)
        if not dates:
            raise ValueError("No commits found")

        min_date = dates[0]
        max_date = dates[-1]
        self.all_dates_range = [min_date + datetime.timedelta(days=i)
                              for i in range((max_date - min_date).days + 1)]
        self.date_to_column = {date: idx for idx, date in enumerate(self.all_dates_range)}

        # Prepare authors and color mapping
        self.authors = sorted(authors)
        self.author_to_index = {author: idx+1 for idx, author in enumerate(self.authors)}

        self.update_matrix()

    def update_matrix(self):
        """Update the visualization matrix based on current grouping and filters"""
        # Get visible files/groups
        visible_groups = [group for group in sorted(self.files_data.keys())
                        if not any(pattern in group for pattern in self.hidden_patterns)]

        self.files_or_groups = visible_groups
        num_days = len(self.all_dates_range)
        self.original_matrix = np.zeros((len(visible_groups), num_days), dtype=int)

        for row_idx, group in enumerate(visible_groups):
            group_dates = self.files_data[group]
            for date, author in group_dates.items():
                col_idx = self.date_to_column[date]
                self.original_matrix[row_idx, col_idx] = self.author_to_index[author]

    def setup_plot(self):
        """Create initial plot with interactive elements"""
        # Create colormap
        default_color = (1, 1, 1, 1)
        cmap = plt.cm.get_cmap('tab20', len(self.authors))
        colors = [default_color]
        colors.extend([cmap(i) for i in range(len(self.authors))])
        self.custom_cmap = ListedColormap(colors)

        # Plotting
        self.img = self.ax.imshow(self.original_matrix, cmap=self.custom_cmap,
                                aspect='auto', interpolation='nearest')

        # Axis formatting
        self.ax.set_xticks(np.linspace(0, len(self.all_dates_range)-1, num=10, dtype=int))
        self.ax.set_xticklabels([self.all_dates_range[i].strftime('%Y-%m-%d')
                               for i in np.linspace(0, len(self.all_dates_range)-1, num=10, dtype=int)],
                               rotation=45)

        self.update_ylabels()

        # Color bar
        self.cbar = self.fig.colorbar(self.img, boundaries=np.arange(len(self.authors)+2)-0.5)
        self.cbar.set_ticks(np.arange(len(self.authors)+1))
        self.cbar.set_ticklabels(['No Contributor'] + self.authors)
        self.cbar.ax.tick_params(labelsize=8)

        # Title and labels
        self.ax.set_title(f'Git Contributions (Grouping Depth: {self.folder_depth})')
        self.ax.set_xlabel('Date')
        self.ax.set_ylabel('Files/Groups')

    def update_ylabels(self):
        """Update y-axis labels"""
        self.ax.set_yticks(np.arange(len(self.files_or_groups)))
        self.ax.set_yticklabels(self.files_or_groups, fontsize=8)

    def setup_controls(self):
        """Add interactive controls"""
        # Group depth controls
        ax_depth_label = self.fig.add_axes([0.1, 0.05, 0.1, 0.04])
        ax_depth_label.axis('off')
        ax_depth_label.text(0.5, 0.5, 'Folder Depth:', ha='right')

        ax_depth = self.fig.add_axes([0.21, 0.05, 0.1, 0.04])
        self.depth_textbox = TextBox(ax_depth, '', initial=str(self.folder_depth))
        self.depth_textbox.on_submit(self.change_depth)

        # Hide pattern controls
        ax_hide_label = self.fig.add_axes([0.35, 0.05, 0.1, 0.04])
        ax_hide_label.axis('off')
        ax_hide_label.text(0.5, 0.5, 'Hide Pattern:', ha='right')

        ax_hide = self.fig.add_axes([0.46, 0.05, 0.2, 0.04])
        self.hide_textbox = TextBox(ax_hide, '')
        self.hide_textbox.on_submit(self.add_hide_pattern)

        # Clear filters button
        ax_clear = self.fig.add_axes([0.7, 0.05, 0.15, 0.04])
        self.clear_button = Button(ax_clear, 'Clear Filters')
        self.clear_button.on_clicked(self.clear_filters)

    def change_depth(self, text):
        """Change the folder grouping depth"""
        try:
            new_depth = int(text)
            if new_depth >= 0:
                self.folder_depth = new_depth
                # Rebuild the data with new grouping
                self.setup_data()
                self.img.set_data(self.original_matrix)
                self.update_ylabels()
                self.ax.set_title(f'Git Contributions (Grouping Depth: {self.folder_depth})')
                self.fig.canvas.draw_idle()
        except ValueError:
            pass

    def add_hide_pattern(self, pattern):
        """Add a pattern to hide from visualization"""
        if pattern:
            self.hidden_patterns.add(pattern)
            self.update_matrix()
            self.img.set_data(self.original_matrix)
            self.update_ylabels()
            self.fig.canvas.draw_idle()

    def clear_filters(self, event):
        """Clear all hiding patterns"""
        self.hidden_patterns.clear()
        self.update_matrix()
        self.img.set_data(self.original_matrix)
        self.update_ylabels()
        self.fig.canvas.draw_idle()

    def show(self):
        plt.show()

def visualize_repository(repo_path, initial_depth=0):
    visualizer = GitVisualizer(repo_path, initial_depth)
    visualizer.show()

if __name__ == '__main__':
    # Example usage:
    visualize_repository('/home/haukot/temp/git-truck', initial_depth=1)
