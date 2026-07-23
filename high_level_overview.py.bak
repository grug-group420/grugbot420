#!/usr/bin/env python3
import os
import re
from collections import defaultdict

# Find all Julia files and extract module/struct/function definitions
julia_files = [f for f in os.listdir('.') if f.endswith('.jl')]

modules = []
structs = []
functions = []

for f in julia_files[:50]:  # Limit to first 50 for speed
    try:
        with open(f, 'r') as file:
            content = file.read()
            # Find module definitions
            modules.extend(re.findall(r'module\s+(\w+)', content))
            # Find struct definitions  
            structs.extend(re.findall(r'struct\s+(\w+)', content))
            # Find function definitions
            functions.extend(re.findall(r'function\s+(\w+)', content))
    except:
        pass

print("=== Core Components Found ===")
print(f"Modules: {len(set(modules))}")
print(f"Structs: {len(set(structs))}")
print(f"Functions: {len(set(functions))}")
print(f"\nModules: {', '.join(set(modules)[:10])}")
print(f"Structs: {', '.join(set(structs)[:10])}")
