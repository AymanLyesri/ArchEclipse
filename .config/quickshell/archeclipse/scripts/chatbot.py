#!/usr/bin/env python3
"""Shim: forwards to chatbot/main.py. Remove after QML points at main.py."""
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(_HERE))
from chatbot.main import main

if __name__ == "__main__":
    main()
