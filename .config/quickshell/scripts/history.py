import json
import os
import sys

HISTORY_FILE = os.path.expanduser("~/.config/quickshell/launcher_history.json")

def load_history():
    if not os.path.exists(HISTORY_FILE):
        return {}
    try:
        with open(HISTORY_FILE, "r") as f:
            return json.load(f)
    except:
        return {}

def save_history(history):
    with open(HISTORY_FILE, "w") as f:
        json.dump(history, f)

def increment(app_name):
    history = load_history()
    history[app_name] = history.get(app_name, 0) + 1
    save_history(history)

def get_counts():
    history = load_history()
    for name, count in history.items():
        print(f"{name}|{count}")

if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "add":
        increment(sys.argv[2])
    else:
        get_counts()
