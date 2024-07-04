import itertools
import sys
import time

def loading_spinner():
    spinner = itertools.cycle(['-', '/', '|', '\\'])
    for _ in range(20):
        sys.stdout.write(next(spinner))   # write the next character
        sys.stdout.flush()                # flush the output
        time.sleep(0.1)
        print("\b", end='')            # erase the last character

loading_spinner()
