#!/bin/bash
# Run Stellar Assault

# Check if Love2D is installed
if ! command -v love &> /dev/null
then
    echo "Love2D is not installed. Please install it first."
    echo "On macOS: brew install love"
    echo "On Ubuntu/Debian: sudo apt-get install love"
    echo "Or download from https://love2d.org/"
    exit 1
fi

# Run the game
love .