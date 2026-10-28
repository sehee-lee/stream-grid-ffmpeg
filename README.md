# FFmpeg for Stream Grid (LGPL source)

This repository provides the complete corresponding source code of **FFmpeg** as used in the iOS app **Stream Grid**, together with everything needed to rebuild it, as required by the **GNU Lesser General Public License v2.1 or later** (LGPL).

| | |
|---|---|
| FFmpeg version | **9.0.2**, unmodified |
| Source | [`source/ffmpeg-9.0.2.tar.xz`](source/ffmpeg-9.0.2.tar.xz) — identical to https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz |
| SHA-256 | `8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e` |
| Signature | [`source/ffmpeg-9.0.2.tar.xz.asc`](source/ffmpeg-9.0.2.tar.xz.asc) (from ffmpeg.org) |
| License | LGPL 2.1 or later — see [`COPYING.LGPLv2.1`](COPYING.LGPLv2.1). No GPL or non-free components are enabled. |
| Modifications | **None.** |

## How Stream Grid uses FFmpeg

Stream Grid uses FFmpeg only to **receive RTSP/RTP streams** (libavformat, libavcodec parsers, libavutil). It contains **no FFmpeg decoders**; video is decoded by Apple VideoToolbox.

FFmpeg is linked as a separate **dynamic framework** (`FFmpeg.framework`, embedded in the app), so it can be replaced with a modified version.

## Rebuilding

Requires macOS with Xcode.

```sh
build/build-ffmpeg.sh
```

This extracts `source/ffmpeg-9.0.2.tar.xz`, configures it with the exact options listed in [`BUILD_INFO.txt`](BUILD_INFO.txt), and produces:

- `out/FFmpeg.xcframework` — iOS device (arm64) and simulator (arm64) slices; one dynamic library built from libavformat, libavcodec and libavutil
- `out/include/` — headers
- `build/CFFmpeg/` — the Clang module map Stream Grid uses to import the C API from Swift

The configure options are:

```
--disable-everything --disable-programs --disable-doc --disable-debug --disable-autodetect
--disable-avdevice --disable-avfilter --disable-swscale --disable-swresample
--enable-static --disable-shared --enable-pic --enable-network
--enable-protocol=tcp,udp,rtp,http --enable-demuxer=rtsp,rtp,sdp --enable-parser=h264,hevc
```

## Replacing FFmpeg in the app

To use a modified FFmpeg with Stream Grid:

1. Build your modified FFmpeg with `build/build-ffmpeg.sh` (it must keep the FFmpeg 9.0 API/ABI of libavformat, libavcodec and libavutil, combined into one library named `FFmpeg`).
2. Replace `Payload/StreamGrid.app/Frameworks/FFmpeg.framework/FFmpeg` in the app bundle with your `out/FFmpeg.xcframework/ios-arm64/FFmpeg.framework/FFmpeg`.
3. Re-sign the app and the framework with your own Apple developer certificate and install it on your device.

## Questions

Please open an issue in this repository.

---

## 한국어 요약

iOS 앱 **Stream Grid**에 들어간 **FFmpeg 9.0.2**(수정 없음)의 소스와 빌드 방법을 LGPL 2.1 이상의 요건에 따라 공개하는 저장소입니다.

- `source/`: ffmpeg.org 원본 소스(SHA-256과 서명 포함)
- `build/build-ffmpeg.sh`: 앱과 같은 설정으로 다시 빌드(`out/`에 결과물)
- 앱은 FFmpeg를 RTSP 수신에만 쓰고(디코더 없음, 영상은 VideoToolbox가 디코딩), 바꿔 끼울 수 있게 동적 프레임워크로 넣었습니다.
- 문의는 이 저장소의 Issues로 남겨 주세요.
