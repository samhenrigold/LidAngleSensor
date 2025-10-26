#!/bin/bash

set -e

# select debug or release
configuration=release

# go to root
cd $(dirname "$0")/..

# build
xcodebuild \
  -project "LidAngleSensor.xcodeproj" \
  -scheme "LidAngleSensor" \
  -configuration $configuration \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" \
  -arch arm64

# run
build/Build/Products/$configuration/LidAngleSensor.app/Contents/MacOS/LidAngleSensor
