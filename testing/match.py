# List of printer models to ignore
ignore_models = [
    "Canon MF450 Series",
    "Canon MF741C/743C",
    "Canon LBP226",
    "canon",
    "as400",
    "ibm",
    "yealink",
    "HP ETHERNET",
    "HP",
    "Xerox",
    "Integrated"
]

def is_printer(model):
    if model:
        print(f"Printer model detected: {model}")
        
        match_count = sum(model.lower().count(ignore_model.lower()) for ignore_model in ignore_models)
        if match_count > 0:
            print(f"match_count: {match_count}")
            return False  # Ignore this printer
        else:
            return True  # No match found, it is a printer

    return False  # If model is None or empty, default to not a printer

output = is_printer("Integrated")
print(f"output: >> {output}")

output = is_printer("Konika")
print(f"output: >> {output}")
