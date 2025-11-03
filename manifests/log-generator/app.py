
import time
import random

with open("./sample_logs.log", "r") as f:
    for line in f:
        print(line.strip())
        time.sleep(random.uniform(0.1, 1.0))
