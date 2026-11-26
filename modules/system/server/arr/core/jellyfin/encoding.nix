{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
  enc = cfg.jellyfin.encoding;

  jellyfinFfmpegWrapped = pkgs.symlinkJoin {
    name = "jellyfin-ffmpeg-wrapped";
    paths = [
      (pkgs.writeShellScriptBin "ffmpeg" ''
        args=("$@")
        for ((i=0; i<''${#args[@]}; i++)); do
          if [ "''${args[i]}" = "-hls_time" ]; then
            ((i++))
            args[i]="${toString cfg.jellyfin.hlsSegmentDuration}"
          fi
        done
        exec ${pkgs.jellyfin-ffmpeg}/bin/ffmpeg "''${args[@]}"
      '')
      pkgs.jellyfin-ffmpeg
    ];
  };
in {
  config = mkIf (cfg.enable && cfg.jellyfin.enable) {
    nixflix.jellyfin.encoding = {
      transcodingTempPath = cfg.jellyfin.transcodingTempPath;
      encoderAppPathDisplay = "${jellyfinFfmpegWrapped}/bin/ffmpeg";

      enableHardwareEncoding = cfg.jellyfin.hardwareAcceleration != "none";
      hardwareAccelerationType = cfg.jellyfin.hardwareAcceleration;
      vaapiDevice = cfg.jellyfin.device;
      qsvDevice = cfg.jellyfin.device;

      allowHevcEncoding = enc.allowHevcEncoding;
      allowAv1Encoding = enc.allowAv1Encoding;

      hardwareDecodingCodecs = enc.hardwareDecodingCodecs;
      enableDecodingColorDepth10Hevc = enc.enableDecodingColorDepth10Hevc;
      enableDecodingColorDepth10Vp9 = enc.enableDecodingColorDepth10Vp9;

      enableIntelLowPowerH264HwEncoder = enc.enableLowPowerH264Encoder;
      enableIntelLowPowerHevcHwEncoder = enc.enableLowPowerHevcEncoder;

      enableTonemapping = enc.enableTonemapping;
      enableVppTonemapping = enc.enableVppTonemapping;

      enableThrottling = enc.enableThrottling;
      throttleDelaySeconds = enc.throttleDelaySeconds;
      enableSegmentDeletion = enc.enableSegmentDeletion;
      segmentKeepSeconds = enc.segmentKeepSeconds;
      maxMuxingQueueSize = enc.maxMuxingQueueSize;
      h264Crf = enc.h264Crf;
      h265Crf = enc.h265Crf;
      encoderPreset = enc.encoderPreset;

      encodingThreadCount = enc.encodingThreadCount;
    };
  };
}
