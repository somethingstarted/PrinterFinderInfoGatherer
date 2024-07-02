# more_python/time_formatter.py

from datetime import timedelta

def format_elapsed_time(delta: timedelta, format_type: int = 0) -> str:
    formatters = {
        1: format_type_1,
        # Add additional format types here
    }
    
    formatter = formatters.get(format_type, default_formatter)
    return formatter(delta)

def format_type_1(delta: timedelta) -> str:
    seconds = int(delta.total_seconds())
    if seconds >= 86400:  # More than 24 hours
        days = seconds // 86400
        hours = (seconds % 86400) // 3600
        return f"{days}d {hours}h"
    elif seconds >= 3600:  # More than 60 minutes
        hours = seconds // 3600
        minutes = (seconds % 3600) // 60
        return f"{hours}h {minutes}m"
    elif seconds >= 60:  # More than 60 seconds
        minutes = seconds // 60
        seconds = seconds % 60
        return f"{minutes}m {seconds}s"
    else:  # Less than 60 seconds
        return f"{seconds}s"

def default_formatter(delta: timedelta) -> str:
    return str(delta)
