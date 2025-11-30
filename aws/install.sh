#!/bin/bash

# Check if AWS CLI is already installed
if command -v aws &> /dev/null; then
    echo "AWS CLI is already installed"
    aws --version
else
    # Install AWS CLI via Homebrew (matches existing pattern)
    if command -v brew &> /dev/null; then
        echo "Installing AWS CLI via Homebrew..."
        brew install awscli
    else
        echo "Error: Homebrew not found. Please install Homebrew first."
        exit 1
    fi
    
    # Verify installation
    if command -v aws &> /dev/null; then
        echo "AWS CLI installed successfully"
        aws --version
    else
        echo "Error: AWS CLI installation failed"
        exit 1
    fi
fi

