import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os
import sys
import textwrap

def read_input_file(file_path):
    # Read the CSV file
    df = pd.read_csv(file_path, header=None)
    
    # The first row contains the total GC execution time
    total_gc_time = float(df.iloc[0, 1])
    
    # The subsequent rows contain the phases and their respective times
    phases = df.iloc[1:, 0].tolist()
    times = df.iloc[1:, 1].astype(float).tolist()
    
    return total_gc_time, phases, times

def plot_gc_execution_times(plot_title, total_gc_time, phases, times, save_path):
    # Total measured time
    measured_total_time = sum(times)

    # Normalize times based on the reported total execution time
    normalized_times = np.array(times) * total_gc_time / measured_total_time

    # Plotting the total execution time with stacked phases
    plt.figure(figsize=(10, 6))
    plt.barh(["Major GC Total Time"], [total_gc_time], color="lightgrey", edgecolor="black")

    bottom = 0
    colors = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd", "#8c564b", "#e377c2", "#7f7f7f"]
    for i, (phase, time) in enumerate(zip(phases, normalized_times)):
        plt.barh(["Major GC Total Time"], [time], left=[bottom], color=colors[i], label=f"{phase} ({time:.2f} ms)", edgecolor="black")
        bottom += time

    plt.xlabel("Execution Time (ms)")

    # Wrap the title if it's too long
    max_title_length = 60  # Set maximum title length before wrapping
    if len(plot_title) > max_title_length:
        plot_title = "\n".join(textwrap.wrap(plot_title, max_title_length))

    plt.title(plot_title)

    # Adjust layout and add space for long titles
    plt.legend(loc="upper right", bbox_to_anchor=(1.3, 1))
    plt.tight_layout(rect=[0, 0, 1, 0.9])  # Add padding for the title

    # Save the plot to the specified directory
    plt.savefig(save_path, bbox_inches="tight")
    print(f"Plot saved at {save_path}")
    plt.close()

if __name__ == "__main__":
    # Ensure correct number of arguments
    if len(sys.argv) not in [3, 4]:
        print("Usage: python gc_execution_time_plot.py <plot_title> <input_file> [output_directory]")
        sys.exit(1)

    # Plot title as first argument
    plot_title = sys.argv[1]

    # Input file path as the second argument
    file_path = sys.argv[2]

    # Output directory (if provided, else use current directory)
    output_dir = sys.argv[3] if len(sys.argv) == 4 else os.getcwd()

    # Ensure the output directory exists
    if not os.path.exists(output_dir):
        print(f"Error: The directory {output_dir} does not exist.")
        sys.exit(1)

    # Define the output file path for the plot
    output_file = os.path.join(output_dir, plot_title+".png")
    
    try:
        # Read total GC time, phases, and times from the file
        total_gc_time, phases, times = read_input_file(file_path)
        
        # Plot the GC execution times and save to the specified location
        plot_gc_execution_times(plot_title, total_gc_time, phases, times, output_file)
        
    except Exception as e:
        print(f"An error occurred: {e}")

