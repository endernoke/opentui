import re
import sys
from typing import Dict, List

def parse_header_to_zig(input_text: str) -> str:
    # Regex to find module names: /* module Name */
    module_regex = re.compile(r'/\* module (\w+) \*/')
    
    # Regex to find constants: const long Name = Value;
    # Handles tabs, spaces, and trailing semicolons
    const_regex = re.compile(r'const\s+long\s+(\w+)\s*=\s*(\d+);')

    # Split the file by module markers to group constants
    # We find all module start positions
    module_matches = list(module_regex.finditer(input_text))
    
    output = ["// Generated from C Header\n"]
    
    for i, match in enumerate(module_matches):
        module_name = match.group(1)

        if module_name.startswith("UIA_"):
            module_name = module_name[4:]
        
        # Determine the text range for this module
        start_pos = match.end()
        end_pos = module_matches[i+1].start() if i + 1 < len(module_matches) else len(input_text)
        module_block = input_text[start_pos:end_pos]
        
        # Find all constants within this block
        constants = const_regex.findall(module_block)
        
        if not constants:
            continue

        # Start generating the Zig Enum
        output.append(f"pub const {module_name} = enum(i32) {{")
        
        for name, value in constants:
            # Zig convention is often TitleCase for enums, 
            # but for C-interop, keeping the original name is safer.
            output.append(f"    {name} = {value},")
            
        output.append("};\n")

    return "\n".join(output)

def main():
    if len(sys.argv) < 2:
        print("Usage: python h2zig.py <header_file.h>")
        return

    file_path = sys.argv[1]
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        zig_code = parse_header_to_zig(content)
        
        # Output to stdout or a file
        print(zig_code)
        
    except FileNotFoundError:
        print(f"Error: File {file_path} not found.")

if __name__ == "__main__":
    main()