#!/bin/bash

# Install Klassy window decoration (KDecoration2 plugin)
# Used for drawing a colored outline around the active window
# GitHub: https://github.com/paulmcauley/klassy

set -e

# Check if already installed by looking for the decoration plugin
if find /usr/lib -path "*/org.kde.kdecoration2/klassydecoration.so" 2>/dev/null | grep -q .; then
    echo "Klassy already installed, skipping build"
    exit 0
fi

echo "Installing Klassy build dependencies..."
sudo apt install -y build-essential libkf5config-dev libkdecorations2-dev \
    libqt5x11extras5-dev qtdeclarative5-dev extra-cmake-modules \
    libkf5guiaddons-dev libkf5configwidgets-dev libkf5windowsystem-dev \
    libkf5coreaddons-dev gettext cmake libkf5iconthemes-dev \
    libkf5package-dev libkf5style-dev libkf5kcmutils-dev \
    kirigami2-dev libqt5svg5-dev

BUILD_DIR=$(mktemp -d)
trap "rm -rf $BUILD_DIR" EXIT

echo "Cloning Klassy..."
git clone --branch v5.26.1 --depth 1 https://github.com/paulmcauley/klassy "$BUILD_DIR/klassy"

echo "Building..."
cd "$BUILD_DIR/klassy"
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
# Only build the decoration plugin and its shared library (skip kstyle which has build issues)
cmake --build . --target klassydecoration klassycommon5 -j$(nproc)

echo "Installing..."
sudo make -C kdecoration install
sudo make -C libbreezecommon install

echo "Klassy installed successfully"
