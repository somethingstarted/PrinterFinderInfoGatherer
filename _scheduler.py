import subprocess
from datetime import datetime
import os
import yaml
import calendar

# Load settings from the YAML file
def load_settings():
    settings_path = os.path.join(os.path.dirname(__file__), 'settings.yaml')
    with open(settings_path, 'r') as file:
        return yaml.safe_load(file)

def run_script(script_path):
    process = subprocess.run(['python3', script_path], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    print(process.stdout)
    if process.returncode != 0:
        print(f"Error running {script_path}: {process.stderr}")

def main():
    settings = load_settings()
    dayToRunBoth = settings.get('dayToRunBoth')

    today = datetime.today().day
    current_year = datetime.today().year
    current_month = datetime.today().month

    # Get the number of days in the current month
    days_in_month = calendar.monthrange(current_year, current_month)[1]
    print(f"Today is {today}, dayToRunBoth is {dayToRunBoth}, days in month is {days_in_month}")

    # Adjust dayToRunBoth to be within the valid range
    if dayToRunBoth > days_in_month:
        dayToRunBoth = days_in_month
    elif dayToRunBoth < 1:
        dayToRunBoth = 1
    print(f"Adjusted dayToRunBoth is {dayToRunBoth}")

    base_path = os.path.join(os.path.dirname(__file__), 'src')

    find_printers_path = os.path.join(base_path, '_find_printers.py')
    printer_counter_path = os.path.join(base_path, '_printer_counter.py')

    if today == dayToRunBoth:
        print("------running both scripts today")
        run_script(find_printers_path)
        print("find printers complete.")
        print("running printer counter")
        run_script(printer_counter_path)
        print("all complete")
    else:
        print("------running only printer counter today")
        run_script(printer_counter_path)
        print("printer counter complete")

if __name__ == "__main__":
    main()
