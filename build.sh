#!/bin/bash
set -e

# Download & extract Flutter
curl https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.3-stable.tar.xz -o flutter.tar.xz
tar xf flutter.tar.xz
export PATH=$PATH:$PWD/flutter/bin

# Build
flutter config --no-analytics
flutter pub get
flutter build web --release
