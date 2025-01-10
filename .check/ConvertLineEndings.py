#!/usr/bin/env python3

import os
import sys

def convert_line_endings_to_unix(directory):
    """
    Recursively walk `directory`, converting Windows-style line endings (\r\n)
    to Unix-style (\n) in all files EXCEPT:
      - any folders named '.github'
      - any files named '.gitattributes'
    """
    for root, dirs, files in os.walk(directory):
        # Skip the .github directory
        if ".github" in dirs:
            dirs.remove(".git")
            dirs.remove(".github")

        for filename in files:
            # Skip .gitattributes files
            if filename == ".gitattributes":
                continue

            file_path = os.path.join(root, filename)

            # Read the file in binary mode
            try:
                with open(file_path, "rb") as f:
                    content = f.read()
            except OSError as e:
                print(f"[ERROR] Could not open {file_path}: {e}")
                continue

            # Replace CRLF with LF
            new_content = content.replace(b"\r\n", b"\n")

            # Only write back if there's a difference
            if new_content != content:
                try:
                    with open(file_path, "wb") as f:
                        f.write(new_content)
                    print(f"[INFO] Converted line endings in {file_path}")
                except OSError as e:
                    print(f"[ERROR] Could not write to {file_path}: {e}")


def main():
    if len(sys.argv) != 2:
        print("Usage: python convert_line_endings.py <directory>")
        sys.exit(1)

    directory = sys.argv[1]

    if not os.path.isdir(directory):
        print(f"Error: {directory} is not a valid directory.")
        sys.exit(1)

    convert_line_endings_to_unix(directory)

if __name__ == "__main__":
    main()
