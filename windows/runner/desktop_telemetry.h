#pragma once
#include <array>
#include <atomic>
#include <mutex>
#include <thread>
#include <map>
#include <string>
struct DesktopReadings {
  std::array<float, 48> bands{};
  std::array<float, 128> waveform{};
  double cpu = -1, gpu = -1, ram_percent = 0, ram_used_gb = 0, ram_total_gb = 0;
  unsigned memory_clock = 0, cpu_clock = 0, gpu_clock = 0, gpu_memory_clock = 0;
  bool audio_available = false;
};
class DesktopTelemetry {
 public:
  ~DesktopTelemetry();
  void Start(bool audio, bool stats);
  void SetConsumer(const std::string& key, bool audio, bool stats);
  void Stop();
  DesktopReadings Read();
 private:
  void CaptureAudio();
  void CaptureStats();
  std::atomic<bool> running_{false}, audio_{true}, stats_{true};
  std::mutex mutex_;
  DesktopReadings readings_;
  std::map<std::string, std::pair<bool,bool>> consumers_;
  std::thread audio_thread_, stats_thread_;
};

DesktopTelemetry& SharedDesktopTelemetry();
