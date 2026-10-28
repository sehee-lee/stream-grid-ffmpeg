#!/bin/zsh
# FFmpeg를 iOS용 동적 프레임워크(FFmpeg.xcframework)로 빌드한다.
#
# - LGPL 2.1 구성만 쓴다. --enable-gpl / --enable-nonfree는 절대 켜지 않는다.
# - RTSP/RTP 수신과 H.264/H.265 파서만 넣는다. 디코딩은 앱에서 VideoToolbox가 맡으므로 디코더는 하나도 넣지 않는다.
# - libavformat/libavcodec/libavutil을 하나의 동적 라이브러리로 묶는다(LGPL 재링크 요건).
#
# 이 스크립트는 Stream Grid 앱 저장소의 scripts/build-ffmpeg.sh와 같은 설정으로,
# 인터넷에서 받지 않고 이 저장소의 source/ffmpeg-9.0.2.tar.xz로 빌드한다.
#
# 결과물(out/):
#   FFmpeg.xcframework   iphoneos arm64 + iphonesimulator arm64
#   include/             C 헤더 (Vendor/CFFmpeg 모듈이 참조)
#   COPYING.LGPLv2.1     앱에 함께 넣는 라이선스 전문
#   BUILD_INFO.txt       버전, 소스 주소, configure 옵션 (앱의 오픈소스 라이선스 화면에 표시)
#
# 사용법: build/build-ffmpeg.sh        (저장소 최상위에서 실행, Xcode 필요)

set -euo pipefail

FFMPEG_VERSION="9.0.2"
MIN_IOS="17.0"
SOURCE_URL="https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"

ROOT="${0:A:h:h}"
WORK="$ROOT/work"
OUT="$ROOT/out"
SRC="$WORK/ffmpeg-$FFMPEG_VERSION"

CONFIGURE_FLAGS=(
  --disable-everything
  --disable-programs --disable-doc --disable-debug
  --disable-autodetect
  --disable-avdevice --disable-avfilter --disable-swscale --disable-swresample
  --enable-static --disable-shared
  --enable-pic
  --enable-network
  --enable-protocol=tcp,udp,rtp,http
  --enable-demuxer=rtsp,rtp,sdp
  --enable-parser=h264,hevc
)

mkdir -p "$WORK"
if [[ ! -d "$SRC" ]]; then
  echo "▶ FFmpeg $FFMPEG_VERSION 소스 푸는 중"
  tar -xf "$ROOT/source/ffmpeg-$FFMPEG_VERSION.tar.xz" -C "$WORK"
fi

# $1: iphoneos | iphonesimulator
build_slice() {
  local sdk=$1
  local target="arm64-apple-ios${MIN_IOS}"
  [[ $sdk == iphonesimulator ]] && target="${target}-simulator"
  local sysroot=$(xcrun --sdk "$sdk" --show-sdk-path)
  local cc="$(xcrun --sdk "$sdk" --find clang)"
  local build="$WORK/build-$sdk"
  local prefix="$WORK/install-$sdk"

  echo "▶ $sdk 빌드 중"
  rm -rf "$build" "$prefix"
  mkdir -p "$build"
  (
    cd "$build"
    "$SRC/configure" \
      --prefix="$prefix" \
      --enable-cross-compile --target-os=darwin --arch=aarch64 \
      --cc="$cc" --sysroot="$sysroot" \
      --extra-cflags="-target $target" \
      --extra-ldflags="-target $target" \
      "${CONFIGURE_FLAGS[@]}" > configure.log
    make -j"$(sysctl -n hw.ncpu)" > make.log
    make install > install.log
  )

  # 정적 라이브러리 셋을 동적 라이브러리 하나로 묶어 프레임워크로 감싼다.
  local framework="$WORK/frameworks-$sdk/FFmpeg.framework"
  rm -rf "$framework"
  mkdir -p "$framework"
  "$cc" -target "$target" -isysroot "$sysroot" -dynamiclib \
    -install_name @rpath/FFmpeg.framework/FFmpeg \
    -Wl,-all_load \
    "$prefix/lib/libavformat.a" "$prefix/lib/libavcodec.a" "$prefix/lib/libavutil.a" \
    -o "$framework/FFmpeg"

  local platform="iPhoneOS"
  [[ $sdk == iphonesimulator ]] && platform="iPhoneSimulator"
  cat > "$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>FFmpeg</string>
  <key>CFBundleIdentifier</key><string>org.ffmpeg.FFmpeg</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>FFmpeg</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>$FFMPEG_VERSION</string>
  <key>CFBundleVersion</key><string>$FFMPEG_VERSION</string>
  <key>CFBundleSupportedPlatforms</key><array><string>$platform</string></array>
  <key>MinimumOSVersion</key><string>$MIN_IOS</string>
</dict>
</plist>
PLIST
}

build_slice iphoneos
build_slice iphonesimulator

echo "▶ xcframework 만드는 중"
rm -rf "$OUT"
mkdir -p "$OUT"
xcodebuild -create-xcframework \
  -framework "$WORK/frameworks-iphoneos/FFmpeg.framework" \
  -framework "$WORK/frameworks-iphonesimulator/FFmpeg.framework" \
  -output "$OUT/FFmpeg.xcframework" > /dev/null

cp -R "$WORK/install-iphoneos/include" "$OUT/include"
cp "$SRC/COPYING.LGPLv2.1" "$OUT/COPYING.LGPLv2.1"
cat > "$OUT/BUILD_INFO.txt" <<INFO
FFmpeg $FFMPEG_VERSION (수정 없음)
License: GNU LGPL 2.1 or later
Source: $SOURCE_URL
Configure: ${CONFIGURE_FLAGS[*]}
INFO

echo "✔ 완료: $OUT"
