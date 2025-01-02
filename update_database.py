import datetime
import json

# Example database
database = {
    "Herbs": [],
    "Ores": [],
}

# Add daily data
database["Herbs"].append({"x": 0.25, "y": 0.33, "mapID": 1434})
database["Ores"].append({"x": 0.52, "y": 0.74, "mapID": 1434})

# Save to file
filename = f"database_{datetime.date.today()}.json"
with open(filename, "w") as f:
    json.dump(database, f)
print(f"Database updated: {filename}")